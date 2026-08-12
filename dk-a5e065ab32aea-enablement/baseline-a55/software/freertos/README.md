# Overview of FreeRTOS

The FreeRTOS framework enables user to create real-time operating systems (RTOS)
with deterministic behaviours and bounded response time. The Altera FreeRTOS framework
provides software drivers for Agilex 5 HPS peripherals and a straightforward build
process for deploying real-time operating system on the Agilex 5 SoC FPGA.

Each FreeRTOS example design is contained inside a XXX-app folder, and all FreeRTOS
example design uses QSPI boot. Following is the top level view of the FreeRTOS framework.

```
.
├── XXX-app
├── qspi_flash_image_agilex5_boot.pfg
└── README.md

```

## Pre-Requisite
- **QUARTUS ToolKit**
Ensure you have Altera Quartus Prime 26.1.1 correctly configured in your environment

- **Hardware Design**
Ensure that the SOF file for your hardware design is successfully generated (eg. baseline-a55/output_files/baseline_a55.sof)

# Projects
- **Hello World**
Follow instructions in ```hello-world-app/README.md``` to build the FreeRTOS Hello World example design