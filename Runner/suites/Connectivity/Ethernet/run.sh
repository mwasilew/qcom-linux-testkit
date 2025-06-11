#!/bin/sh
 
#Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
#SPDX-License-Identifier: BSD-3-Clause-Clear
 
# Robustly find and source init_env
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT_ENV=""
SEARCH="$SCRIPT_DIR"
while [ "$SEARCH" != "/" ]; do
    if [ -f "$SEARCH/init_env" ]; then
        INIT_ENV="$SEARCH/init_env"
        break
    fi
    SEARCH=$(dirname "$SEARCH")
done

if [ -z "$INIT_ENV" ]; then
    echo "[ERROR] Could not find init_env (starting at $SCRIPT_DIR)" >&2
    exit 1
fi

if [ -z "$__INIT_ENV_LOADED" ]; then
    # shellcheck disable=SC1090
    . "$INIT_ENV"
fi
# shellcheck disable=SC1090,SC1091
. "$TOOLS/functestlib.sh"

TESTNAME="Ethernet"
test_path=$(find_test_case_by_name "$TESTNAME")
cd "$test_path" || exit 1
res_file="./$TESTNAME.res"
summary_file="./$TESTNAME.summary"
rm -f "$res_file" "$summary_file"
 
log_info "--------------------------------------------------------------------------"
log_info "-------------------Starting $TESTNAME Testcase----------------------------"

# Check for dependencies
check_dependencies ip ping

# User-specified interface (argument) or all detected
# Accept user-preferred interface as argument
user_iface="$1"
if [ -n "$user_iface" ]; then
    IFACES="$user_iface"
    log_info "User specified interface: $user_iface"
else
    IFACES=$(get_ethernet_interfaces)
    log_info "Auto-detected Ethernet interfaces: $IFACES"
fi

iface_passed=0
iface_failed=0
iface_skipped=0

for iface in $IFACES; do
    log_info "---- Testing interface: $iface ----"

    # Check if interface is up
    if ! is_interface_up "$iface"; then
        log_warn "$iface is DOWN, skipping"
        echo "$iface: SKIP (down/no cable)" >> "$summary_file"
        iface_skipped=$((iface_skipped+1))
        continue
    fi

    ip_addr="$(get_ip_address "$iface")"

    if [ -z "$ip_addr" ]; then
        log_info "$iface has no IP, attempting DHCP"
        run_dhcp_client "$iface" 10
        sleep 2
        ip_addr="$(get_ip_address "$iface")"
    fi

    if [ -z "$ip_addr" ]; then
        log_warn "$iface has no IP assigned, skipping"
        echo "$iface: SKIP (no IP assigned)" >> "$summary_file"
        iface_skipped=$((iface_skipped+1))
        continue
    elif echo "$ip_addr" | grep -q '^169\.254'; then
        log_warn "$iface got only link-local IP ($ip_addr), skipping"
        echo "$iface: SKIP (link-local IP: $ip_addr)" >> "$summary_file"
        iface_skipped=$((iface_skipped+1))
        continue
    else
        log_info "$iface got IP: $ip_addr"
    fi

    # Ping test
    if ping -I "$iface" -c 4 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_pass "$iface connectivity verified via ping"
        echo "$iface: PASS" >> "$summary_file"
        iface_passed=$((iface_passed+1))
    else
        log_fail "Ping test failed for $iface"
        echo "$iface: FAIL (ping failed)" >> "$summary_file"
        iface_failed=$((iface_failed+1))
    fi
done

log_info "---- Ethernet Interface Test Summary ----"
cat "$summary_file"

if [ "$iface_passed" -gt 0 ]; then
    echo "$TESTNAME PASS" > "$res_file"
    exit 0
elif [ "$iface_failed" -gt 0 ]; then
    echo "$TESTNAME FAIL" > "$res_file"
    exit 1
else
    echo "$TESTNAME SKIP" > "$res_file"
    exit 2
fi
