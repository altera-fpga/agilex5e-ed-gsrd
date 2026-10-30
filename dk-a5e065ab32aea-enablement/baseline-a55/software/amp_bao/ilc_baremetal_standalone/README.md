# ILC Bare-Metal Standalone Demo

A pure bare-metal Interrupt Latency Counter (ILC) demo for the Altera
**Agilex 5** HPS. It measures hardware interrupt latency from ILC trigger to
ISR entry and prints min / max / average statistics over UART0.

This is the **baseline** for the companion Bao bare-metal guest under
[`bao-baremetal-guest/`](../bao-baremetal-guest/README.md). Running the same
ILC measurement bare-metal (this tree) and inside Bao lets you compare vGIC
emulation overhead.

The binary is an **extra** FAT file for `CONFIG=baremetal` — it is not
auto-booted by `boot.scr`. Load it manually from U-Boot when you want the
standalone measurement.

---

## Hardware / software requirements

| Requirement | Notes |
|-------------|-------|
| Board | Agilex 5 SoCFPGA development kit with ILC soft-IP in the fabric |
| FPGA bitstream | Core RBF that includes the ILC IP (program before `go`) |
| Toolchain | `aarch64-none-elf-gcc` (or the cross compiler passed as `CROSS=`) |
| Boot firmware | U-Boot + ATF capable of SD / TFTP load and `go` at EL2 |

---

## Build

### Recommended (parent orchestrator)

From `software/amp_bao/`:

```bash
make CONFIG=baremetal ilc
```

Produces `ilc_demo.bin` here and copies it to
`build/baremetal/out/ilc_demo.bin`. A full
`make CONFIG=baremetal FPGA_RBF=/path/to/core.rbf sdcard` also builds this
target and places `ilc_demo.bin` on the FAT partition.

### Local build

Ensure the bare-metal toolchain is on `PATH` (from the parent directory:
`make toolchains` then `eval "$(./scripts/toolchains.sh --print-env)"`), then:

```bash
# Prefer aarch64-none-elf- (matches amp_bao BM_CROSS):
make CROSS=aarch64-none-elf-

make clean              # remove .o / .elf / .bin / .map
make dis                # disassemble ilc_isr (early-hook check)
```

Output: `ilc_demo.elf` and `ilc_demo.bin` .

---

## Running from U-Boot

Load address / entry point is `0xa0000000` (see `agilex5_amp.ld`).

```
# Program fabric (ILC IP) — adjust path / transport as needed
fatload mmc 0:1 0x88000000 fpga.rbf
fpga load 0 0x88000000 ${filesize}

# Load standalone demo (SD example; TFTP/dhcp also fine)
fatload mmc 0:1 0xa0000000 ilc_demo.bin

bridge enable
wdt dev watchdog@10d00200
wdt stop
go 0xa0000000
```

Expected UART output (115200 8N1 on UART0), after ILC is firing:

```
### [BM] Agilex5 SoCFPGA
[BM] ILC init done
[BM] ILC n=5 | min=... max=... avg=... ns
[BM] ILC n=10 | min=... max=... avg=... ns
...
```

Per-sample lines are off by default (same cadence as the Bao guest path).
Define `ILC_PER_SAMPLE_LOG` at build time to print one line per interrupt.

ILC INTID is **50** (FPGA2HPS SPI 18).

---

## Code structure

```
vectors.S              — exception vectors + EL-detect startup
main.c                 — ILC init, interrupt enable, WFI loop
ilc_latency.c/.h       — IRQ early-hook, ring buffer, statistics
gic_handle.c           — ICC_IAR1/EOIR1 read/write
irq.c/.h               — handler table
uart.c/.h              — polled UART TX, minimal printf
drivers/gic/           — GICv3 / GIC-600 driver for Agilex 5
agilex5_amp.ld         — linker script (load: 0xa0000000, 4 MB DDR)
```

---

## License

MIT. See [LICENSE](LICENSE).
