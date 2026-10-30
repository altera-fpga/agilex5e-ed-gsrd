#!/usr/bin/env bash
# Shared shell helpers for hps-amp scripts.
# Source from any script via:  . "$(dirname "$0")/lib.sh"

# Colour helpers (silenced if not a TTY)
if [[ -t 1 ]]; then
    _bold=$'\033[1m'; _cyan=$'\033[1;36m'; _green=$'\033[1;32m'
    _yellow=$'\033[1;33m'; _red=$'\033[1;31m'; _off=$'\033[0m'
else
    _bold=''; _cyan=''; _green=''; _yellow=''; _red=''; _off=''
fi

step()  { printf "\n%s== %s ==%s\n" "$_cyan"   "$*" "$_off"; }
ok()    { printf "%s[ok]%s %s\n"    "$_green"  "$_off" "$*"; }
warn()  { printf "%s[warn]%s %s\n"  "$_yellow" "$_off" "$*" >&2; }
die()   { printf "%s[err]%s %s\n"   "$_red"    "$_off" "$*" >&2; exit 1; }

VERBOSE="${VERBOSE:-0}"

# run <cmd...> — execute, suppress output unless VERBOSE=1; on failure tail log.
run() {
    if [[ "$VERBOSE" == "1" ]]; then
        "$@"
    else
        local log; log="$(mktemp)"
        if ! "$@" >"$log" 2>&1; then
            tail -80 "$log" >&2
            rm -f "$log"
            die "command failed: $*"
        fi
        rm -f "$log"
    fi
}

bytes_human() {
    local b=$1
    if   [[ $b -ge 1048576 ]]; then awk "BEGIN{printf \"%.1f MB\", $b/1048576}"
    elif [[ $b -ge    1024 ]]; then awk "BEGIN{printf \"%.1f KB\", $b/1024}"
    else echo "${b} B"; fi
}
