FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Override the stock weston.ini with one that forces the Pixman (software)
# renderer.  The Agilex 5 MK-A5E065AB32AEA has no GPU, so Weston's default
# GL/GBM renderer cannot initialise; the DRM backend + Pixman renderer drives
# the altera-vvp-dp KMS device using dumb buffers and atomic page-flips.
SRC_URI:append = " file://weston.ini"

# --- Start Weston after console login (approach A) -----------------------
# The stock weston.service runs as the unprivileged 'weston' user and is
# WantedBy=graphical.target.  On this headless demo image the default target is
# multi-user.target, so graphical.target is never reached and Weston never
# comes up on its own.  Ship a dedicated root service (weston-drm.service) that
# runs the exact DRM/Pixman command line used for the DP demo.
#
# The DP KMS driver registers no fbdev/fbcon (Weston is the only allowed CRTC
# client - a second client re-committing drops the DP link), so there is no
# on-screen text console for a getty login.  Instead we gate the GUI behind the
# normal console login: weston-drm.service is installed but NOT auto-enabled,
# and a /etc/profile.d hook starts it when root logs in on the console (serial /
# ser2net telnet).  So the flow is: boot -> console login prompt -> root + empty
# password -> Weston desktop appears on the DisplayPort output.
#
# SYSTEMD_SERVICE below overrides the stock "weston.service weston.socket" list;
# the stock units are still installed but left disabled so two compositors do
# not contend for DRM master.
SRC_URI:append = " file://weston-drm.service"
SRC_URI:append = " file://weston-login-launch.sh"

do_install:append() {
    install -D -p -m0644 ${UNPACKDIR}/weston-drm.service \
        ${D}${systemd_system_unitdir}/weston-drm.service
    install -D -p -m0644 ${UNPACKDIR}/weston-login-launch.sh \
        ${D}${sysconfdir}/profile.d/weston-login-launch.sh
}

SYSTEMD_SERVICE:${PN} = "weston-drm.service"
# Installed but not started at boot; the profile.d hook starts it on root login.
SYSTEMD_AUTO_ENABLE = "disable"

# The stock recipe lists its unit files in FILES:${PN} explicitly (no wildcard),
# so our extra unit and the login hook must be added or packaging fails the
# installed-not-shipped QA check.
FILES:${PN} += "${systemd_system_unitdir}/weston-drm.service"
FILES:${PN} += "${sysconfdir}/profile.d/weston-login-launch.sh"
