# Recursive SW build entrypoints for per-project makefiles.

# Define the list of software projects to build
# NOTE: This design boots from SD only; QSPI/XEN are intentionally omitted.
SW_PROJECT_LIST += \
hps_debug \
yocto_linux_sd
