# Roll-your-own OP-TEE

Reference example for building an OP-TEE-enabled software stack for the Agilex 5 E-Series
013B Development Kit.

The script guides you through building OP-TEE OS, the OP-TEE client, a hello_world trusted
application example, Arm Trusted Firmware (ATF), U-Boot, and the Linux kernel using patched
sources for this board. It also downloads host dependencies and toolchains needed for the build.

This flow prioritizes simplicity and demonstration over optimization. The resulting SD card
boot image showcases OP-TEE bring-up on the 013B Baseline System Example Design.

## Build

From this directory:

```bash
./ryo_optee_sd.sh
```

See [ryo_optee_sd.sh](ryo_optee_sd.sh) for host requirements, output layout, and script options.

To remove build artifacts:

```bash
./clean_build.sh
```
