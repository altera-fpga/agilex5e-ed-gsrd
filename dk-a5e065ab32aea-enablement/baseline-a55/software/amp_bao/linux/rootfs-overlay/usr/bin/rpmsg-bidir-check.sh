#!/bin/sh
# rpmsg-bidir-check.sh -- bidirectional rpmsg smoke test.
#
# Sends N pings into /dev/rpmsg0 (the rpmsg-raw cdev exposed by Linux
# bao-rproc + virtio_rpmsg_bus + rpmsg_chrdev), then captures the next
# couple of FreeRTOS heartbeat lines and asserts that the heartbeat's
# 'rx=' counter advanced by N. Heartbeat format (from
# main_rpmsg_console.c, prvProducerTask):
#
#   [FRT] hb uptime=Xs tx=N txfail=K rx=M last="..."
#
# Exit 0 = pass (rx delta == N), 1 = fail (delta wrong, no heartbeat
# in window, or /dev/rpmsg0 missing). The reader runs `cat /dev/rpmsg0`
# in the background under a `timeout`, so this script always returns
# in bounded time even if the FreeRTOS guest has stopped emitting
# heartbeats.
#
# Usage: rpmsg-bidir-check.sh [N]   (default 3)

set -u

N="${1:-3}"
DEV=/dev/rpmsg0
WINDOW_S=35           # > 3 * 10 s heartbeat period; gives 2-3 hb samples
LOGF=/tmp/rpmsg-bidir-check.log

if [ ! -c "$DEV" ]; then
    echo "FAIL: $DEV not present (is bao-rproc attached?)" >&2
    exit 1
fi

# Drain anything already pending in the rpmsg ring -- otherwise an old
# heartbeat captured before we sent any pings would skew the rx-delta.
( timeout 1 cat "$DEV" >/dev/null 2>&1 ) || true

# Reader: capture up to WINDOW_S of heartbeat traffic.
( timeout "$WINDOW_S" cat "$DEV" > "$LOGF" 2>&1 ) &
READER_PID=$!

# Give the reader's open(2) time to bind a fresh endpoint and let one
# heartbeat land that we can use as the BEFORE sample.
sleep 12

# Sample BEFORE rx counter (last heartbeat seen so far).
RX_BEFORE=$(awk '/^\[FRT\] hb / {
    for (i=1;i<=NF;i++) if (substr($i,1,3)=="rx=") { sub("rx=","",$i); v=$i }
} END { if (v=="") { print "MISSING" } else { print v } }' "$LOGF")

if [ "$RX_BEFORE" = "MISSING" ]; then
    kill "$READER_PID" 2>/dev/null
    wait "$READER_PID" 2>/dev/null
    echo "FAIL: no heartbeat captured in first 12 s -- FreeRTOS hung?" >&2
    cat "$LOGF" >&2
    exit 1
fi

i=0
while [ "$i" -lt "$N" ]; do
    i=$((i + 1))
    echo "ping_$i" > "$DEV"
done

# Wait for the reader to finish its WINDOW_S timeout so we get the
# AFTER heartbeat(s).
wait "$READER_PID" 2>/dev/null

RX_AFTER=$(awk '/^\[FRT\] hb / {
    for (i=1;i<=NF;i++) if (substr($i,1,3)=="rx=") { sub("rx=","",$i); v=$i }
} END { if (v=="") { print "MISSING" } else { print v } }' "$LOGF")

if [ "$RX_AFTER" = "MISSING" ]; then
    echo "FAIL: no heartbeat captured after pings" >&2
    cat "$LOGF" >&2
    exit 1
fi

DELTA=$(( RX_AFTER - RX_BEFORE ))
echo "rx_before=$RX_BEFORE rx_after=$RX_AFTER delta=$DELTA expected=$N"
echo "--- heartbeat log ($LOGF) ---"
grep -E '^\[FRT\] hb ' "$LOGF" || true
echo "--- end ---"

if [ "$DELTA" -eq "$N" ]; then
    echo "PASS"
    exit 0
fi

echo "FAIL: rx delta $DELTA != expected $N" >&2
exit 1
