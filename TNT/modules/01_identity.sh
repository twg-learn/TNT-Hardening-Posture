#!/usr/bin/env bash

source /etc/os-release 2>/dev/null

print_header "System Identity"
print_explain "Establishes baseline system identity including hostname, OS version, kernel, uptime, and timezone. This confirms the system is running expected software versions and helps identify stale uptimes that may indicate pending security patches requiring a reboot to apply."

# --- Uptime & load ---
uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //')
load_avg=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
last_boot=$(who -b 2>/dev/null | awk '{print $3, $4}')
timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)
cpu_arch=$(uname -m)

printf " ${C_BOLD}%-16s${C_RESET} %s\n" "Hostname:"      "$(hostname -f 2>/dev/null || hostname)"
printf " ${C_BOLD}%-16s${C_RESET} %s\n" "Operating Sys:" "${PRETTY_NAME:-Linux} (Kernel: $(uname -r))"
printf " ${C_BOLD}%-16s${C_RESET} %s\n" "Architecture:"  "$cpu_arch"
printf " ${C_BOLD}%-16s${C_RESET} %s\n" "Last Boot:"     "${last_boot:-unknown}"
printf " ${C_BOLD}%-16s${C_RESET} %s\n" "Uptime:"        "${uptime_str:-unknown}"
printf " ${C_BOLD}%-16s${C_RESET} %s\n" "Load Average:"  "$load_avg (1m 5m 15m)"
printf " ${C_BOLD}%-16s${C_RESET} %s\n" "Timezone:"      "$timezone"