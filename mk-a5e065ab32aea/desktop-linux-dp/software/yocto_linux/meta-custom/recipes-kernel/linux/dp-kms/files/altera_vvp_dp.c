// SPDX-License-Identifier: GPL-2.0-only
/*
 * altera_vvp_dp.c - DRM/KMS driver for the Altera Agilex GHRD
 *                       DisplayPort fabric subsystem.
 *
 * This driver is the kernel equivalent of dp_demo.sh. It maps the same 6-step
 * bring-up sequence onto proper DRM/KMS abstractions:
 *
 *   dp_demo.sh step                  DRM/KMS mapping
 *   ─────────────────────────────────────────────────────────────────────────
 *   1. modprobe uio_pdrv_genirq   -> driver probe: SMMU identity mapping is
 *                                    set up by the DT (iommus + memory-region
 *                                    on this node), replacing the UIO node.
 *   2. devmem2 PIO_ADDR w 3       -> drm_crtc_helper_funcs.mode_set_nofb:
 *                                    clock PIO written before VFR start.
 *   3. dp_train                   -> drm_connector_helper_funcs.detect +
 *                                    drm_encoder_helper_funcs.enable:
 *                                    native drm_dp_helper AUX + link training.
 *   4. dp_video_f2h -b 0 ...      -> drm_plane_helper_funcs.atomic_update:
 *                                    VFR buffer-set programming + run.
 *   5. dp_axi2cv                  -> drm_crtc_helper_funcs.atomic_enable:
 *                                    AXIS video-timing (altera_dp_axi_2_im).
 *   6. dp_video_f2h (repaint)     -> drm_crtc_helper_funcs.atomic_flush:
 *                                    VFR commit (latch new starting set).
 *
 * Hardware block layout:
 *
 *   DDR carve-out (0xC000_0000, 32 MB)
 *     |
 *     | F2SDRAM (non-coherent) or F2H (coherent, via SMMU SID-12)
 *     ↓
 *   VFR (0x2002_0000)  – primary plane pixel pump
 *     ↓ AXI4-Stream
 *   CPM  (colour-plane mux, transparent in this config)
 *     ↓ AXI4-Stream
 *   AXI2IM (0x2003_0C00)  – altera_dp_axi_2_im: AXIS -> DP TX video timing
 *     ↓ (raster totals + per-line clock throttle)
 *   DP TX (0x2003_0000)  – DisplayPort TX IP → connector
 *     ↓
 *   Monitor
 *
 * DRM object hierarchy:
 *
 *   drm_device
 *   └── drm_plane  (primary, wraps VFR)
 *   └── drm_crtc   (wraps VFR run-control + AXI2CV timing)
 *   └── drm_encoder (simple pass-through; link training in enable)
 *   └── drm_connector (DP, HPD + EDID via the native AUX channel)
 *
 * Limitations / known simplifications:
 *   - Single fixed mode: 1920x1080@60 Hz (CEA VIC 16). The sink's EDID is
 *     read and validated: the fixed mode is offered only when the sink
 *     advertises 1080p60 (the one mode the fixed pixel clock can generate).
 *   - Single framebuffer: uses the DT reserved-memory carve-out at
 *     0xC000_0000. The plane does not allocate GEM objects; it operates the
 *     VFR directly on the fixed physical address.
 *   - Non-coherent F2SDRAM path (matches the SM43 SOF). A coherent F2H build
 *     (modular devkit) would set dma_set_coherent_mask differently and map the
 *     framebuffer cacheable.
 *   - Atomic page-flip / vblank IS wired: the VFR frame-read IRQ (GIC SPI 18)
 *     drives drm_crtc_handle_vblank(), and page-flips use a deferred ping-pong
 *     buffer-set switch committed at the frame boundary in altdp_vfr_irq()
 *     (see altdp_plane_atomic_update / altdp_crtc_enable_vblank).
 */

#include <linux/clk.h>
#include <linux/delay.h>
#include <linux/dma-mapping.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_reserved_mem.h>
#include <linux/platform_device.h>

#include <drm/drm_atomic.h>
#include <drm/drm_atomic_helper.h>
#include <drm/drm_framebuffer.h>
#include <drm/drm_gem_framebuffer_helper.h>
#include <drm/drm_connector.h>
#include <drm/drm_crtc.h>
#include <drm/drm_crtc_helper.h>
#include <drm/drm_drv.h>
#include <drm/drm_edid.h>
#include <drm/drm_encoder.h>
#include <drm/drm_fb_helper.h>
#include <drm/drm_file.h>
#include <drm/drm_fourcc.h>
#include <drm/drm_gem_dma_helper.h>
#include <drm/drm_managed.h>
#include <drm/drm_modeset_helper_vtables.h>
#include <drm/drm_plane.h>
#include <drm/drm_plane_helper.h>
#include <drm/drm_print.h>
#include <drm/drm_probe_helper.h>
#include <drm/drm_simple_kms_helper.h>
#include <drm/drm_vblank.h>

#include "altera_vvp_dp_regs.h"
#include "altera_vvp_dp.h"

#define DRIVER_NAME "altera-vvp-dp"
#define DRIVER_DESC "Altera Agilex VVP DisplayPort DRM/KMS driver"
#define DRIVER_MAJOR 1
#define DRIVER_MINOR 0

/* -------------------------------------------------------------------------
 * Driver private state
 * -------------------------------------------------------------------------*/

struct altdp_device {
    struct drm_device drm;
    struct device *dev;

    /* MMIO bases */
    void __iomem *dptx_base; /* DP TX + AXI2CV (0x20030000) */
    void __iomem *vfr_base; /* VFR CSR        (0x20020000) */
    void __iomem *pio_base; /* Clock PIO      (0x20035000) */

    /* Reserved framebuffer carve-out */
    phys_addr_t fb_phys; /* physical base (32-bit)     */
    size_t fb_size; /* total reserved bytes       */
    void __iomem *fb_virt; /* kernel ioremap mapping     */

    /* Current display mode (cached for VFR re-program on flip) */
    struct drm_display_mode mode;
    bool mode_valid;

    /*
         * Video clock PIO divider value written to CLK_PIO_DATA.
         * The PIO divides the 148.5 MHz system clock by (value + 1) to derive
         * the DP source video clock (e.g. value 3 => divide-by-4 =>
         * 148.5 / 4 = 37.125 MHz; the VFR streams 4 pixels/clock, giving the
         * 148.5 MHz 1080p60 pixel rate).  Encoded from the human-friendly
         * "intel,vid-clk-divider" DT property (the divide ratio N) as N - 1,
         * so a board or FPGA respin (different vid_pll / pixel clock) can
         * retune the divider without editing or recompiling this driver.
         * Defaults to CLK_PIO_DIV_DEFAULT when the property is absent.
         */
    u32 clk_pio_div;

    /* VFR interrupt */
    int vfr_irq;

    /*
	 * Ping-pong double-buffer state (two VFR buffer sets, one frame each).
	 * A plane update stages the new frame's base into the *back* set and
	 * arms flip_pending; the VFR frame-read IRQ then switches
	 * VFR_STARTING_BUFFER_SET to that set at the frame boundary.  flip_lock
	 * serialises the process-context stage against the IRQ-context switch.
	 */
    spinlock_t flip_lock;
    unsigned int active_set; /* set the VFR is reading now  */
    unsigned int pending_set; /* set armed for next boundary */
    bool flip_pending; /* a set switch is armed       */

    /* Native DisplayPort link (drm_dp_helper AUX + CR/EQ training) */
    struct altdp_link link;

    /* DRM objects */
    struct drm_plane plane;
    struct drm_crtc crtc;
    struct drm_encoder encoder;
    struct drm_connector connector;
};

static inline struct altdp_device *to_altdp(struct drm_device *drm)
{
    return container_of(drm, struct altdp_device, drm);
}

/* -------------------------------------------------------------------------
 * MMIO helpers
 * -------------------------------------------------------------------------*/

static inline u32 vfr_rd(struct altdp_device *adp, unsigned int off)
{
    return ioread32(adp->vfr_base + off);
}

static inline void vfr_wr(struct altdp_device *adp, unsigned int off, u32 val)
{
    iowrite32(val, adp->vfr_base + off);
}

static inline u32 dptx_rd(struct altdp_device *adp, unsigned int off)
{
    return ioread32(adp->dptx_base + off);
}

static inline void dptx_wr(struct altdp_device *adp, unsigned int off, u32 val)
{
    iowrite32(val, adp->dptx_base + off);
}

/* -------------------------------------------------------------------------
 * Clock PIO
 * -------------------------------------------------------------------------*/

static void altdp_clk_pio_set_div(struct altdp_device *adp, u32 div)
{
    iowrite32(div, adp->pio_base + CLK_PIO_DATA);
    dev_dbg(adp->dev, "clock PIO: divide-by-%u\n", div + 1);
}

/* -------------------------------------------------------------------------
 * AXI-Stream video-timing programming (altera_dp_axi_2_im + DP TX MSA)
 *
 * The DP TX video path uses the altera_dp_axi_2_im "AXIS ingest throttle"
 * (TX_AXIS_VIDEOIF_EN=1). Unlike the old intel_axi2cv clocked-video block it
 * neither has a mode bank / MODE_MATCH handshake nor auto-measures the video
 * timing, so software must (1) program the throttle raster totals + per-line
 * clock count, (2) program the DP TX Main Stream Attributes (MSA) the sink
 * needs, and (3) toggle video idle->active to latch the MSA. This mirrors the
 * DP IP reference (dp_demo main.c: axi_2_im writes + MSA writes +
 * btc_dptx_video_enable()).
 * -------------------------------------------------------------------------*/

static int altdp_axi2cv_program(struct altdp_device *adp, const struct drm_display_mode *mode)
{
    u32 hactive, htotal, vactive, vtotal, sysclocks, fps;
    u32 hsw, hstart, vsw, vstart, hsp, vsp, ctrl;

    hactive = mode->hdisplay;
    htotal = mode->htotal;
    vactive = mode->vdisplay;
    vtotal = mode->vtotal;

    hsw = mode->hsync_end - mode->hsync_start;
    hstart = mode->htotal - mode->hsync_start; /* sync + back porch to active */
    vsw = mode->vsync_end - mode->vsync_start;
    vstart = mode->vtotal - mode->vsync_start;
    hsp = (mode->flags & DRM_MODE_FLAG_PHSYNC) ? 1 : 0;
    vsp = (mode->flags & DRM_MODE_FLAG_PVSYNC) ? 1 : 0;

    /*
     * Frame rate in Hz. mode->clock is the pixel clock in kHz; fall back to
     * the DRM vrefresh helper if it is unset.
     */
    if (mode->clock)
        fps = DIV_ROUND_CLOSEST(mode->clock * 1000u, htotal * vtotal);
    else
        fps = drm_mode_vrefresh(mode);

    /*
     * SYSCLOCKS = tx_axi4s_clk (Hz) / (fps * vtotal) = tx_axi4s_clk cycles per
     * video line. tx_axi4s_clk is the full pixel clock (not divided by PIP),
     * i.e. pixel_clock = fps * htotal * vtotal, so this reduces to htotal and
     * stays correct without hard-coding the clock frequency.
     */
    sysclocks = htotal;

    dev_info(adp->dev,
             "AXIS video: %ux%u htot=%u vtot=%u fps=%u -> HACT=%u HTOT=%u VACT=%u VTOT=%u SYSCLK=%u (pip=%u)\n",
             hactive, vactive, htotal, vtotal, fps, hactive / AXI2IM_PIP, htotal / AXI2IM_PIP, vactive, vtotal,
             sysclocks, AXI2IM_PIP);

    /* 1) altera_dp_axi_2_im throttle: raster totals (H scaled by PIP). */
    dptx_wr(adp, AXI2IM_HACTIVE, hactive / AXI2IM_PIP);
    dptx_wr(adp, AXI2IM_HTOTAL, htotal / AXI2IM_PIP);
    dptx_wr(adp, AXI2IM_VACTIVE, vactive);
    dptx_wr(adp, AXI2IM_VTOTAL, vtotal);
    dptx_wr(adp, AXI2IM_SYSCLOCKS, sysclocks);

    /* 2) DP TX Main Stream Attributes (the AXIS path does not auto-measure). */
    dptx_wr(adp, MSA_HTOTAL, htotal);
    dptx_wr(adp, MSA_VTOTAL, vtotal);
    dptx_wr(adp, MSA_HSP, hsp);
    dptx_wr(adp, MSA_HSW, hsw);
    dptx_wr(adp, MSA_HSTART, hstart);
    dptx_wr(adp, MSA_VSTART, vstart);
    dptx_wr(adp, MSA_VSP, vsp);
    dptx_wr(adp, MSA_VSW, vsw);
    dptx_wr(adp, MSA_HWIDTH, hactive);
    dptx_wr(adp, MSA_VHEIGHT, vactive);
    /*
     * MISC0 (colour format / bit depth) is auto-generated by the DP TX from
     * the video path - the reference does not write it and it reads back 0 in
     * a working link, so it is intentionally left to the hardware.
     */

    /*
     * 3) Latch the MSA by toggling the video idle pattern off->on. Preserve
     * the link-rate / lane-count fields the training path wrote to TX_CONTROL.
     */
    ctrl = dptx_rd(adp, DPTX_OFF_TX_CONTROL) & ~TX_CONTROL_VID_MASK;
    dptx_wr(adp, DPTX_OFF_TX_CONTROL, ctrl | TX_CONTROL_VID_IDLE); /* idle */
    usleep_range(10000, 20000);
    dptx_wr(adp, DPTX_OFF_TX_CONTROL, ctrl); /* active video */

    return 0;
}

/* -------------------------------------------------------------------------
 * VFR buffer-set programming
 * (equivalent to dp_video.c program_buffer_set() + run sequence)
 * -------------------------------------------------------------------------*/

static void altdp_vfr_program_bufset(struct altdp_device *adp, unsigned int set, u32 phys_base, u32 stride, u32 width,
                                     u32 height)
{
    unsigned int base = VFR_BUFSET_BASE + set * VFR_BUFSET_STRIDE;

    vfr_wr(adp, base + VFR_BUF_BASE, phys_base);
    vfr_wr(adp, base + VFR_BUF_NUM_BUFFERS, 1);
    vfr_wr(adp, base + VFR_BUF_INTER_BUF_OFF, stride * height);
    vfr_wr(adp, base + VFR_BUF_INTER_LINE_OFF, stride);
    vfr_wr(adp, base + VFR_BUF_WIDTH, width);
    vfr_wr(adp, base + VFR_BUF_HEIGHT, height);
    vfr_wr(adp, base + VFR_BUF_INTERLACE, 0);
    vfr_wr(adp, base + VFR_BUF_COLORSPACE, 0);
    vfr_wr(adp, base + VFR_BUF_SUBSAMPLING, VFR_SUBSAMPLING_444);
    vfr_wr(adp, base + VFR_BUF_COSITING, 0);
    vfr_wr(adp, base + VFR_BUF_BPS, 8);
    vfr_wr(adp, base + VFR_BUF_FIELD_COUNT, 0);
}

/**
 * altdp_vfr_start - configure and start the VFR for a given mode + buffer.
 * @adp:     driver private state
 * @set:     buffer set index to display (0 or 1)
 * @commit:  if true, also write VFR_COMMIT to latch (initial enable path)
 *
 * Implements the dp_video_f2h -b <set> sequence:
 *   stop → configure 2 buffer sets → set run mode → set starting set → commit.
 */
static int altdp_vfr_start(struct altdp_device *adp, unsigned int set, bool commit)
{
    u32 stride, buf1_phys, status;
    int i;

    if (!adp->mode_valid) {
        dev_err(adp->dev, "VFR start called with no valid mode\n");
        return -EINVAL;
    }

    /*
	 * Per-line stride MUST be a multiple of the VFR's 1024-byte (256 px)
	 * AXI read burst, or the VFR corrupts pixels at the partial final
	 * burst / mid-burst line wrap (horizontal-hatch artifact).  The dumb
	 * buffer is allocated with the same alignment (altdp_dumb_create), so
	 * this stride matches the framebuffer's actual pitch.  Buffer set 1
	 * starts one burst-aligned frame after set 0.
	 */
    stride = ALIGN((u32)adp->mode.hdisplay * DP_BYTES_PER_PIXEL, VFR_STRIDE_ALIGN);
    buf1_phys = (u32)adp->fb_phys + stride * (u32)adp->mode.vdisplay;

    /* Quiesce the reader first. */
    vfr_wr(adp, VFR_RUN, VFR_RUN_STOP);

    /* Program two buffer sets (set 0 and set 1). */
    vfr_wr(adp, VFR_NUM_BUFFER_SETS, 2);
    vfr_wr(adp, VFR_BUFFER_MODE, VFR_BUFFER_MODE_SINGLE);
    altdp_vfr_program_bufset(adp, 0, (u32)adp->fb_phys, stride, adp->mode.hdisplay, adp->mode.vdisplay);
    altdp_vfr_program_bufset(adp, 1, buf1_phys, stride, adp->mode.hdisplay, adp->mode.vdisplay);

    /* Start free-running. */
    vfr_wr(adp, VFR_RUN, VFR_RUN_FREE_RUNNING);
    vfr_wr(adp, VFR_STARTING_BUFFER_SET, set);

    if (commit)
        vfr_wr(adp, VFR_COMMIT, 1);

    /* Poll for VFR_STATUS_OUTPUTTING. */
    status = 0;
    for (i = 0; i < VFR_STATUS_TRIES; i++) {
        status = vfr_rd(adp, VFR_STATUS);
        if (status & VFR_STATUS_OUTPUTTING)
            break;
        usleep_range(VFR_STATUS_POLL_US, VFR_STATUS_POLL_US * 2);
    }

    if (!(status & VFR_STATUS_OUTPUTTING)) {
        dev_err(adp->dev, "VFR did not assert OUTPUTTING (status=0x%x)\n", status);
        return -ETIMEDOUT;
    }

    dev_info(adp->dev, "VFR streaming: set=%u phys=0x%08llx %ux%u\n", set, (unsigned long long)adp->fb_phys,
             adp->mode.hdisplay, adp->mode.vdisplay);
    return 0;
}

/* -------------------------------------------------------------------------
 * VFR IRQ handler (frame-read / vblank equivalent)
 * -------------------------------------------------------------------------*/

static irqreturn_t altdp_vfr_irq(int irq, void *data)
{
    struct altdp_device *adp = data;
    u32 status;

    status = vfr_rd(adp, VFR_IRQ_STATUS);
    if (!status)
        return IRQ_NONE;

    /* Acknowledge by writing back the status bits. */
    vfr_wr(adp, VFR_IRQ_STATUS, status);

    /*
	 * Frame boundary reached: the VFR has just finished reading the active
	 * buffer set (VFR IP flow step 6).  If a flip is armed, switch the
	 * reader to the freshly-written back set *now* — at the boundary — so
	 * the new base never latches mid-scan (step 7).  Committing here rather
	 * than in the plane update is what stops the per-repaint blink: the VFR
	 * always reads a complete, stable frame.
	 */
    spin_lock(&adp->flip_lock);
    if (adp->flip_pending) {
        vfr_wr(adp, VFR_STARTING_BUFFER_SET, adp->pending_set);
        vfr_wr(adp, VFR_COMMIT, 1);
        adp->active_set = adp->pending_set;
        adp->flip_pending = false;
    }
    spin_unlock(&adp->flip_lock);

    /* Signal DRM vblank (also sends any armed page-flip completion event). */
    drm_crtc_handle_vblank(&adp->crtc);

    return IRQ_HANDLED;
}

/* =========================================================================
 * DRM plane helpers
 * (primary plane = VFR pixel pump)
 * =========================================================================*/

static const u32 altdp_plane_formats[] = {
    DRM_FORMAT_XRGB8888,
};

static void altdp_plane_atomic_update(struct drm_plane *plane, struct drm_atomic_state *state)
{
    struct drm_plane_state *new_state = drm_atomic_get_new_plane_state(state, plane);
    struct altdp_device *adp = to_altdp(plane->dev);
    struct drm_framebuffer *fb = new_state->fb;
    dma_addr_t paddr;
    unsigned int back;
    unsigned long flags;

    if (!new_state->crtc || !fb)
        return;

    /*
	 * For the fixed carve-out framebuffer we bypass GEM and use the
	 * reserved physical address directly. If a GEM DMA buffer is
	 * provided (e.g. from a userspace mmap), use its DMA address.
	 */
    if (fb->obj[0]) {
        struct drm_gem_dma_object *dma_obj = to_drm_gem_dma_obj(fb->obj[0]);
        paddr = dma_obj->dma_addr;
    } else {
        paddr = adp->fb_phys;
    }

    /*
	 * Ping-pong double buffer (VFR IP "two buffer sets" model, steps 3/5):
	 * program the new frame's base into the set the VFR is NOT currently
	 * reading (the back set) and arm a switch to it.  We do NOT commit
	 * here — the actual VFR_STARTING_BUFFER_SET + VFR_COMMIT is deferred to
	 * the frame-read IRQ (altdp_vfr_irq), so the reader only switches at a
	 * frame boundary and never re-points mid-scan.  A mid-scan re-point
	 * tears the frame and collapses the DP link, which is the per-repaint
	 * blink we are fixing.
	 */
    spin_lock_irqsave(&adp->flip_lock, flags);
    back = adp->active_set ^ 1;
    vfr_wr(adp, VFR_BUF(back, VFR_BUF_BASE), (u32)paddr);
    adp->pending_set = back;
    adp->flip_pending = true;
    spin_unlock_irqrestore(&adp->flip_lock, flags);

    dev_dbg(adp->dev, "plane update: fb phys=0x%08llx -> back set %u (deferred flip)\n", (unsigned long long)paddr,
            back);
}

static void altdp_plane_atomic_disable(struct drm_plane *plane, struct drm_atomic_state *state)
{
    struct altdp_device *adp = to_altdp(plane->dev);

    vfr_wr(adp, VFR_RUN, VFR_RUN_STOP);
}

static const struct drm_plane_helper_funcs altdp_plane_helper_funcs = {
    .atomic_update = altdp_plane_atomic_update,
    .atomic_disable = altdp_plane_atomic_disable,
};

static const struct drm_plane_funcs altdp_plane_funcs = {
    .update_plane = drm_atomic_helper_update_plane,
    .disable_plane = drm_atomic_helper_disable_plane,
    .destroy = drm_plane_cleanup,
    .reset = drm_atomic_helper_plane_reset,
    .atomic_duplicate_state = drm_atomic_helper_plane_duplicate_state,
    .atomic_destroy_state = drm_atomic_helper_plane_destroy_state,
};

/* =========================================================================
 * DRM CRTC helpers
 * (CRTC = VFR run-control + AXI2CV timing)
 * =========================================================================*/

static void altdp_crtc_mode_set_nofb(struct drm_crtc *crtc)
{
    struct altdp_device *adp = to_altdp(crtc->dev);
    const struct drm_display_mode *mode = &crtc->state->adjusted_mode;
    int ret;

    /* Cache mode for VFR programming. */
    drm_mode_copy(&adp->mode, mode);
    adp->mode_valid = true;

    /* Step 2: set the video clock PIO divider (from DT, see probe). */
    altdp_clk_pio_set_div(adp, adp->clk_pio_div);

    /*
	 * The AXIS video-timing block (altera_dp_axi_2_im) is programmed in
	 * atomic_enable, after VFR starts, so the raster totals are latched
	 * while pixel data is already flowing through the bridge.
	 */
}

static void altdp_crtc_atomic_enable(struct drm_crtc *crtc, struct drm_atomic_state *state)
{
    struct altdp_device *adp = to_altdp(crtc->dev);
    int ret;

    /* Step 4: start VFR streaming buffer set 0.
	 *
	 * altdp_vfr_start() uses adp->fb_phys (the reserved carve-out,
	 * 0xC0000000) as the initial buffer address.  However,
	 * plane_atomic_update() already ran (DRM commit_planes precedes
	 * commit_modeset_enables) and set VFR_BUF_BASE to the GEM DMA
	 * address — which altdp_vfr_start() then overwrites.  Fix: after
	 * vfr_start, re-apply the GEM DMA address from the primary plane
	 * state so VFR reads actual pixel data, not the empty carve-out.
	 */
    altdp_vfr_start(adp, 0, true);

    {
        struct drm_plane_state *ps = crtc->primary->state;

        if (ps && ps->fb && ps->fb->obj[0]) {
            struct drm_gem_dma_object *dma_obj = to_drm_gem_dma_obj(ps->fb->obj[0]);
            u32 dma_base = (u32)dma_obj->dma_addr;

            vfr_wr(adp, VFR_BUF(0, VFR_BUF_BASE), dma_base);
            vfr_wr(adp, VFR_COMMIT, 1);
            dev_info(adp->dev, "VFR: GEM dma_addr=0x%08x → VFR_BUF_BASE\n", dma_base);
        }
    }

    /*
	 * Establish a clean ping-pong baseline: the VFR is now reading set 0,
	 * and any flip staged by the plane update during this modeset commit is
	 * superseded by the buffer we just committed above.  Subsequent plane
	 * updates will alternate set 0 / set 1 from here.
	 */
    spin_lock_irq(&adp->flip_lock);
    adp->active_set = 0;
    adp->pending_set = 0;
    adp->flip_pending = false;
    spin_unlock_irq(&adp->flip_lock);

    /*
	 * Step 5: program the AXIS video-timing block now that pixel data is
	 * flowing (raster totals + per-line clock count for altera_dp_axi_2_im).
	 */
    ret = altdp_axi2cv_program(adp, &adp->mode);
    if (ret)
        dev_warn(adp->dev, "AXIS video-timing program failed: %d\n", ret);

    /* Enable VFR frame-read interrupt for vblank. */
    vfr_wr(adp, VFR_IRQ_CONTROL, 1);

    drm_crtc_vblank_on(crtc);

    /*
	 * Hold a permanent vblank reference for as long as the CRTC is on.
	 *
	 * This driver's only vblank source is the VFR frame-read IRQ, and it
	 * provides no .get_scanout_position / .get_vblank_timestamp callback.
	 * If DRM's vblank-disable timer were allowed to drop the refcount to 0
	 * it would gate the frame IRQ off (enable/disable_vblank), while the
	 * VFR keeps free-running.  drm_crtc_handle_vblank() would then stop
	 * being called and DRM's software vblank counter/timestamp would
	 * freeze; the next flip hands userspace a stale presentation time
	 * (Weston logs "time until next presentation ... is abnormal" and
	 * throttles to a ~60s fallback repaint).  Keeping one reference pins
	 * vblank enabled so the frame IRQ fires every frame and the
	 * presentation clock stays continuously accurate.
	 */
    if (drm_crtc_vblank_get(crtc))
        dev_warn(adp->dev, "failed to pin vblank reference\n");
}

static void altdp_crtc_atomic_disable(struct drm_crtc *crtc, struct drm_atomic_state *state)
{
    struct altdp_device *adp = to_altdp(crtc->dev);

    /* Release the permanent vblank reference taken in atomic_enable. */
    drm_crtc_vblank_put(crtc);

    drm_crtc_vblank_off(crtc);

    /* Disable VFR interrupt and stop. */
    vfr_wr(adp, VFR_IRQ_CONTROL, 0);
    vfr_wr(adp, VFR_IRQ_STATUS, 0xFFFFFFFF);
    vfr_wr(adp, VFR_RUN, VFR_RUN_STOP);
}

static void altdp_crtc_atomic_flush(struct drm_crtc *crtc, struct drm_atomic_state *state)
{
    unsigned long flags;

    /*
	 * Do NOT commit the VFR here.  The buffer-set switch + VFR_COMMIT is
	 * performed at the frame boundary in altdp_vfr_irq (ping-pong double
	 * buffer), so the reader never re-points mid-scan.  We only arm the
	 * flip-complete event; drm_crtc_handle_vblank() sends it from the IRQ
	 * once the switch has landed, telling userspace the old buffer is free.
	 */
    if (crtc->state->event) {
        spin_lock_irqsave(&crtc->dev->event_lock, flags);
        if (drm_crtc_vblank_get(crtc) == 0)
            drm_crtc_arm_vblank_event(crtc, crtc->state->event);
        else
            drm_crtc_send_vblank_event(crtc, crtc->state->event);
        crtc->state->event = NULL;
        spin_unlock_irqrestore(&crtc->dev->event_lock, flags);
    }
}

static int altdp_crtc_enable_vblank(struct drm_crtc *crtc)
{
    struct altdp_device *adp = to_altdp(crtc->dev);

    vfr_wr(adp, VFR_IRQ_CONTROL, 1);
    return 0;
}

static void altdp_crtc_disable_vblank(struct drm_crtc *crtc)
{
    struct altdp_device *adp = to_altdp(crtc->dev);

    vfr_wr(adp, VFR_IRQ_CONTROL, 0);
}

static const struct drm_crtc_helper_funcs altdp_crtc_helper_funcs = {
    .mode_set_nofb = altdp_crtc_mode_set_nofb,
    .atomic_enable = altdp_crtc_atomic_enable,
    .atomic_disable = altdp_crtc_atomic_disable,
    .atomic_flush = altdp_crtc_atomic_flush,
};

static const struct drm_crtc_funcs altdp_crtc_funcs = {
    .set_config = drm_atomic_helper_set_config,
    .destroy = drm_crtc_cleanup,
    .page_flip = drm_atomic_helper_page_flip,
    .reset = drm_atomic_helper_crtc_reset,
    .atomic_duplicate_state = drm_atomic_helper_crtc_duplicate_state,
    .atomic_destroy_state = drm_atomic_helper_crtc_destroy_state,
    .enable_vblank = altdp_crtc_enable_vblank,
    .disable_vblank = altdp_crtc_disable_vblank,
};

/* =========================================================================
 * DRM encoder helpers
 * (encoder = DP TX link training, step 3)
 * =========================================================================*/

static void altdp_encoder_enable(struct drm_encoder *encoder, struct drm_atomic_state *state)
{
    struct altdp_device *adp = to_altdp(encoder->dev);
    u8 link_bw, lane_count;
    int rc;

    /*
     * Step 3: DP link training (native drm_dp_helper path,
     * altera_vvp_dp_link.c).
     *
     * Read the sink's DPCD capabilities and clamp them to what 1080p60
     * needs (no faster than HBR, no wider than 2 lanes), then run the
     * standard clock-recovery + channel-equalisation training against the
     * DP TX core.  Nothing is hardcoded: the rate and lane count come from
     * the attached sink.
     */
    rc = altdp_link_get_caps(&adp->link, &link_bw, &lane_count);
    if (rc) {
        dev_err(adp->dev, "DP: cannot read sink capabilities (rc=%d); skipping link training\n", rc);
        return;
    }

    rc = altdp_link_train(&adp->link, link_bw, lane_count);
    if (rc)
        dev_err(adp->dev, "DP: link training FAILED (rc=%d)\n", rc);
}

static void altdp_encoder_disable(struct drm_encoder *encoder, struct drm_atomic_state *state)
{
    /* Nothing to do: DP TX is reset with the bitstream. */
}

static const struct drm_encoder_helper_funcs altdp_encoder_helper_funcs = {
    .atomic_enable = altdp_encoder_enable,
    .atomic_disable = altdp_encoder_disable,
};

static const struct drm_encoder_funcs altdp_encoder_funcs = {
    .destroy = drm_encoder_cleanup,
};

/* =========================================================================
 * DRM connector helpers
 * (connector = DP sink, HPD + EDID via the native AUX channel)
 * =========================================================================*/

static const struct drm_display_mode altdp_fixed_mode = {
    /*
	 * 1920x1080@60 Hz progressive (CEA-861 VIC 16).
	 *
	 * DRM_MODE macro:  name, type, clock(kHz),
	 *   hdisplay, hsync_start, hsync_end, htotal, hskew,
	 *   vdisplay, vsync_start, vsync_end, vtotal, vscan,
	 *   flags
	 */
    DRM_MODE("1920x1080", DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED, 148500, 1920, 2008, 2052, 2200, 0, 1080, 1084,
             1089, 1125, 0, DRM_MODE_FLAG_PHSYNC | DRM_MODE_FLAG_PVSYNC),
};

static int altdp_connector_get_modes(struct drm_connector *connector)
{
    struct altdp_device *adp = to_altdp(connector->dev);
    struct drm_display_mode *mode, *tmp;
    struct edid *edid;
    bool have_1080p60 = false;

    /*
	 * Read and validate the sink's EDID over the native I2C-over-AUX DDC
	 * channel.  The fixed pixel clock can generate exactly one mode
	 * (1920x1080@60), so:
	 *   - EDID readable and advertises 1080p60 -> offer the fixed mode.
	 *   - EDID readable but no 1080p60          -> offer nothing + warn
	 *     (a clear log instead of a guaranteed-black picture).
	 *   - EDID unreadable (AUX/adapter error)   -> offer the fixed mode
	 *     anyway, so an already-working EDID-less setup is not regressed.
	 */
    edid = drm_get_edid(connector, &adp->link.aux.ddc);
    if (edid) {
        drm_connector_update_edid_property(connector, edid);
        drm_add_edid_modes(connector, edid);
        kfree(edid);

        list_for_each_entry(mode, &connector->probed_modes, head)
        {
            if (mode->hdisplay == 1920 && mode->vdisplay == 1080 && drm_mode_vrefresh(mode) == 60) {
                have_1080p60 = true;
                break;
            }
        }

        /*
		 * Drop every EDID mode: the hardware can only ever drive our
		 * single fixed timing, so we must not advertise the sink's
		 * other resolutions (they would produce a black screen).
		 */
        list_for_each_entry_safe(mode, tmp, &connector->probed_modes, head)
        {
            list_del(&mode->head);
            drm_mode_destroy(connector->dev, mode);
        }

        if (!have_1080p60) {
            drm_warn(&adp->drm, "DP: sink does not advertise 1920x1080@60; offering no modes\n");
            return 0;
        }
    }

    /* Sink supports 1080p60 (or EDID unreadable): offer the fixed mode. */
    mode = drm_mode_duplicate(connector->dev, &altdp_fixed_mode);
    if (!mode)
        return 0;

    drm_mode_probed_add(connector, mode);
    return 1;
}

static enum drm_connector_status altdp_connector_detect(struct drm_connector *connector, bool force)
{
    struct altdp_device *adp = to_altdp(connector->dev);
    u32 status;

    /* HPD level = bit 2 of DPTX_REG_TX_STATUS. */
    status = dptx_rd(adp, DPTX_OFF_TX_STATUS);
    if (status & TX_STATUS_HPD_MASK) {
        dev_dbg(adp->dev, "connector: HPD asserted\n");
        return connector_status_connected;
    }

    dev_dbg(adp->dev, "connector: HPD not asserted (TX_STATUS=0x%x)\n", status);
    return connector_status_disconnected;
}

static const struct drm_connector_helper_funcs altdp_connector_helper_funcs = {
    .get_modes = altdp_connector_get_modes,
};

static const struct drm_connector_funcs altdp_connector_funcs = {
    .detect = altdp_connector_detect,
    .fill_modes = drm_helper_probe_single_connector_modes,
    .destroy = drm_connector_cleanup,
    .reset = drm_atomic_helper_connector_reset,
    .atomic_duplicate_state = drm_atomic_helper_connector_duplicate_state,
    .atomic_destroy_state = drm_atomic_helper_connector_destroy_state,
};

static const struct drm_mode_config_funcs altdp_mode_config_funcs = {
    .fb_create = drm_gem_fb_create,
    .atomic_check = drm_atomic_helper_check,
    .atomic_commit = drm_atomic_helper_commit,
};

/* =========================================================================
 * DRM driver
 * =========================================================================*/

DEFINE_DRM_GEM_DMA_FOPS(altdp_driver_fops);

/*
 * Dumb-buffer allocation with VFR-burst-aligned pitch.
 *
 * The VFR reads the framebuffer as 1024-byte AXI bursts; a line stride that
 * is not a multiple of VFR_STRIDE_ALIGN corrupts pixels (horizontal-hatch
 * artifact).  Round the pitch up so every scanline is an integer number of
 * bursts.  The VFR stride programmed in altdp_vfr_start() uses the same
 * alignment, keeping the hardware stride consistent with the buffer layout.
 */
static int altdp_dumb_create(struct drm_file *file_priv, struct drm_device *drm, struct drm_mode_create_dumb *args)
{
    u32 min_pitch = DIV_ROUND_UP(args->width * args->bpp, 8);

    args->pitch = ALIGN(min_pitch, VFR_STRIDE_ALIGN);
    args->size = (u64)args->pitch * args->height;

    return drm_gem_dma_dumb_create_internal(file_priv, drm, args);
}

/* drm_driver.lastclose was removed in this kernel.  Use postclose instead:
 * called on every DRM fd close, which resets all CRTCs to off so the next
 * opener gets a clean slate (crtc_atomic_enable is called, VFR restarts). */
static void altdp_drm_postclose(struct drm_device *dev, struct drm_file *file)
{
    drm_atomic_helper_shutdown(dev);
}

static const struct drm_driver altdp_drm_driver = {
    .driver_features = DRIVER_MODESET | DRIVER_GEM | DRIVER_ATOMIC,
    .fops = &altdp_driver_fops,
    DRM_GEM_DMA_DRIVER_OPS_WITH_DUMB_CREATE(altdp_dumb_create),
    /*
	 * Reset all CRTCs to off when the last DRM client closes the device.
	 * Without this, a second modetest run sees the CRTC still "active" in
	 * DRM state (leftover from the previous run), skips crtc_atomic_enable,
	 * and drm_atomic_helper_wait_for_vblanks times out on a stopped VFR,
	 * followed by "failed to page flip: EBUSY".
	 */
    .postclose = altdp_drm_postclose,
    .name = DRIVER_NAME,
    .desc = DRIVER_DESC,
    .major = DRIVER_MAJOR,
    .minor = DRIVER_MINOR,
};

/* =========================================================================
 * Platform driver probe / remove
 * =========================================================================*/

/**
 * altdp_ioremap_resource - ioremap a named DT reg entry or fall back to a
 *                           fixed physical address.
 *
 * The hardware blocks (VFR, DP TX, Clock PIO) each have a fixed physical
 * address that matches the QSF pin assignments and is present in the DT.
 * If the DT property is absent we fall back to the known physical addresses
 * from altera_vvp_dp_regs.h.
 */
static void __iomem *altdp_map_phys(struct device *dev, resource_size_t phys, resource_size_t size, const char *name)
{
    void __iomem *p = ioremap(phys, size);

    if (!p)
        dev_err(dev, "ioremap(%s, 0x%llx, 0x%llx) failed\n", name, (unsigned long long)phys, (unsigned long long)size);
    else
        dev_dbg(dev, "mapped %s: phys=0x%llx size=0x%llx virt=%p\n", name, (unsigned long long)phys,
                (unsigned long long)size, p);
    return p;
}

static int altdp_probe(struct platform_device *pdev)
{
    struct altdp_device *adp;
    struct drm_device *drm;
    struct device *dev = &pdev->dev;
    struct device_node *mem_np;
    struct resource mem_res;
    int ret;

    dev_info(dev, "probing Altera Agilex DP DRM/KMS driver\n");

    adp = devm_drm_dev_alloc(dev, &altdp_drm_driver, struct altdp_device, drm);
    if (IS_ERR(adp))
        return PTR_ERR(adp);

    drm = &adp->drm;
    adp->dev = dev;
    platform_set_drvdata(pdev, adp);

    spin_lock_init(&adp->flip_lock);
    adp->active_set = 0;
    adp->pending_set = 0;
    adp->flip_pending = false;

    /*
	 * The VFR reads DDR over the F2SDRAM bridge, whose BASE register is
	 * 32-bit. Constrain this device's DMA/coherent mask to 32 bits so any
	 * GEM buffer the DRM helpers allocate is guaranteed to sit in the lower
	 * 4 GB window the VFR BASE register can address.
	 */
    ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(32));
    if (ret) {
        dev_err(dev, "32-bit DMA mask not supported: %d\n", ret);
        return ret;
    }

    /* ---- MMIO mappings ------------------------------------------------- */
    adp->dptx_base = altdp_map_phys(dev, DPTX_PHYS_BASE, DPTX_SPAN, "dptx");
    if (!adp->dptx_base)
        return -ENOMEM;

    /*
     * Set up the native DisplayPort AUX + link-training path.  This wires up
     * the drm_dp_aux channel (DPCD access, link training, and I2C-over-AUX
     * EDID reads); the adapter is registered later, once the connector exists.
     */
    altdp_link_init(&adp->link, &adp->drm, dev, adp->dptx_base);

    adp->vfr_base = altdp_map_phys(dev, VFR_PHYS_BASE, VFR_SPAN, "vfr");
    if (!adp->vfr_base) {
        ret = -ENOMEM;
        goto err_unmap_dptx;
    }

    adp->pio_base = altdp_map_phys(dev, CLK_PIO_PHYS_BASE, CLK_PIO_SPAN, "clk_pio");
    if (!adp->pio_base) {
        ret = -ENOMEM;
        goto err_unmap_vfr;
    }

    /*
     * Video clock PIO divider.  Board/FPGA property: the PIO divides the
     * 148.5 MHz system clock by the divide ratio N to make the DP source
     * video clock (N = 4 => 37.125 MHz, 4 pixels/clock => 148.5 MHz pixel
     * rate).  The DT carries the human-friendly ratio N
     * ("intel,vid-clk-divider"); CLK_PIO_DATA is programmed with N - 1.  Read
     * it from DT so a respin for a different pixel clock needs only a .dts
     * edit, not a driver change.  Fall back to the 1080p60 default when
     * absent.
     */
    {
        u32 vid_clk_ratio;

        if (of_property_read_u32(dev->of_node, "intel,vid-clk-divider", &vid_clk_ratio)) {
            adp->clk_pio_div = CLK_PIO_DIV_DEFAULT;
            dev_info(dev, "no intel,vid-clk-divider in DT; using default divide-by-%u\n", CLK_PIO_DIV_DEFAULT + 1);
        } else if (vid_clk_ratio < 1) {
            dev_warn(dev, "intel,vid-clk-divider=%u invalid (must be >= 1); using default divide-by-%u\n",
                     vid_clk_ratio, CLK_PIO_DIV_DEFAULT + 1);
            adp->clk_pio_div = CLK_PIO_DIV_DEFAULT;
        } else {
            adp->clk_pio_div = vid_clk_ratio - 1;
            dev_info(dev, "video clock PIO divide-by-%u (from DT)\n", vid_clk_ratio);
        }
    }

    /* ---- Reserved framebuffer carve-out -------------------------------- */
    mem_np = of_parse_phandle(dev->of_node, "memory-region", 0);
    if (!mem_np) {
        dev_err(dev, "no memory-region DT property\n");
        ret = -ENODEV;
        goto err_unmap_pio;
    }

    ret = of_address_to_resource(mem_np, 0, &mem_res);
    of_node_put(mem_np);
    if (ret) {
        dev_err(dev, "failed to get memory-region address: %d\n", ret);
        goto err_unmap_pio;
    }

    adp->fb_phys = mem_res.start;
    adp->fb_size = resource_size(&mem_res);

    if (adp->fb_phys > 0xFFFFFFFFULL) {
        dev_err(dev, "framebuffer base 0x%llx > 4 GB; VFR BASE register is 32-bit\n", (unsigned long long)adp->fb_phys);
        ret = -EINVAL;
        goto err_unmap_pio;
    }

    /*
	 * Map the framebuffer write-combining (uncached). The VFR reads it over
	 * the non-coherent F2SDRAM bridge, so CPU writes must reach DDR without
	 * relying on cache snooping.
	 */
    adp->fb_virt = ioremap_wc(adp->fb_phys, adp->fb_size);
    if (!adp->fb_virt) {
        dev_err(dev, "ioremap_wc(fb, 0x%llx) failed\n", (unsigned long long)adp->fb_phys);
        ret = -ENOMEM;
        goto err_unmap_pio;
    }

    dev_info(dev, "framebuffer: phys=0x%llx size=0x%zx\n", (unsigned long long)adp->fb_phys, adp->fb_size);

    /* ---- VFR identity check -------------------------------------------- */
    {
        u32 vid_pid = vfr_rd(adp, VFR_VID_PID);

        if (vid_pid == 0 || vid_pid == 0xFFFFFFFF) {
            dev_err(dev, "VFR_VID_PID=0x%08x - hardware not accessible\n", vid_pid);
            ret = -ENODEV;
            goto err_unmap_fb;
        }
        if (vid_pid != VFR_VID_PID_EXPECT)
            dev_warn(dev, "VFR_VID_PID=0x%08x (expected 0x%08x)\n", vid_pid, (u32)VFR_VID_PID_EXPECT);
        else
            dev_info(dev, "VFR identified (VID/PID=0x%08x)\n", vid_pid);
    }

    /* ---- VFR IRQ ------------------------------------------------------- */
    adp->vfr_irq = platform_get_irq_optional(pdev, 0);
    if (adp->vfr_irq > 0) {
        ret = devm_request_irq(dev, adp->vfr_irq, altdp_vfr_irq, IRQF_SHARED, DRIVER_NAME, adp);
        if (ret) {
            dev_err(dev, "failed to request VFR IRQ %d: %d\n", adp->vfr_irq, ret);
            goto err_unmap_fb;
        }
        dev_info(dev, "VFR IRQ %d registered\n", adp->vfr_irq);
    } else {
        dev_info(dev, "no VFR IRQ; vblank events not available\n");
    }

    /* ---- DRM mode-setting objects -------------------------------------- */
    ret = drmm_mode_config_init(drm);
    if (ret)
        goto err_unmap_fb;

    drm->mode_config.min_width = 1;
    drm->mode_config.max_width = 1920;
    drm->mode_config.min_height = 1;
    drm->mode_config.max_height = 1080;
    drm->mode_config.funcs = &altdp_mode_config_funcs;

    /* Primary plane */
    ret = drm_universal_plane_init(drm, &adp->plane, 1, &altdp_plane_funcs, altdp_plane_formats,
                                   ARRAY_SIZE(altdp_plane_formats), NULL, DRM_PLANE_TYPE_PRIMARY, NULL);
    if (ret) {
        dev_err(dev, "plane init failed: %d\n", ret);
        goto err_unmap_fb;
    }
    drm_plane_helper_add(&adp->plane, &altdp_plane_helper_funcs);

    /* CRTC */
    ret = drm_crtc_init_with_planes(drm, &adp->crtc, &adp->plane, NULL, &altdp_crtc_funcs, NULL);
    if (ret) {
        dev_err(dev, "crtc init failed: %d\n", ret);
        goto err_unmap_fb;
    }
    drm_crtc_helper_add(&adp->crtc, &altdp_crtc_helper_funcs);

    /* Encoder */
    ret = drm_encoder_init(drm, &adp->encoder, &altdp_encoder_funcs, DRM_MODE_ENCODER_TMDS, NULL);
    if (ret) {
        dev_err(dev, "encoder init failed: %d\n", ret);
        goto err_unmap_fb;
    }
    drm_encoder_helper_add(&adp->encoder, &altdp_encoder_helper_funcs);
    adp->encoder.possible_crtcs = drm_crtc_mask(&adp->crtc);

    /* Connector */
    ret = drm_connector_init(drm, &adp->connector, &altdp_connector_funcs, DRM_MODE_CONNECTOR_DisplayPort);
    if (ret) {
        dev_err(dev, "connector init failed: %d\n", ret);
        goto err_unmap_fb;
    }
    drm_connector_helper_add(&adp->connector, &altdp_connector_helper_funcs);
    adp->connector.polled = DRM_CONNECTOR_POLL_CONNECT | DRM_CONNECTOR_POLL_DISCONNECT;
    ret = drm_connector_attach_encoder(&adp->connector, &adp->encoder);
    if (ret) {
        dev_err(dev, "connector attach encoder failed: %d\n", ret);
        goto err_unmap_fb;
    }

    drm_mode_config_reset(drm);

    /* ---- vblank -------------------------------------------------------- */
    if (adp->vfr_irq > 0) {
        ret = drm_vblank_init(drm, 1);
        if (ret)
            dev_warn(dev, "vblank init failed: %d (continuing)\n", ret);
    }

    /* ---- Register the DRM device --------------------------------------- */
    ret = drm_dev_register(drm, 0);
    if (ret) {
        dev_err(dev, "drm_dev_register failed: %d\n", ret);
        goto err_unmap_fb;
    }

    /*
     * Register the AUX channel's I2C adapter so the connector can read the
     * sink's EDID over I2C-over-AUX.  Done after drm_dev_register so no probe
     * step can fail after the adapter is live.
     */
    ret = drm_dp_aux_register(&adp->link.aux);
    if (ret) {
        dev_err(dev, "DP AUX register failed: %d\n", ret);
        drm_dev_unregister(drm);
        goto err_unmap_fb;
    }

    drm_kms_helper_poll_init(drm);

    /*
	 * fbdev emulation is intentionally NOT installed here.  Registering the
	 * generic fbdev-dma client (drm_client_setup) would create /dev/fb0 and
	 * let fbcon bind to it, which takes over the DP output with the Linux
	 * login console instead of leaving it free for the Weston/Wayland
	 * compositor.  Weston drives the CRTC directly via KMS, so no fbdev.
	 */

    dev_info(dev, "registered as %s\n", drm->unique);
    return 0;

err_unmap_fb:
    iounmap(adp->fb_virt);
err_unmap_pio:
    iounmap(adp->pio_base);
err_unmap_vfr:
    iounmap(adp->vfr_base);
err_unmap_dptx:
    iounmap(adp->dptx_base);
    return ret;
}

static void altdp_remove(struct platform_device *pdev)
{
    struct altdp_device *adp = platform_get_drvdata(pdev);

    drm_kms_helper_poll_fini(&adp->drm);
    drm_dp_aux_unregister(&adp->link.aux);
    drm_dev_unregister(&adp->drm);
    drm_atomic_helper_shutdown(&adp->drm);

    iounmap(adp->fb_virt);
    iounmap(adp->pio_base);
    iounmap(adp->vfr_base);
    iounmap(adp->dptx_base);
}

static const struct of_device_id altdp_of_match[] = { { .compatible = "altera,agilex5-dp" }, { /* sentinel */ } };
MODULE_DEVICE_TABLE(of, altdp_of_match);

static struct platform_driver altdp_platform_driver = {
	.probe  = altdp_probe,
	.remove = altdp_remove,
	.driver = {
		.name           = DRIVER_NAME,
		.of_match_table = altdp_of_match,
	},
};

module_platform_driver(altdp_platform_driver);

MODULE_AUTHOR("Altera Corporation");
MODULE_DESCRIPTION(DRIVER_DESC);
MODULE_LICENSE("GPL v2");
