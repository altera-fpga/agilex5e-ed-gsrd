// SPDX-License-Identifier: GPL-2.0-only
/*
 * altera_vvp_dp_link.c - Native DisplayPort AUX + link training for the
 *                        Altera Agilex VVP DisplayPort DRM/KMS driver.
 *
 * A self-contained clock-recovery + equalisation link-training implementation
 * built on the kernel's own GPL DisplayPort helpers (drm_dp_aux /
 * drm_dp_helper). It contains no third-party code:
 *
 *   - The DP protocol logic (DPCD access, link-status decode, CR/EQ done
 *     checks, sink ADJUST_REQUEST decode, training delays) comes entirely
 *     from the kernel's independently-written GPL drm_dp_helper library.
 *   - The only hardware-specific code is the AUX register transaction and
 *     the transceiver swing/pre-emphasis + link-config register writes,
 *     taken from the DP TX core register map (a hardware fact).
 *
 * Register offsets and bit layouts live in altera_vvp_dp_regs.h.
 */

#include <linux/delay.h>
#include <linux/device.h>
#include <linux/io.h>
#include <linux/iopoll.h>
#include <linux/kernel.h>

#include <drm/drm_device.h>
#include <drm/drm_print.h>
#include <drm/display/drm_dp.h>
#include <drm/display/drm_dp_helper.h>

#include "altera_vvp_dp.h"
#include "altera_vvp_dp_regs.h"

/* Standard DP training-loop bounds (DP 1.4 §3.5.1.3). */
#define ALTDP_CR_MAX_TRIES 10
#define ALTDP_CR_MAX_VOLT_TRIES 5
#define ALTDP_EQ_MAX_TRIES 6

/* -------------------------------------------------------------------------
 * DP TX register access (byte-addressed ioremap mapping)
 * -------------------------------------------------------------------------*/

static inline u32 dptx_rd(struct altdp_link *link, unsigned int off)
{
    return ioread32(link->dptx_base + off);
}

static inline void dptx_wr(struct altdp_link *link, unsigned int off, u32 val)
{
    iowrite32(val, link->dptx_base + off);
}

static void altdp_aux_reset(struct altdp_link *link)
{
    dptx_wr(link, DPTX_OFF_AUX_RESET, 0x1);
    udelay(400);
    dptx_wr(link, DPTX_OFF_AUX_RESET, 0x0);
}

/* -------------------------------------------------------------------------
 * AUX channel transfer callback
 *
 * One AUX transaction against the DP TX AUX controller.  The core packs the
 * DP request code into COMMAND[7:4] identically for native DPCD and
 * I2C-over-AUX (EDID), so a single code path handles both:
 *   COMMAND  = (request & 0xF) << 4 | addr[19:16]
 *   BYTE0    = addr[15:8]      (0 for the 7-bit I2C address)
 *   BYTE1    = addr[7:0]       (I2C slave address for I2C transfers)
 *   BYTE2    = size - 1        (omitted for address-only I2C probes)
 *   BYTE3..  = write payload
 *   CONTROL  = message length  (3 = address-only, 4 = read/header,
 *                               4 + size = write; triggers transmission)
 * then poll CONTROL[31] (done) and decode the reply from COMMAND[7:4]: the
 * native/AUX-layer reply is in bits [5:4], and an I2C-over-AUX transfer adds
 * an I2C-layer reply in bits [7:6].
 * -------------------------------------------------------------------------*/
static ssize_t altdp_aux_transfer(struct drm_dp_aux *aux, struct drm_dp_aux_msg *msg)
{
    struct altdp_link *link = container_of(aux, struct altdp_link, aux);
    bool is_native = msg->request & DP_AUX_NATIVE_WRITE; /* bit 3: native */
    bool is_read = msg->request & DP_AUX_I2C_READ; /* bit 0: read   */
    u8 *buf = msg->buffer;
    u32 ctrl, hw_reply, xmit;
    unsigned int i, len;
    int ret;

    if (msg->size > AUX_MAX_PAYLOAD)
        return -E2BIG;

    /* Wait for the AUX controller to be idle. */
    ret = readl_poll_timeout(link->dptx_base + DPTX_OFF_AUX_CONTROL, ctrl, ctrl & AUX_CTRL_READY, 1,
                             AUX_READY_TIMEOUT_US);
    if (ret) {
        altdp_aux_reset(link);
        return -ETIMEDOUT;
    }

    /*
	 * Program the header.  (request & 0xF) << 4 yields the core's command
	 * byte for every request type: native wr/rd 0x80/0x90, I2C wr/rd
	 * 0x00/0x10, with the I2C MOT bit (0x40) already in place.  The upper
	 * DPCD address nibble is OR'd in; it is 0 for a 7-bit I2C address.
	 */
    dptx_wr(link, DPTX_OFF_AUX_COMMAND, ((u32)(msg->request & 0xF) << 4) | ((msg->address >> 16) & 0x0F));
    dptx_wr(link, DPTX_OFF_AUX_BYTE(0), (msg->address >> 8) & 0xFF);
    dptx_wr(link, DPTX_OFF_AUX_BYTE(1), msg->address & 0xFF);
    if (msg->size)
        dptx_wr(link, DPTX_OFF_AUX_BYTE(2), msg->size - 1);

    if (!is_read)
        for (i = 0; i < msg->size; i++)
            dptx_wr(link, DPTX_OFF_AUX_BYTE(3 + i), buf[i]);

    /* Message length triggers transmission. */
    if (msg->size == 0)
        xmit = AUX_ADDR_ONLY_BYTES; /* address-only I2C probe    */
    else if (is_read)
        xmit = AUX_HDR_BYTES; /* header only, data returns */
    else
        xmit = AUX_HDR_BYTES + msg->size; /* header + write payload    */
    dptx_wr(link, DPTX_OFF_AUX_CONTROL, xmit);

    /* Wait for the reply. */
    ret =
        readl_poll_timeout(link->dptx_base + DPTX_OFF_AUX_CONTROL, ctrl, ctrl & AUX_CTRL_DONE, 1, AUX_REPLY_TIMEOUT_US);
    if (ret) {
        altdp_aux_reset(link);
        return -ETIMEDOUT;
    }

    hw_reply = dptx_rd(link, DPTX_OFF_AUX_COMMAND) & AUX_REPLY_MASK;

    /* Native/AUX-layer reply (bits [5:4]), shared by native and I2C. */
    switch (hw_reply & AUX_AUX_REPLY_MASK) {
    case AUX_REPLY_ACK:
        msg->reply = 0; /* DP_AUX_NATIVE_REPLY_ACK == 0 */
        break;
    case AUX_REPLY_NACK:
        msg->reply = DP_AUX_NATIVE_REPLY_NACK;
        return msg->size;
    case AUX_REPLY_DEFER:
        msg->reply = DP_AUX_NATIVE_REPLY_DEFER;
        return msg->size;
    default:
        return -EIO;
    }

    /* For I2C-over-AUX also decode the I2C-layer reply (bits [7:6]). */
    if (!is_native) {
        switch (hw_reply & AUX_I2C_REPLY_MASK) {
        case AUX_I2C_REPLY_ACK:
            msg->reply |= DP_AUX_I2C_REPLY_ACK;
            break;
        case AUX_I2C_REPLY_NACK:
            msg->reply |= DP_AUX_I2C_REPLY_NACK;
            return msg->size;
        case AUX_I2C_REPLY_DEFER:
            msg->reply |= DP_AUX_I2C_REPLY_DEFER;
            return msg->size;
        }
    }

    if (!is_read)
        return msg->size;

    /* Reply length field counts the reply command byte; data follows it. */
    len = dptx_rd(link, DPTX_OFF_AUX_CONTROL) & AUX_CTRL_LEN_MASK;
    len = len ? len - 1 : 0;
    if (len > msg->size)
        len = msg->size;
    for (i = 0; i < len; i++)
        buf[i] = dptx_rd(link, DPTX_OFF_AUX_BYTE(i)) & 0xFF;

    return len;
}

int altdp_link_init(struct altdp_link *link, struct drm_device *drm, struct device *dev, void __iomem *dptx_base)
{
    link->dptx_base = dptx_base;
    link->drm = drm;
    link->dev = dev;

    link->aux.name = "altera-vvp-dp-aux";
    link->aux.dev = dev;
    link->aux.drm_dev = drm;
    link->aux.transfer = altdp_aux_transfer;
    drm_dp_aux_init(&link->aux);

    altdp_aux_reset(link);
    return 0;
}

int altdp_link_get_caps(struct altdp_link *link, u8 *link_bw, u8 *lane_count)
{
    u8 cap[2];

    if (drm_dp_dpcd_read(&link->aux, DP_MAX_LINK_RATE, cap, sizeof(cap)) < 0) {
        drm_err(link->drm, "DP: DPCD capability read failed (no sink?)\n");
        return -EIO;
    }

    /*
	 * Clamp the sink's advertised maximum DOWN to what 1080p60 needs.
	 * 1920x1080@60 24bpp is ~3.2 Gbps; HBR (2.7 Gbps/lane) x2 lanes is the
	 * minimum viable configuration with comfortable headroom, so never
	 * train faster or wider than that even when the sink can.  A sink that
	 * advertises less (e.g. RBR or a single lane) is respected as-is; link
	 * training then reports whether it can actually carry the mode.
	 * The DP link-rate codes are numerically ordered (RBR 0x06 < HBR 0x0a <
	 * HBR2 0x14 < HBR3 0x1e), so min_t() clamps them correctly.
	 */
    *link_bw = min_t(u8, cap[0], DP_LINK_BW_2_7);
    *lane_count = min_t(u8, cap[1] & DP_MAX_LANE_COUNT_MASK, 2);
    if (*lane_count == 0) {
        drm_err(link->drm, "DP: sink reports zero lanes\n");
        return -EIO;
    }

    return 0;
}

/* -------------------------------------------------------------------------
 * Link training (native CR + EQ using drm_dp_helper)
 * -------------------------------------------------------------------------*/

/* Program the transceiver drive settings for every lane, then apply them. */
static void altdp_program_drive(struct altdp_link *link, unsigned int lane_count, const u8 volt[4], const u8 pre[4])
{
    unsigned int lane;

    for (lane = 0; lane < 4; lane++) {
        u32 val = (lane < lane_count) ? DPTX_PRE_VOLT(pre[lane], volt[lane]) : 0;

        dptx_wr(link, DPTX_OFF_PRE_VOLT(lane), val);
    }
    dptx_wr(link, DPTX_OFF_RECONFIG, DPTX_RECONFIG_DRIVE);
}

/* Select the local TX_CONTROL pattern source without disturbing link config. */
static void altdp_set_tx_pattern(struct altdp_link *link, u32 pattern)
{
    u32 ctrl = dptx_rd(link, DPTX_OFF_TX_CONTROL);

    ctrl &= ~TX_CTRL_PATTERN_MASK;
    ctrl |= pattern & TX_CTRL_PATTERN_MASK;
    dptx_wr(link, DPTX_OFF_TX_CONTROL, ctrl);
}

/*
 * Read the sink's per-lane ADJUST_REQUEST and translate it into raw
 * swing/pre-emphasis levels (0..3) plus the DP_TRAINING_LANE_SET bytes.
 */
static void altdp_get_adjust(const u8 status[DP_LINK_STATUS_SIZE], unsigned int lane_count, u8 volt[4], u8 pre[4],
                             u8 lane_set[4])
{
    unsigned int lane;

    for (lane = 0; lane < lane_count; lane++) {
        u8 v = drm_dp_get_adjust_request_voltage(status, lane) & DP_TRAIN_VOLTAGE_SWING_MASK;
        u8 p = drm_dp_get_adjust_request_pre_emphasis(status, lane) >> DP_TRAIN_PRE_EMPHASIS_SHIFT;

        volt[lane] = v;
        pre[lane] = p;
        lane_set[lane] = v | (p << DP_TRAIN_PRE_EMPHASIS_SHIFT);
        if (v >= 3)
            lane_set[lane] |= DP_TRAIN_MAX_SWING_REACHED;
        if (p >= 3)
            lane_set[lane] |= DP_TRAIN_MAX_PRE_EMPHASIS_REACHED;
    }
    for (; lane < 4; lane++) {
        volt[lane] = 0;
        pre[lane] = 0;
        lane_set[lane] = 0;
    }
}

static bool altdp_max_swing(const u8 volt[4], unsigned int lane_count)
{
    unsigned int lane;

    for (lane = 0; lane < lane_count; lane++)
        if (volt[lane] < 3)
            return false;
    return true;
}

/* Clock recovery: TP1 until DP_LANE_CR_DONE on every lane. */
static int altdp_train_cr(struct altdp_link *link, const u8 dpcd[DP_RECEIVER_CAP_SIZE], unsigned int lane_count,
                          u8 volt[4], u8 pre[4], u8 lane_set[4])
{
    u8 status[DP_LINK_STATUS_SIZE];
    unsigned int tries = 0, volt_tries = 0;
    u8 prev_v0 = 0xff;

    /* Source + sink into TP1. */
    altdp_program_drive(link, lane_count, volt, pre);
    altdp_set_tx_pattern(link, TX_PATTERN_TP1);
    if (drm_dp_dpcd_writeb(&link->aux, DP_TRAINING_PATTERN_SET, DP_TRAINING_PATTERN_1 | DP_LINK_SCRAMBLING_DISABLE) < 0)
        return -EIO;

    for (;;) {
        if (drm_dp_dpcd_write(&link->aux, DP_TRAINING_LANE0_SET, lane_set, lane_count) < 0)
            return -EIO;

        drm_dp_link_train_clock_recovery_delay(&link->aux, dpcd);

        if (drm_dp_dpcd_read_link_status(&link->aux, status) < 0)
            return -EIO;

        if (drm_dp_clock_recovery_ok(status, lane_count))
            return 0;

        if (++tries >= ALTDP_CR_MAX_TRIES)
            break;

        /* Track voltage-swing retries at the same level (DP §3.5.1.3). */
        altdp_get_adjust(status, lane_count, volt, pre, lane_set);
        if (volt[0] == prev_v0)
            volt_tries++;
        else
            volt_tries = 1;
        prev_v0 = volt[0];
        if (volt_tries >= ALTDP_CR_MAX_VOLT_TRIES)
            break;
        if (altdp_max_swing(volt, lane_count) && volt_tries > 1)
            break;

        altdp_program_drive(link, lane_count, volt, pre);
    }

    return -EIO;
}

/* Channel equalisation: TP2/3/4 until EQ + symbol lock + interlane align. */
static int altdp_train_eq(struct altdp_link *link, const u8 dpcd[DP_RECEIVER_CAP_SIZE], unsigned int lane_count,
                          u8 volt[4], u8 pre[4], u8 lane_set[4])
{
    u8 status[DP_LINK_STATUS_SIZE];
    u32 tx_pattern;
    u8 tps;
    unsigned int tries;

    /* Pick the strongest equalisation pattern the sink supports. */
    if (dpcd[DP_MAX_DOWNSPREAD] & DP_TPS4_SUPPORTED) {
        tx_pattern = TX_PATTERN_TP4;
        tps = DP_TRAINING_PATTERN_4;
    } else if (dpcd[DP_MAX_LANE_COUNT] & DP_TPS3_SUPPORTED) {
        tx_pattern = TX_PATTERN_TP3;
        tps = DP_TRAINING_PATTERN_3 | DP_LINK_SCRAMBLING_DISABLE;
    } else {
        tx_pattern = TX_PATTERN_TP2;
        tps = DP_TRAINING_PATTERN_2 | DP_LINK_SCRAMBLING_DISABLE;
    }

    altdp_set_tx_pattern(link, tx_pattern);
    if (drm_dp_dpcd_writeb(&link->aux, DP_TRAINING_PATTERN_SET, tps) < 0)
        return -EIO;

    for (tries = 0; tries < ALTDP_EQ_MAX_TRIES; tries++) {
        /* Program current drive (CR's final settings on the first pass). */
        altdp_program_drive(link, lane_count, volt, pre);
        if (drm_dp_dpcd_write(&link->aux, DP_TRAINING_LANE0_SET, lane_set, lane_count) < 0)
            return -EIO;

        drm_dp_link_train_channel_eq_delay(&link->aux, dpcd);

        if (drm_dp_dpcd_read_link_status(&link->aux, status) < 0)
            return -EIO;

        /* CR must still hold before EQ can be trusted. */
        if (!drm_dp_clock_recovery_ok(status, lane_count))
            return -EIO;

        if (drm_dp_channel_eq_ok(status, lane_count))
            return 0;

        /* Apply the sink's requested drive for the next pass. */
        altdp_get_adjust(status, lane_count, volt, pre, lane_set);
    }

    return -EIO;
}

/* Single attempt to train at exactly the given link rate and lane count. */
static int altdp_link_train_once(struct altdp_link *link, u8 link_bw, u8 lane_count)
{
    u8 dpcd[DP_RECEIVER_CAP_SIZE];
    u8 volt[4] = {}, pre[4] = {}, lane_set[4] = {};
    bool enhanced;
    u32 ctrl;
    int ret;

    if (drm_dp_dpcd_read(&link->aux, DP_DPCD_REV, dpcd, sizeof(dpcd)) < 0) {
        drm_err(link->drm, "DP: DPCD read failed (no sink?)\n");
        return -EIO;
    }
    enhanced = dpcd[DP_MAX_LANE_COUNT] & DP_ENHANCED_FRAME_CAP;

    /* Program the DP TX link configuration and reconfigure the transceiver. */
    ctrl = dptx_rd(link, DPTX_OFF_TX_CONTROL);
    ctrl &= ~(TX_CTRL_RATE_MASK | TX_CTRL_ENHANCED_FRAME | TX_CTRL_PRECODE_DISABLE | TX_CTRL_CODING_MASK |
              TX_CTRL_LANE_MASK | TX_CTRL_PATTERN_MASK);
    ctrl |= (u32)link_bw << TX_CTRL_RATE_SHIFT;
    ctrl |= TX_CODING_8B10B << TX_CTRL_CODING_SHIFT;
    ctrl |= (u32)lane_count << TX_CTRL_LANE_SHIFT;
    if (enhanced)
        ctrl |= TX_CTRL_ENHANCED_FRAME;
    ctrl |= TX_PATTERN_IDLE;
    dptx_wr(link, DPTX_OFF_TX_CONTROL, ctrl);

    dptx_wr(link, DPTX_OFF_RECONFIG, DPTX_RECONFIG_LINK);
    usleep_range(DPTX_RECONFIG_WAIT_US, DPTX_RECONFIG_WAIT_US + 5000);

    /* Bring the sink to D0 and clear any residual training pattern. */
    drm_dp_dpcd_writeb(&link->aux, DP_SET_POWER, DP_SET_POWER_D0);
    drm_dp_dpcd_writeb(&link->aux, DP_TRAINING_PATTERN_SET, DP_TRAINING_PATTERN_DISABLE);

    /* Configure the link on the sink side. */
    drm_dp_dpcd_writeb(&link->aux, DP_MAIN_LINK_CHANNEL_CODING_SET, DP_SET_ANSI_8B10B);
    drm_dp_dpcd_writeb(&link->aux, DP_LINK_BW_SET, link_bw);
    drm_dp_dpcd_writeb(&link->aux, DP_LANE_COUNT_SET, lane_count | (enhanced ? DP_LANE_COUNT_ENHANCED_FRAME_EN : 0));
    drm_dp_dpcd_writeb(&link->aux, DP_DOWNSPREAD_CTRL, 0);

    ret = altdp_train_cr(link, dpcd, lane_count, volt, pre, lane_set);
    if (ret) {
        drm_err(link->drm, "DP: clock recovery failed\n");
        goto out_disable;
    }

    ret = altdp_train_eq(link, dpcd, lane_count, volt, pre, lane_set);
    if (ret) {
        drm_err(link->drm, "DP: channel equalisation failed\n");
        goto out_disable;
    }

    /* Training complete: return the link to normal (video) operation. */
    altdp_set_tx_pattern(link, TX_PATTERN_NORMAL);
    drm_dp_dpcd_writeb(&link->aux, DP_TRAINING_PATTERN_SET, DP_TRAINING_PATTERN_DISABLE);

    drm_info(link->drm, "DP: native link trained OK (BW 0x%02x, %u lanes%s)\n", link_bw, lane_count,
             enhanced ? ", enhanced" : "");
    return 0;

out_disable:
    altdp_set_tx_pattern(link, TX_PATTERN_NORMAL);
    drm_dp_dpcd_writeb(&link->aux, DP_TRAINING_PATTERN_SET, DP_TRAINING_PATTERN_DISABLE);
    return ret;
}

/* Standard DP link rates, ordered low to high, used for fallback stepping. */
static const u8 altdp_link_rates[] = {
    DP_LINK_BW_1_62,
    DP_LINK_BW_2_7,
    DP_LINK_BW_5_4,
    DP_LINK_BW_8_1,
};

/* Return the next lower standard link rate, or 0 if already at the minimum. */
static u8 altdp_lower_rate(u8 link_bw)
{
    int i;

    for (i = ARRAY_SIZE(altdp_link_rates) - 1; i > 0; i--)
        if (altdp_link_rates[i] == link_bw)
            return altdp_link_rates[i - 1];
    return 0;
}

/*
 * Train the link, falling back to a slower or narrower configuration when the
 * sink or cable cannot sustain the requested one (DP spec §3.5.1.6): step the
 * link rate down to the minimum first, then halve the lane count and retry
 * from the top rate.  @link_bw and @lane_count are the maximum (starting)
 * values, as clamped by altdp_link_get_caps().
 */
int altdp_link_train(struct altdp_link *link, u8 link_bw, u8 lane_count)
{
    u8 max_bw = link_bw;
    u8 bw = link_bw;
    u8 lanes = lane_count;

    for (;;) {
        if (altdp_link_train_once(link, bw, lanes) == 0)
            return 0;

        bw = altdp_lower_rate(bw);
        if (bw) {
            drm_warn(link->drm, "DP: retraining at lower rate (BW 0x%02x, %u lanes)\n", bw, lanes);
            continue;
        }

        if (lanes > 1) {
            lanes /= 2;
            bw = max_bw;
            drm_warn(link->drm, "DP: retraining with fewer lanes (BW 0x%02x, %u lanes)\n", bw, lanes);
            continue;
        }

        drm_err(link->drm, "DP: link training exhausted all fallback configurations\n");
        return -EIO;
    }
}
