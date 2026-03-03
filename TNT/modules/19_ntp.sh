#!/usr/bin/env bash

print_header "Time Sync & NTP"
print_explain "Accurate system time is required for log correlation, TLS certificate validation, and authentication protocols such as Kerberos. Clock skew can invalidate certificates, corrupt log timelines, or open windows for replay attacks. This section verifies a time synchronization service is active and the clock is accurate."

# --- Detect time sync daemon ---
ntp_daemon=""
ntp_active="inactive"

for svc in systemd-timesyncd chronyd ntpd openntpd; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        ntp_daemon="$svc"
        ntp_active="active"
        break
    elif systemctl list-unit-files --no-pager 2>/dev/null | grep -q "^${svc}"; then
        ntp_daemon="${svc} (installed, inactive)"
    fi
done
[[ -z "$ntp_daemon" ]] && ntp_daemon="None detected"

printf " ${C_BOLD}%-24s${C_RESET} %b\n" "NTP Daemon:" \
    "$(color_val "$ntp_daemon" "timesyncd|chronyd|ntpd|openntpd" "inactive")"
printf " ${C_BOLD}%-24s${C_RESET} %b\n" "Service Status:" \
    "$(color_val "$ntp_active" "active" "n/a")"

# --- timedatectl summary ---
if command -v timedatectl &>/dev/null; then
    td_out=$(timedatectl show 2>/dev/null)

    synced=$(echo "$td_out" | grep -oP "NTPSynchronized=\K\S+")
    rtc_time=$(echo "$td_out" | grep -oP "TimeUSec=\K[^\n]+")
    tz=$(echo "$td_out" | grep -oP "Timezone=\K\S+")

    printf " ${C_BOLD}%-24s${C_RESET} %b\n" "NTP Synchronized:" \
        "$( [[ "$synced" == "yes" ]] && color_val "Yes" "Yes" "n/a" || color_val "No" "Yes" "n/a" )"
    printf " ${C_BOLD}%-24s${C_RESET} %s\n" "Timezone:" "${tz:-unknown}"
fi

# --- System clock drift via chronyc or timedatectl ---
if command -v chronyc &>/dev/null && systemctl is-active --quiet chronyd 2>/dev/null; then
    tracking=$(chronyc tracking 2>/dev/null)
    ref=$(echo "$tracking" | grep -oP "Reference ID\s+:\s+\K\S+")
    offset=$(echo "$tracking" | grep -oP "System time\s+:\s+\K[^\n]+")
    stratum=$(echo "$tracking" | grep -oP "Stratum\s+:\s+\K\d+")

    printf " ${C_BOLD}%-24s${C_RESET} %s\n" "Reference Source:" "${ref:-unknown}"
    printf " ${C_BOLD}%-24s${C_RESET} %s\n" "Clock Offset:" "${offset:-unknown}"
    printf " ${C_BOLD}%-24s${C_RESET} %b\n" "Stratum:" \
        "$( [[ -n "$stratum" && "$stratum" -le 4 ]] \
            && color_val "$stratum" "^[1-4]$" "" \
            || color_val "${stratum:-unknown}" "" ".*" )"

elif systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
    ts_status=$(timedatectl timesync-status 2>/dev/null)
    server=$(echo "$ts_status" | grep -oP "Server:\s+\K\S+")
    offset=$(echo "$ts_status" | grep -oP "Offset:\s+\K[^\n]+")
    printf " ${C_BOLD}%-24s${C_RESET} %s\n" "Sync Server:" "${server:-unknown}"
    printf " ${C_BOLD}%-24s${C_RESET} %s\n" "Clock Offset:" "${offset:-unknown}"
fi

# --- RTC check ---
if command -v hwclock &>/dev/null; then
    hwclock_out=$(hwclock --show 2>/dev/null | head -1)
    printf " ${C_BOLD}%-24s${C_RESET} %s\n" "RTC (Hardware Clock):" "${hwclock_out:-not accessible}"
fi