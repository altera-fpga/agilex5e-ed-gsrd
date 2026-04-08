# Steps to Regenerate Post-Yocto Binaries

This README explains how to manually generate the binaries that appear in the install directories but are not directly produced by Yocto. These are generated from Yocto outputs using Quartus tools and scripts.

## Prerequisites

- Install mtd utilities
	```bash
	sudo apt update
	sudo apt install mtd-utils
	```
- Quartus Prime Pro tools must be installed and on PATH
- Complete Yocto build outputs available in `yocto_linux/build/tmp/deploy/images/<machine>/`

## Setup

1. Copy required SOF files into the Yocto deploy directory:
   ```bash
   # Replace <sof_name> with your design sof file name (e.g., baseline_a55)
   cp output_files/<sof_name>.sof yocto_linux/build/tmp/deploy/images/agilex5e/
   ```

2. Copy scripts into the Yocto deploy directory:
   ```bash
   cp yocto_linux/scripts/* yocto_linux/build/tmp/deploy/images/agilex5e/
   ```

3. Change to the Yocto deploy directory:
   ```bash
   cd yocto_linux/build/tmp/deploy/images/agilex5e/
   ```

---

## Generate RBF Files from SOF

The PFG files in this folder expect `ghrd.sof` as input, so rename your SOF file first:
```bash
# Use the appropriate SOF for your boot media
cp <sof_name>.sof ghrd.sof
```

### Option 1: Core RBF without bootloader (Quartus 26.1+)
Creates `ghrd.core.rbf` - FPGA fabric configuration only, no bootloader embedded:
```bash
quartus_pfg -c ghrd.sof ghrd.core.rbf -o hps=ON -o hps_core_only=ON
```

### Option 2: RBF with bootloader (legacy method)
Creates `ghrd.hps.rbf` (bootloader) and `ghrd.core.rbf` (fabric) from SOF and SPL:
```bash
quartus_pfg -c ghrd.sof ghrd.rbf -o hps=ON -o hps_path=u-boot-spl-dtb.hex
```
**Note:** This produces both `ghrd.hps.rbf` (HPS bootloader) and `ghrd.core.rbf` (core fabric).

**Usage notes:**
- To integrate `core.rbf` into kernel ITB, copy it to `meta-custom/recipes-fpga/fpga-bitstream/files/`
- Otherwise, use `core.rbf` to program FPGA from U-Boot (`fpga load`) or Linux (device tree overlay)

---

## Generate U-Boot Binary

Extract U-Boot binary from ITB format (required for JIC file generation):
```bash
./uboot_bin.sh
```
**Output:** `u-boot.bin` (extracted from `u-boot.itb`)

---

## SD/eMMC/NAND Boot Artifacts

### Generate U-Boot-Only JIC
If the daughter card (SDMMC, eMMC, NAND) is empty and you need to boot to U-Boot to access it, create a minimal JIC with U-Boot only and program it to QSPI flash:
```bash
cp <sof_name>.sof ghrd.sof
quartus_pfg -c qspi_helper.pfg
```
**Output:** `qspi_helper.hps.jic` - Contains U-Boot only (no Linux kernel/rootfs)
**Alternative method (explicit command):**
```bash
cp <sof_name>.sof ghrd.sof
quartus_pfg -c ghrd.sof ghrd.jic \
  -o device=MT25QU128 \
  -o flash_loader=A5ED065BB32AE4S \
  -o hps_path=u-boot-spl-dtb.hex \
  -o mode=ASX4 \
  -o hps=1
```


---

## NAND Boot Artifacts

### Generate UBI Image for NAND

Create the UBI image containing Linux kernel and root filesystem:

**For NAND:**
```bash
ubinize -o root.ubi -p 1024KiB -m 8192 -s 8192 ubinize_nand.cfg
```
**Output:** `root.ubi` - UBI image with kernel ITB and rootfs for NAND

---

## QSPI Boot Artifacts

### Generate UBI Image for QSPI (NOR flash)

Create the UBI image containing Linux kernel and root filesystem:

**For QSPI (NOR flash):**
```bash
ubinize -o hps.bin -p 65536 -m 1 -s 1 ubinize_nor.cfg
```
**Output:** `hps.bin` - UBI image with kernel ITB and rootfs for QSPI

### Generate QSPI JIC Images

Create full QSPI JIC with HPS first-boot configuration:
```bash
cp <sof_name>.sof ghrd.sof
quartus_pfg -c qspi_boot.pfg
```
**Output:** 
- `qspi_boot.hps.jic` - Full QSPI image (Quartus Format)
- `qspi_boot.rpd` - Full QSPI Raw programming data

---

## Summary of Generated Files

### Common Files (All Boot Media):
| File | Source | Description |
|------|--------|-------------|
| `ghrd.core.rbf` | quartus_pfg | FPGA fabric bitstream (core-only) |
| `ghrd.hps.rbf` | quartus_pfg (Option 2) | HPS bootloader region |
| `u-boot.bin` | uboot_bin.sh | U-Boot binary extracted from ITB |

### SD/eMMC/NAND Files:
| File | Source | Description |
|------|--------|-------------|
| `qspi_helper.hps.jic` | quartus_pfg + qspi_helper.pfg | U-Boot-only QSPI image for initial uboot bringup with empty daughter card |

## NAND Files:
| File | Source | Description |
|------|--------|-------------|
| `root.ubi` | ubinize | UBI image for NANDflash (kernel + rootfs) |

## QSPI Files:
| File | Source | Description |
|------|--------|-------------|
| `hps.bin` | ubinize | UBI image for flash (kernel + rootfs) |
| `qspi_boot.hps.jic` | quartus_pfg + qspi_boot.pfg| Full QSPI image (Quartus Format) |
| `qspi_boot.rpd` | quartus_pfg + qspi_boot.pfg| Full QSPI Raw programming data |

**Note:** All other files (Image, kernel.itb, u-boot.itb, DTB, rootfs archives, etc.) are produced directly by Yocto.
