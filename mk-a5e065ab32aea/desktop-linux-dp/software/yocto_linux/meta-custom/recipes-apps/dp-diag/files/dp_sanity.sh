#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# dp_sanity.sh - DisplayPort bring-up sanity check for the Agilex 5
#                desktop-linux-dp design (altera-vvp-dp KMS driver).
#
# Purpose
# -------
# One command that tells you whether the whole DP path is healthy, without
# needing to look at the monitor. Intended for:
#   * customers / lab: "did it come up correctly?" after boot + root login
#   * weekly regression: run headless, check the exit code (0 = PASS)
#
# What it catches (the real failures seen in the field)
# -----------------------------------------------------
#   1. Old .sof vs new software  -> base-address mismatch (wrong bitstream).
#      Detected by the fabric "bad address" sentinel (0x0BAD10AD) and the VFR
#      identity register.
#   2. DP IP upgrade (b50->b55)  -> wrong video-timing programming.
#      Detected by the AXIS-throttle + MSA registers and the ~60 Hz frame rate.
#   3. Generic bring-up gaps     -> connector/HPD, link training, video-enable,
#      compositor.
#
# Exit code: 0 if all *applicable* checks pass, 1 otherwise. Checks that need a
# monitor are skipped (not failed) when no sink is connected, so you still get a
# useful driver/fabric verdict in a monitor-less lab.
#
# Usage:  ./dp_sanity.sh            (normal)
#         DP_VERBOSE=1 ./dp_sanity.sh   (print every register value)
#
# Automation / weekly regression:
#   * exit code (preferred):  0 = PASS, 1 = FAIL
#   * keyword grep (colour-free token on the last line):
#         ./dp_sanity.sh | grep -q 'DP_SANITY_RESULT=PASS' && echo PASS || echo FAIL

# ---------------------------------------------------------------------------
# Expected timing (this design ships a single fixed mode: 1920x1080 @ 60 Hz).
# If you respin for a different mode, update these expectations.
# ---------------------------------------------------------------------------
EXP_HACTIVE=1920
EXP_VACTIVE=1080
EXP_HTOTAL=2200
EXP_VTOTAL=1125
EXP_FPS=60
PIP=4                       # TX_PIXELS_PER_CLOCK (AXI stream pixels per beat)
FPS_MIN=55                  # accepted VFR frame-IRQ rate window
FPS_MAX=65

# ---- Register map (physical byte addresses) -------------------------------
VFR_BASE=0x20020000
VFR_VIDPID=0x20020000       # expect 0x6AF7024A
VFR_STATUS=0x20020140       # bit0 = outputting
DPTX_BASE=0x20030000
TX_CONTROL=0x20030000       # bit2 = video idle pattern
TX_STATUS=0x20030004        # bit2 = HPD
CLK_PIO=0x20035000          # divide value; 0x0BAD10AD = wrong/old bitstream
# AXIS ingest throttle (altera_dp_axi_2_im)
A2I_HACTIVE=0x20030C00
A2I_HTOTAL=0x20030C04
A2I_VACTIVE=0x20030C08
A2I_VTOTAL=0x20030C0C
A2I_SYSCLOCKS=0x20030C10
# DP TX Main Stream Attributes (MSA)
MSA_HTOTAL=0x20030088
MSA_VTOTAL=0x2003008C
MSA_HWIDTH=0x200300A8
MSA_VHEIGHT=0x200300AC
MSA_MISC0=0x200300B0

VFR_VIDPID_EXPECT=0x6AF7024A
BAD_ADDR=0x0BAD10AD

pass_count=0
fail_count=0
skip_count=0

# Colour only on an interactive terminal; keep logs/regression output plain so
# result keywords stay greppable.
if [ -t 1 ]; then
    green() { printf '\033[32m%s\033[0m' "$1"; }
    red()   { printf '\033[31m%s\033[0m' "$1"; }
    yellow(){ printf '\033[33m%s\033[0m' "$1"; }
else
    green() { printf '%s' "$1"; }
    red()   { printf '%s' "$1"; }
    yellow(){ printf '%s' "$1"; }
fi

# rd <addr> : read a 32-bit register, echo its value as 0xXXXXXXXX (or "ERR").
rd() {
    v=$(devmem2 "$1" w 2>/dev/null | sed -n 's/.*: \(0x[0-9A-Fa-f]*\).*/\1/p' | tail -1)
    [ -n "$v" ] && echo "$v" || echo "ERR"
}

# hex2dec <0xNN>
hex2dec() { printf '%d' "$1" 2>/dev/null || echo 0; }

PASS() { pass_count=$((pass_count+1)); printf '  [%s] %s\n' "$(green PASS)" "$1"; }
FAIL() { fail_count=$((fail_count+1)); printf '  [%s] %s\n' "$(red FAIL)" "$1"; }
SKIP() { skip_count=$((skip_count+1)); printf '  [%s] %s\n' "$(yellow SKIP)" "$1"; }
INFO() { printf '       %s\n' "$1"; }

# check_eq <label> <addr> <expected-decimal>
check_eq() {
    raw=$(rd "$2")
    [ "$DP_VERBOSE" = 1 ] && INFO "$2 = $raw"
    if [ "$raw" = "ERR" ]; then FAIL "$1: register read failed ($2)"; return; fi
    act=$(hex2dec "$raw")
    if [ "$act" = "$3" ]; then PASS "$1 = $act"; else FAIL "$1 = $act (expected $3)"; fi
}

echo "=================================================================="
echo " DisplayPort sanity check  (altera-vvp-dp / desktop-linux-dp)"
echo " expecting ${EXP_HACTIVE}x${EXP_VACTIVE} @ ${EXP_FPS}Hz"
echo "=================================================================="

# ---------------------------------------------------------------------------
# A) Platform / driver / bitstream  (works even with NO monitor attached)
# ---------------------------------------------------------------------------
echo
echo "A) Platform / driver / bitstream"

if ! command -v devmem2 >/dev/null 2>&1; then
    echo "  devmem2 not found - cannot probe registers. Install it and re-run."
    exit 1
fi

if [ -e /dev/dri/card0 ]; then
    PASS "KMS device present (/dev/dri/card0)"
else
    FAIL "no /dev/dri/card0 - altera-vvp-dp did not bind (check dmesg)"
fi

# Driver finished probing (complements the /dev/dri/card0 node check).
if dmesg 2>/dev/null | grep -q 'Initialized altera-vvp-dp'; then
    PASS "driver probe completed (dmesg)"
else
    FAIL "no 'Initialized altera-vvp-dp' in dmesg - probe did not finish"
fi

# Negative check: no driver errors or kernel faults this boot. This is the
# regression tripwire - it catches crashes / timeouts a register dump can't,
# e.g. a future IP change that makes the driver fault or the video stall.
faults=$(dmesg 2>/dev/null | grep -iE \
    'altera-vvp-dp.*(fail|error|timed out)|vblank wait timed out|Asynchronous SError|Kernel panic' \
    | head -5)
if [ -z "$faults" ]; then
    PASS "no driver errors / kernel faults in dmesg"
else
    FAIL "kernel log shows errors:"
    echo "$faults" | while IFS= read -r l; do INFO "$l"; done
fi

# Bitstream vs software match: the new clk-PIO address must decode. A read of
# 0x0BAD10AD means the fabric returned "bad address" => wrong/old .sof loaded.
clk=$(rd $CLK_PIO)
[ "$DP_VERBOSE" = 1 ] && INFO "$CLK_PIO = $clk"
if [ "$clk" = "$BAD_ADDR" ]; then
    FAIL "fabric bad-address sentinel at clk-PIO ($BAD_ADDR) - OLD/mismatched .sof"
    INFO "The running bitstream does not match this software (base-addr change)."
elif [ "$clk" = "ERR" ]; then
    FAIL "clk-PIO read failed"
else
    PASS "clk-PIO decodes ($clk) - bitstream base addresses match software"
fi

# VFR identity
vid=$(rd $VFR_VIDPID)
if [ "$vid" = "$VFR_VIDPID_EXPECT" ]; then
    PASS "VFR identity ok ($vid)"
else
    FAIL "VFR identity = $vid (expected $VFR_VIDPID_EXPECT)"
fi

# VFR outputting?
st=$(rd $VFR_STATUS)
if [ "$st" != "ERR" ] && [ $(( $(hex2dec "$st") & 1 )) -eq 1 ]; then
    PASS "VFR is streaming (STATUS=$st, outputting=1)"
else
    FAIL "VFR not streaming (STATUS=$st) - no pixels leaving DDR"
fi

# VFR frame-read interrupt rate (the tell-tale for wrong SYSCLOCKS / timing).
irqline=$(grep -m1 'altera-vvp-dp' /proc/interrupts 2>/dev/null)
if [ -n "$irqline" ]; then
    a=$(echo "$irqline" | awk '{print $2}')
    sleep 1
    b=$(grep -m1 'altera-vvp-dp' /proc/interrupts | awk '{print $2}')
    rate=$((b - a))
    if [ "$rate" -ge "$FPS_MIN" ] && [ "$rate" -le "$FPS_MAX" ]; then
        PASS "VFR frame rate ${rate} Hz (~${EXP_FPS})"
    else
        FAIL "VFR frame rate ${rate} Hz (expected ${FPS_MIN}-${FPS_MAX})"
        INFO "Wrong rate usually means bad SYSCLOCKS / video-timing programming."
    fi
else
    SKIP "VFR frame IRQ not found in /proc/interrupts"
fi

# ---------------------------------------------------------------------------
# B) DP connector / link  (needs a monitor connected)
# ---------------------------------------------------------------------------
echo
echo "B) DP connector / link"

conn=$(cat /sys/class/drm/card*-DP-1/status 2>/dev/null | head -1)
MONITOR=0
if [ "$conn" = "connected" ]; then
    PASS "connector DP-1 connected"
    MONITOR=1
elif [ "$conn" = "disconnected" ]; then
    SKIP "connector DP-1 disconnected - plug in a monitor for the video checks"
else
    SKIP "connector DP-1 status unknown ($conn)"
fi

# HPD bit in TX_STATUS
txs=$(rd $TX_STATUS)
if [ "$txs" != "ERR" ] && [ $(( $(hex2dec "$txs") & 0x4 )) -ne 0 ]; then
    PASS "HPD asserted (TX_STATUS=$txs)"
elif [ "$MONITOR" = 1 ]; then
    FAIL "HPD not asserted (TX_STATUS=$txs) but connector says connected"
else
    SKIP "HPD not asserted (no monitor)"
fi

if dmesg 2>/dev/null | grep -q 'link trained OK'; then
    PASS "DP link training succeeded (dmesg)"
elif [ "$MONITOR" = 1 ]; then
    FAIL "no 'link trained OK' in dmesg"
else
    SKIP "link training not attempted (no monitor)"
fi

# ---------------------------------------------------------------------------
# C) Video timing programming  (only meaningful once video is up)
# ---------------------------------------------------------------------------
echo
echo "C) Video-timing registers"

if [ "$MONITOR" = 1 ]; then
    # AXIS ingest throttle (altera_dp_axi_2_im): H counts are per-PIP beats.
    check_eq "AXIS HACTIVE (beats)"   $A2I_HACTIVE   $((EXP_HACTIVE / PIP))
    check_eq "AXIS HTOTAL  (beats)"   $A2I_HTOTAL    $((EXP_HTOTAL  / PIP))
    check_eq "AXIS VACTIVE"           $A2I_VACTIVE   $EXP_VACTIVE
    check_eq "AXIS VTOTAL"            $A2I_VTOTAL    $EXP_VTOTAL
    # SYSCLOCKS is in tx_axi4s_clk (full pixel clock) cycles per line = HTOTAL.
    check_eq "AXIS SYSCLOCKS"         $A2I_SYSCLOCKS $EXP_HTOTAL

    # DP TX MSA (the AXIS/im path does NOT auto-measure these).
    check_eq "MSA HTOTAL"             $MSA_HTOTAL    $EXP_HTOTAL
    check_eq "MSA VTOTAL"             $MSA_VTOTAL    $EXP_VTOTAL
    check_eq "MSA HWIDTH"             $MSA_HWIDTH    $EXP_HACTIVE
    check_eq "MSA VHEIGHT"            $MSA_VHEIGHT   $EXP_VACTIVE

    # MISC0 is auto-generated by the DP TX (reads 0 in a working link), so it is
    # reported for reference only and does NOT affect the pass/fail result.
    misc=$(rd $MSA_MISC0)
    INFO "MSA MISC0 = $misc (hardware-managed; informational)"

    # Video enabled (TX_CONTROL bit2 = idle pattern; must be 0 for real video).
    ctrl=$(rd $TX_CONTROL)
    if [ "$ctrl" != "ERR" ] && [ $(( $(hex2dec "$ctrl") & 0x4 )) -eq 0 ]; then
        PASS "video output enabled (TX_CONTROL=$ctrl, idle bit clear)"
    else
        FAIL "video idle pattern active (TX_CONTROL=$ctrl) - monitor will be black"
    fi
else
    SKIP "video-timing checks (no monitor connected)"
fi

# ---------------------------------------------------------------------------
# D) Compositor
# ---------------------------------------------------------------------------
echo
echo "D) Compositor"
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet weston-drm.service 2>/dev/null; then
        PASS "weston-drm.service active"
    else
        SKIP "weston-drm.service not active (starts on root login)"
    fi
else
    SKIP "systemctl not available"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=================================================================="
printf ' RESULT: %s pass, %s fail, %s skipped\n' \
    "$(green $pass_count)" "$(red $fail_count)" "$(yellow $skip_count)"
if [ "$fail_count" -eq 0 ]; then
    echo " OVERALL: $(green PASS)"
    echo "=================================================================="
    # Machine-readable keyword for automation (stable, no colour). Grep this.
    echo "DP_SANITY_RESULT=PASS"
    exit 0
else
    echo " OVERALL: $(red FAIL)  - see [FAIL] lines above"
    echo "=================================================================="
    echo "DP_SANITY_RESULT=FAIL"
    exit 1
fi
