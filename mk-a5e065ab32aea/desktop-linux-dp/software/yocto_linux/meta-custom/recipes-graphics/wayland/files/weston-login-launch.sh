# Launch the Weston DisplayPort desktop after an interactive root login
# (approach A: console login gates the GUI).
#
# weston-drm.service is installed but NOT auto-enabled at boot, so nothing
# drives the DP output until a user logs in.  When root logs in on the console
# (serial / ser2net telnet) the desktop is brought up on the DisplayPort
# monitor - mirroring the "telnet as root with an empty password -> desktop"
# expectation.  'systemctl start' is idempotent, so a weston-terminal or any
# nested login shell that re-sources this file is a harmless no-op.
case "$-" in
*i*)
	if [ "$(id -u)" = "0" ] && command -v systemctl >/dev/null 2>&1; then
		systemctl is-active --quiet weston-drm.service ||
			systemctl start weston-drm.service >/dev/null 2>&1 || true
	fi
	;;
esac
