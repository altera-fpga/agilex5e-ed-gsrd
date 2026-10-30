# Linux entry-stub loader (lloader)

A tiny first-stage that runs **inside** the Linux guest's address space and
sets up the AArch64 Linux boot protocol before branching to the kernel
`Image`. Required because Bao does not perform boot-protocol register setup
when it enters a guest — it just branches to the configured entry address.

## What it does

1. Mask exceptions (`msr daifset, 0xf`).
2. Disable the MMU (clear `SCTLR_EL1.M`).
3. Set `x0 = phys(__dtb_start)`, `x1 = x2 = x3 = 0`  (the AArch64 protocol).
4. Branch to `__linux_start` (= `Image` at section offset `0x80000`).

## Layout

The linker script `loader_<ARCH>.ld` produces a single blob:

```
offset 0x00000   .nloader   stub (_start)
offset 0x00???   .dtb       8-byte aligned, populated via .incbin DTB
offset 0x80000   .linux     populated via .incbin IMAGE
```

Bao boots the Linux guest by jumping to `LINUX_LOAD_ADDR` (which equals
`_start`), so the stub runs first, then the kernel.

## Loader source files

This directory already includes the two files needed to build:

| File                  | Purpose                                     |
|-----------------------|---------------------------------------------|
| `aarch64.S`           | The entry stub (assembly).                  |
| `loader_aarch64.ld`   | Linker script defining the section layout. |

You can replace these with your own equivalents if needed.

## Build interface

This directory has its own Makefile; the solution-level `software/amp_bao/Makefile`
invokes it from the `linux-loader` target:

```
make -C linux/lloader \
     ARCH=aarch64 \
     CROSS_COMPILE=aarch64-none-elf- \
     IMAGE=<path to kernel Image> \
     DTB=<path to guest .dtb> \
     TARGET=<path-without-ext>
```

Emits `<TARGET>.elf` and `<TARGET>.bin`. The `.bin` is what the solution
packages as the Linux guest payload started by Bao at `LINUX_LOAD_ADDR`.

## IPA window constraint

Because the kernel lives at stub-relative offset `0x80000`, the Linux
guest's memory region in `bao/config.c` must:

- Start at `LINUX_LOAD_ADDR` (where the stub's `_start` is loaded), and
- Span at least `0x80000 + sizeof(Image) + initramfs/bss headroom`.
