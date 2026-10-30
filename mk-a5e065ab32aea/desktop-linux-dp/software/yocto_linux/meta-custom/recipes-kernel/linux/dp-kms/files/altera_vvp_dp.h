/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * altera_vvp_dp.h - Native DisplayPort link-training interface for the
 *                   Altera Agilex VVP DisplayPort DRM/KMS driver.
 *
 * A self-contained AUX channel + CR/EQ link training built entirely on the
 * kernel's own GPL DisplayPort helpers (drm_dp_aux / drm_dp_helper). It
 * carries no third-party code — only DP-spec logic (from the kernel helpers)
 * and hardware register writes to the Agilex DP TX core. The AUX channel also
 * carries I2C-over-AUX so the connector can read the sink's EDID.
 */
#ifndef ALTERA_VVP_DP_H
#define ALTERA_VVP_DP_H

#include <linux/io.h>
#include <linux/types.h>
#include <drm/display/drm_dp_helper.h>

struct device;
struct drm_device;

/**
 * struct altdp_link - native DisplayPort link context.
 * @aux:       AUX channel registered with the DRM DP helpers; its
 *             .transfer() callback drives the DP TX AUX registers directly.
 * @dptx_base: DP TX core MMIO base (byte-addressed ioremap mapping).
 * @drm:       owning DRM device (for logging and aux.drm_dev).
 * @dev:       parent platform device.
 */
struct altdp_link {
    struct drm_dp_aux aux;
    void __iomem *dptx_base;
    struct drm_device *drm;
    struct device *dev;
};

/**
 * altdp_link_init - set up the native AUX channel.
 * @link:      link context to initialise (embedded in the driver device).
 * @drm:       owning DRM device.
 * @dev:       parent platform device.
 * @dptx_base: ioremap'd DP TX core base.
 *
 * Registers the AUX transfer callback and initialises the drm_dp_aux so the
 * DP helpers (DPCD read/write, link-status) can be used. Returns 0 on
 * success or a negative errno.
 */
int altdp_link_init(struct altdp_link *link, struct drm_device *drm, struct device *dev, void __iomem *dptx_base);

/**
 * altdp_link_get_caps - read the sink's link capabilities and clamp them.
 * @link:       initialised link context.
 * @link_bw:    output DPCD link-bandwidth code to train at.
 * @lane_count: output lane count to train.
 *
 * Reads DP_MAX_LINK_RATE / DP_MAX_LANE_COUNT from the sink's DPCD and clamps
 * them down to what 1080p60 needs (no faster than HBR, no wider than 2 lanes).
 * Returns 0 on success or a negative errno if the sink cannot be read.
 */
int altdp_link_get_caps(struct altdp_link *link, u8 *link_bw, u8 *lane_count);

/**
 * altdp_link_train - run native clock-recovery + equalisation link training.
 * @link:       initialised link context.
 * @link_bw:    DPCD link-bandwidth code (e.g. DP_LINK_BW_2_7).
 * @lane_count: number of lanes to train (1, 2 or 4).
 *
 * Programs the DP TX link configuration, then drives the standard DP CR/EQ
 * training loops using the kernel drm_dp_helper functions, adjusting the
 * transceiver swing/pre-emphasis registers per the sink's ADJUST_REQUEST.
 * Returns 0 when the link is up, or a negative errno on failure.
 */
int altdp_link_train(struct altdp_link *link, u8 link_bw, u8 lane_count);

#endif /* ALTERA_VVP_DP_H */
