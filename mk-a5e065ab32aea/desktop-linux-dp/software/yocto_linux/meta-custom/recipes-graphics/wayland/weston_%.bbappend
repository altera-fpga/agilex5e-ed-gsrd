# The Agilex 5 DP demo runs Weston (DRM backend, Pixman software renderer) as the
# single compositor for the customer Qt application (SAStudio4). Interacting with
# the app - moving the pointer and opening its menus/popups - intermittently
# triggers a known libweston coordinate-conversion assertion:
#
#   weston: libweston/compositor.c: weston_coord_global_to_surface:
#           Assertion `!view->transform.dirty' failed.
#   weston-drm.service: Main process exited, code=dumped, status=6/ABRT
#
# The assert fires when a pointer event maps a global coordinate onto a view
# whose transform has not yet been recomputed (dirty). The computation still
# returns a usable, at-most-one-frame-stale coordinate, so the abort is a
# hard-stop on an otherwise recoverable condition. When it aborts, systemd
# restarts weston-drm.service, which re-inits the DP output (full modeset +
# link re-train) and blanks the DisplayPort screen - seen by the user as
# "the screen blanked and Weston restarted".
#
# Build Weston with NDEBUG so assert() is compiled out (identical to an upstream
# release build). This keeps the compositor alive during interactive use of the
# customer app. Note this only affects Weston's own assertions, not the DP KMS
# driver or the application.
EXTRA_OEMESON:append = " -Db_ndebug=true"
