#!/bin/sh
 
#Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
#SPDX-License-Identifier: BSD-3-Clause-Clear
 
# Source init_env and functestlib.sh
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
 
# shellcheck disable=SC1090
. "$INIT_ENV"
# shellcheck disable=SC1090,SC1091
. "$TOOLS/functestlib.sh"
 
TESTNAME="Ethernet"
test_path=$(find_test_case_by_name "$TESTNAME") || {
    log_fail "$TESTNAME : Test directory not found."
    echo "FAIL $TESTNAME" > "./$TESTNAME.res"
    exit 1
}
 
cd "$test_path" || exit 1
res_file="./$TESTNAME.res"
rm -f "$res_file"
 
log_info "--------------------------------------------------------------------------"
log_info "-------------------Starting $TESTNAME Testcase----------------------------"

# Check for dependencies
check_dependencies ip ping

# Detect Ethernet interface dynamically using helper
IFACE=$(get_ethernet_interface)
if [ -z "$IFACE" ]; then
    log_fail "No Ethernet interface found!"
    echo "$TESTNAME SKIP" > "$res_file"
    exit 0
fi
log_info "Detected Ethernet interface: $IFACE"

RETRIES=3
SLEEP_SEC=3

# Bring up the interface with retries (always brings down first)
log_info "Ensuring $IFACE is UP..."
if ! bringup_interface "$IFACE" "$RETRIES" "$SLEEP_SEC"; then
    log_fail "Failed to bring up $IFACE after $RETRIES attempts"
    echo "$TESTNAME FAIL" > "$res_file"
    exit 1
fi
log_pass "$IFACE is UP"

# Log the current IP address (if any)
IPADDR=$(get_ip_address "$IFACE")
if [ -n "$IPADDR" ]; then
    log_info "IP Address for $IFACE: $IPADDR"
else
    log_warn "Could not retrieve IP address for $IFACE"
fi

# Ping test with retries
log_info "Running ping test to 8.8.8.8 via $IFACE..."
i=0
while [ $i -lt $RETRIES ]; do
    if ping -I "$IFACE" -c 4 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_pass "Ethernet connectivity verified via ping"
        echo "$TESTNAME PASS" > "$res_file"
        exit 0
    fi
    log_warn "Ping failed (attempt $((i + 1))/$RETRIES)... retrying"
    sleep "$SLEEP_SEC"
    i=$((i + 1))
done

log_fail "Ping test failed after $RETRIES attempts"
echo "$TESTNAME FAIL" > "$res_file"
exit 1
