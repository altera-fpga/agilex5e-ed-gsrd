# Linux ↔ FreeRTOS OpenAMP / RPMsg (`CONFIG=linux_freertos`)

How the two guests exchange messages after you boot the
`linux_freertos` SD image.

## Roles

| Side | Component | Role |
|------|-----------|------|
| Hypervisor | Bao | Maps 64 KiB IPC shmem into both VMs at IPA `0xC4000000`; delivers kicks as irqid **52** |
| FreeRTOS | `freertos/apps/rpmsg_console/` | Publishes OpenAMP resource table at shmem offset 0; OpenAMP remote + ILC / heartbeat traffic |
| Linux | `bao-rproc` + `virtio_rpmsg` | Attach-mode remoteproc; userspace channel `/dev/rpmsg0` |

Bao owns peer lifecycle (load / start). Linux never loads FreeRTOS firmware;
it only attaches to the already-running guest over shmem + Bao IPC.

## Bring-up on the board

After Linux reaches a login shell:

```bash
# 1. Attach remoteproc (bao-rproc probes as detached; auto_boot is false)
echo start > /sys/class/remoteproc/remoteproc0/state
cat /sys/class/remoteproc/remoteproc0/state   # expect: attached

# 2. RPMsg char device appears after FreeRTOS NS_ANNOUNCE
ls -l /dev/rpmsg0

# 3. Read heartbeats / ILC lines (blocks)
cat /dev/rpmsg0

# 4. Optional: write a ping (FreeRTOS echoes / counts RX)
echo "Test Ping" > /dev/rpmsg0
```

A Buildroot overlay helper is also available:
`/usr/bin/rpmsg-bidir-check.sh`.

If `echo start` fails, FreeRTOS has likely not published a valid resource
table yet — wait a moment after boot and retry, or check `dmesg | grep -i bao`.

## Shmem layout (IPA `0xC4000000`, 64 KiB)

Offsets must match FreeRTOS `resource_table.h` and the carveouts in
`bao_rproc.c`:

| Offset | Size | Contents |
|--------|------|----------|
| `0x0000` | 1 KiB (framework window) | OpenAMP resource table |
| `0x1000` | 8 KiB | `vdev0vring0` (Linux → FreeRTOS) |
| `0x3000` | 8 KiB | `vdev0vring1` (FreeRTOS → Linux) |
| `0x5000` | 16 KiB | `vdev0buffer` (32 × 512 B; Linux splits rbufs / sbufs) |
| `0x9000` | rest | Reserved |

Device tree node (see `configs/linux_freertos/linux.dts`):

```dts
bao_rproc: bao-rproc@c4000000 {
    compatible  = "bao,rproc";
    reg         = <0x0 0xc4000000 0x0 0x10000>;
    interrupts  = <0x0 0x14 0x1>;   /* SPI 20 → irqid 52, edge-rising */
    bao,ipc-id  = <0x0>;
};
```

## Notification path

```
Linux virtqueue_kick
  → HVC FID 0x86000001 (x1 = ipc_id, x2 = vqid)
  → Bao injects irqid 52 on FreeRTOS vCPU
  → FreeRTOS OpenAMP advances rings

FreeRTOS kick (same HVC the other way)
  → Bao raises SPI 20 on a Linux vCPU
  → bao-rproc threaded ISR → rproc_vq_interrupt() on both vrings
```

## Where to look in the tree

| Topic | Path |
|-------|------|
| Linux driver (patch) | `linux/patches/6.18/0001-add-bao-rproc-driver.patch` |
| Guest DTS node | `configs/linux_freertos/linux.dts` (`bao-rproc@c4000000`) |
| Bao IPC / shmem | `configs/linux_freertos/config.c` |
| FreeRTOS resource table | `freertos/apps/rpmsg_console/resource_table.h` |
| FreeRTOS OpenAMP app | `freertos/apps/rpmsg_console/main_rpmsg_console.c` |
