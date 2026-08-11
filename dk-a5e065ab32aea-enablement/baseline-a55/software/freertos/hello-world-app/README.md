# FreeRTOS Hello World Example Design
The FreeRTOS Hello World Example Design showcases the application of the FreeRTOS
framework on the Agilex 5 HPS. The Hello World program uses baseline_a55 as the
hardware design and runs the following actions:
1. Load FPGA bitstream<sup>1</sup>
2. Enable H2F bridge and LWH2F bridge
3. Write to on-chip memory in the FPGA fabric through the H2F bridge
4. Read from on-chip memory in the FPGA fabric through the H2F bridge
5. Read System ID from LWH2F bridge
6. Mirror SWITCH PIO state to LED PIOs

<sup>1</sup> All FreeRTOS HPS boot-first design using QSPI boot must use the load_bitstream_from_qspi() function in main.c to load the FPGA bitstream in phase 2 configuration.

# Build Steps

The expected output of the build process is a JIC file that combines the FPGA bitstream and software binaries that users can program onto the FPGA board with quartus_pgm. The JIC file will contain components laid out in the [QSPI flash PFG file](../qspi_flash_image_agilex5_boot.pfg).

1. Enter the baseline-a55 folder

```bash
cd TOP_DIR/dk-a5e065ab32aea-enablement/baseline-a55
```

2. Generate JIC file (hello_world.hps.jic)

```bash
make software-freertos_hello_world-build-sw
```
hello_world.hps.jic should appear under the software/freertos/hello-world-app directory

(Note: the make target is equivalent to running ./software/freertos/hello-world-app/build.sh)

3. Program the board with JIC file

```bash
quartus_pgm -m jtag -c 1 -o "pvi;hello_world.hps.jic@2"
```
(Refer to the [Quartus Programmer Guide](https://docs.altera.com/r/docs/683039/25.3.1/quartus-prime-pro-edition-user-guide-programmer/scripting-support?tocId=hENJN1rgd6fRQEkgsuUfGQ) for more details on quartus_pgm options)

4. Power Cycle the FPGA board

5. Program outputs can be viewed through Serial Terminal Connection
