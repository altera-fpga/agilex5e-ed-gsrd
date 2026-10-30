# Agilex 5 E-Series Baseline Hardware Reference Designs

This repository contains Baseline Hardware Reference Designs for Agilex 5 E-Series System On Chip (SoC) FPGA.
This repository is part of the Baseline System Example Design, which provides a complete solution, including exercising soft IP in the fabric, booting to U-Boot, then Linux, and running sample Linux applications.
Refer to the [HPS Baseline System Example Design User Guide: Agilex 5 FPGA E-Series 065B Premium Development Kit (ES)](https://altera-fpga.github.io/latest/embedded-designs/agilex-5/e-series/premium/gsrd/ug-gsrd-agx5e-premium/) and the [Agilex 5 E-Series Modular Development Kit Baseline System Example Design User Guide](https://altera-fpga.github.io/latest/embedded-designs/agilex-5/e-series/modular/gsrd/ug-gsrd-agx5e-modular/) for more information.

The [designs](#designs) are stored in individual folders. Each design can be opened, modified and compiled by using Quartus Prime software.
Repository releases are tagged for each version of Quartus Prime Software. It is recommended to use the release for your version of Quartus Prime.
These designs demonstrate the system integration between Hard Processor System (HPS) and FPGA IPs.

## Baseline feature
This is applicable to all designs.
- Hard Processor System (HPS) enablement and configuration
  - Enable dual core Arm Cortex-A76 processor
  - Enable dual core Arm Cortex-A55 processor
  - HPS Peripheral and I/O. eg, NAND, SD/MMC, EMAC, USB, SPI, I2C, UART, and GPIO. (depends on the daughter card).
  - HPS Clock and Reset
  - HPS FPGA Bridge and Interrupt
    - Note: The System MMU port in F2H and F2SDRAM bridges are disabled by default in baseline design, unless otherwise specified.
- HPS EMIF configuration (starting 25.1.1 ECC is enabled by default)
- System integration with FPGA IPs
  - Peripheral subsystem that consists of System ID, Programmable I/O (PIO) IP for controlling DIPSW, PushButton, and LEDs.
  - Debug subsystem that consists of JTAG-to-Avalon Master IP to allow System-Console debug activity and FPGA content access through JTAG
  - 256KB of FPGA On-Chip Memory

## Advanced feature
This is only applicable if the feature is enabled.
- Time-Sensitive Networking (TSN): PHY configuration 2 (RGMII from FPGA HVIO)

## Dependency
* Altera Quartus Prime 26.3
* Supported Altera Development Kit
  - Agilex 5 FPGA E-Series 065B Premium Development Kit (ES) DK-A5E065BB32AES1
  - Agilex 5 FPGA E-Series 065B Premium Development Kit DK-A5E065BB32AEA
  - Agilex 5 FPGA E-Series 065A Premium Development Kit DK-A5E065AB32AEA
  ![Agilex 5 E-Series Premium Development Kit](images/agilex5-premium-devkit-es.png)
  - Agilex 5 FPGA E-Series 065B Modular Development Kit (ES) MK-A5E065BB32AES1
  - Agilex 5 FPGA E-Series 065B Modular Development Kit MK-A5E065BB32AEA
  - Agilex 5 FPGA E-Series 065A Modular Development Kit MK-A5E065AB32AEA
  ![Agilex 5 E-Series Modular Development Kit](images/agilex5-modular-devkit-es.png)
  - Agilex 5 FPGA E-Series 013B Development Kit DK-A5E013BM16AEA
  ![Agilex 5 E-Series 013B Development Kit](images/agilex5-013b-devkit.png)
  - Agilex 5 FPGA D-Series 064B Premium Development Kit DK-A5D064AB32BEA
  - Agilex 5 FPGA D-Series 064B Modular Development Kit MK-A5D064AB32BEA
  - Terasic DE25 Nano Development and Education Board
  - Terasic DE25-Standard Development and Education Kit

## Tested platform for the hardware build flow
* SUSE Linux Enterprise Server 15 SP4

## Setup

Several tools are required to be in the path.

* Altera Quartus Prime 26.3
* Python 3.11.5 (only required when using command line to build)

### Example Setup for Altera Quartus Prime tools
This is recommended, when using command line to build.
```bash
export QUARTUS_ROOTDIR=~/alteraFPGA_pro/26.3/quartus
```
Note: Adapt the path above to where Quartus Prime is installed.

```bash
export PATH="$QUARTUS_ROOTDIR/bin:$QUARTUS_ROOTDIR/../qsys/bin:$QUARTUS_ROOTDIR/../niosv/bin:$QUARTUS_ROOTDIR/sopc_builder/bin:$QUARTUS_ROOTDIR/../questa_fe/bin:$QUARTUS_ROOTDIR/../syscon/bin:$QUARTUS_ROOTDIR/../riscfree/RiscFree:$PATH"
```

## Quick start

### Using command line

1. Choose a design under [designs](#designs) for your development kit.
2. Change to that design directory. Example:

```bash
cd dk-a5e065bb32aes1-enablement/baseline-a55
```

3. Follow the README in that directory for command-line build, simulation, and software steps.

### Using Quartus GUI
- Launch Quartus.
- Open the project. Example: dk-a5e065bb32aes1-enablement/baseline-a55/top.qpf
- Click the play button to compile the design.
- The compiled sof can be found in output_files folder of the project path.

### Notes
- Command line and Quartus GUI should not be used intertwined.
- Mixing both design build flows might not generate some fileset correctly and fail the build.


## Designs

This section lists **every** shipped design in the repository, grouped by development kit.
Search here to find which platform folder hosts a design (for example `baseline-a55` or
`tsn-rgmii-hvio`). Each bullet links to that design's README for build instructions and
functional detail; use the platform index link for devkit context and the design list on that
platform.

### Agilex 5 FPGA E-Series 065B Premium Development Kit (ES) DK-A5E065BB32AES1

Platform index: [dk-a5e065bb32aes1-enablement](dk-a5e065bb32aes1-enablement/README.md)

Refer to the individual README for details of each design.

* [dk-a5e065bb32aes1-enablement/baseline-a55](dk-a5e065bb32aes1-enablement/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 ES Premium Devkit with HPS Enablement Expansion Board.
  This design boots from Arm Cortex-A55 core 0 processor.

* [dk-a5e065bb32aes1-enablement/baseline-a76](dk-a5e065bb32aes1-enablement/baseline-a76/README.md) :
  Baseline-A76 design for the A5ED065 ES Premium Devkit with HPS Enablement Expansion Board.
  This design boots from Arm Cortex-A76 core 2 processor.

* [dk-a5e065bb32aes1-enablement/tsn-rgmii-hvio](dk-a5e065bb32aes1-enablement/tsn-rgmii-hvio/README.md) :
  TSN RGMII HVIO design for the A5ED065 ES Premium Devkit with HPS Enablement Expansion Board.
  This design enables RGMII from FPGA HVIO for TSN.

Platform index: [dk-a5e065bb32aes1-test](dk-a5e065bb32aes1-test/README.md)

* [dk-a5e065bb32aes1-test/baseline-a55](dk-a5e065bb32aes1-test/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 ES Premium Devkit with HPS Test Board.

Platform index: [dk-a5e065bb32aes1-emmc](dk-a5e065bb32aes1-emmc/README.md)

* [dk-a5e065bb32aes1-emmc/baseline-a55](dk-a5e065bb32aes1-emmc/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 ES Premium Devkit with HPS NAND Board (This board also offers eMMC).

### Agilex 5 FPGA E-Series 065B Modular Development Kit (ES) MK-A5E065BB32AES1

Platform index: [mk-a5e065bb32aes1](mk-a5e065bb32aes1/README.md)

* [mk-a5e065bb32aes1/baseline-a55](mk-a5e065bb32aes1/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 ES Modular Devkit with speed grade 6 device.

### Agilex 5 FPGA E-Series 013B Development Kit DK-A5E013BM16AEA

Platform index: [dk-a5e013bm16aea](dk-a5e013bm16aea/README.md)

* [dk-a5e013bm16aea/baseline-a55](dk-a5e013bm16aea/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED013 Development Kit.
  This design boots from Arm Cortex-A55 core 0 processor.

### Agilex 5 FPGA E-Series 013B Development Kit DK-A5E013BM16AEA — TSN Daughter Card

Platform index: [dk-a5e013bm16aea-tsn-dc](dk-a5e013bm16aea-tsn-dc/README.md)

* [dk-a5e013bm16aea-tsn-dc/tsn-rgmii-hvio](dk-a5e013bm16aea-tsn-dc/tsn-rgmii-hvio/README.md) :
  TSN RGMII HVIO design for the A5ED013 Development Kit with TSN daughter card.
  This design is not fully validated yet for this release.

### Agilex 5 FPGA E-Series 065B Premium Development Kit DK-A5E065BB32AEA

Platform index: [dk-a5e065bb32aea-enablement](dk-a5e065bb32aea-enablement/README.md)

Refer to the individual README for details of each design.

* [dk-a5e065bb32aea-enablement/baseline-a55](dk-a5e065bb32aea-enablement/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS Enablement Expansion Board.
  This design boots from Arm Cortex-A55 core 0 processor.

* [dk-a5e065bb32aea-enablement/tsn-rgmii-hvio](dk-a5e065bb32aea-enablement/tsn-rgmii-hvio/README.md) :
  TSN RGMII HVIO design for the A5ED065 Premium Devkit with HPS Enablement Expansion Board.
  This design enables RGMII from FPGA HVIO for TSN.

Platform index: [dk-a5e065bb32aea-test](dk-a5e065bb32aea-test/README.md)

* [dk-a5e065bb32aea-test/baseline-a55](dk-a5e065bb32aea-test/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS Test Board.

Platform index: [dk-a5e065bb32aea-emmc](dk-a5e065bb32aea-emmc/README.md)

* [dk-a5e065bb32aea-emmc/baseline-a55](dk-a5e065bb32aea-emmc/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS NAND Board (This board also offers eMMC).

Platform index: [dk-a5e065bb32aea-nand](dk-a5e065bb32aea-nand/README.md)

* [dk-a5e065bb32aea-nand/baseline-a55](dk-a5e065bb32aea-nand/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS NAND Board.
  This design boots from NAND flash on the daughter card.

### Agilex 5 FPGA E-Series 065A Premium Development Kit DK-A5E065AB32AEA with speed grade 1 device

Platform index: [dk-a5e065ab32aea-enablement](dk-a5e065ab32aea-enablement/README.md)

Refer to the individual README for details of each design.

* [dk-a5e065ab32aea-enablement/baseline-a55](dk-a5e065ab32aea-enablement/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS Enablement Expansion Board.
  This design boots from Arm Cortex-A55 core 0 processor.

* [dk-a5e065ab32aea-enablement/baseline-a55-fpga-first](dk-a5e065ab32aea-enablement/baseline-a55-fpga-first/README.md) :
  FPGA First Baseline-A55 design for the A5ED065 Premium Devkit with HPS Enablement Expansion Board.
  FPGA fabric is configured before HPS release; this design boots from Arm Cortex-A55 core 0 processor.

* [dk-a5e065ab32aea-enablement/baseline-a76](dk-a5e065ab32aea-enablement/baseline-a76/README.md) :
  Baseline-A76 design for the A5ED065 Premium Devkit with HPS Enablement Expansion Board.
  This design boots from Arm Cortex-A76 core 2 processor.

* [dk-a5e065ab32aea-enablement/tsn-rgmii-hvio](dk-a5e065ab32aea-enablement/tsn-rgmii-hvio/README.md) :
  TSN RGMII HVIO design for the A5ED065 Premium Devkit with HPS Enablement Expansion Board.
  This design enables RGMII from FPGA HVIO for TSN.

Platform index: [dk-a5e065ab32aea-test](dk-a5e065ab32aea-test/README.md)

* [dk-a5e065ab32aea-test/baseline-a55](dk-a5e065ab32aea-test/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS Test Board.

Platform index: [dk-a5e065ab32aea-emmc](dk-a5e065ab32aea-emmc/README.md)

* [dk-a5e065ab32aea-emmc/baseline-a55](dk-a5e065ab32aea-emmc/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS NAND Board (This board also offers eMMC).

Platform index: [dk-a5e065ab32aea-nand](dk-a5e065ab32aea-nand/README.md)

* [dk-a5e065ab32aea-nand/baseline-a55](dk-a5e065ab32aea-nand/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Premium Devkit with HPS NAND Board.
  This design boots from NAND flash on the daughter card.

### Agilex 5 FPGA E-Series 065B Modular Development Kit MK-A5E065BB32AEA with speed grade 4 device.

Platform index: [mk-a5e065bb32aea](mk-a5e065bb32aea/README.md)

* [mk-a5e065bb32aea/baseline-a55](mk-a5e065bb32aea/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Modular Devkit.

### Agilex 5 FPGA E-Series 065A Modular Development Kit MK-A5E065AB32AEA with speed grade 1 device.

Platform index: [mk-a5e065ab32aea](mk-a5e065ab32aea/README.md)

* [mk-a5e065ab32aea/baseline-a55](mk-a5e065ab32aea/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED065 Modular Devkit.

* [mk-a5e065ab32aea/desktop-linux-dp](mk-a5e065ab32aea/desktop-linux-dp/README.md) :
  Desktop Linux with DisplayPort design for the A5ED065 Modular Devkit.
  This design boots from Arm Cortex-A55 core 0 processor.

### Agilex 5 FPGA D-Series 064B Premium Development Kit DK-A5D064AB32BEA

Platform index: [dk-a5d064ab32bea-enablement](dk-a5d064ab32bea-enablement/README.md)

* [dk-a5d064ab32bea-enablement/baseline-a55](dk-a5d064ab32bea-enablement/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED064 Premium Devkit with HPS Enablement Expansion Board.
  This design boots from Arm Cortex-A55 core 0 processor.
  This design is not fully validated yet for this release.

### Agilex 5 FPGA D-Series 064B Modular Development Kit MK-A5D064AB32BEA

Platform index: [mk-a5d064ab32bea](mk-a5d064ab32bea/README.md)

* [mk-a5d064ab32bea/baseline-a55](mk-a5d064ab32bea/baseline-a55/README.md) :
  Baseline-A55 design for the A5ED064 Modular Devkit.
  This design is not fully validated yet for this release.

### Terasic DE25 Nano Development and Education Board

Platform index: [terasic-de25-nano-devkit](terasic-de25-nano-devkit/README.md)

* [terasic-de25-nano-devkit/baseline-a55](terasic-de25-nano-devkit/baseline-a55/README.md) :
  Baseline-A55 design for the Terasic DE25 Nano Development and Education Board.
  This design boots from Arm Cortex-A55 core 0 processor.

### Terasic DE25-Standard Development and Education Kit

Platform index: [terasic-de25-standard-devkit](terasic-de25-standard-devkit/README.md)

* [terasic-de25-standard-devkit/baseline-a55](terasic-de25-standard-devkit/baseline-a55/README.md) :
  Baseline-A55 design for the Terasic DE25-Standard Development and Education Kit.
  This design boots from Arm Cortex-A55 core 0 processor.