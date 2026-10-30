# Roll-your-own Linux

Reference example for building minimal software required for Altera Agilex 5 HPS platforms.

The script guides you through building Arm Trusted Firmware (ATF), U-Boot, the Linux kernel,
and a minimal root filesystem using default configurations. It also downloads the toolchains
needed for the build.

This flow prioritizes simplicity and demonstration over optimization. The resulting SD card
boot image showcases the initial HPS boot flow only. It does **not** configure FPGA core
fabric in U-Boot or Linux.

## Build

From this directory:

```bash
./ryo_linux_sd.sh
```

See [ryo_linux_sd.sh](ryo_linux_sd.sh) for host requirements, output layout, and script options.

To remove build artifacts:

```bash
./clean_build.sh
```
