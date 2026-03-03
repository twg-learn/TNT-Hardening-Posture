#!/usr/bin/env bash

print_header "Authentication Events"
print_explain "Recent authentication logs reveal active attacks and unauthorized access. This section surfaces failed login patterns, unexpected successful logins, and privilege escalation events — indicators of in-progress brute-force attempts or post-compromise activity occurring on the system."

# --- Failed SSH attempts (last 24h) ---
failed_count=0
# Try journald first (most reliable on systemd hosts)
if command -v journalctl &>/dev/null; then
    failed_count=$(journalctl -u ssh -u sshd --since "24 hours ago" 2>/dev/null \
        | grep -cE "Failed password|Invalid user|authentication failure")
    failed_count=${failed_count:-0}
fi
# Fallback: auth.log
if [[ $failed_count -eq 0 && -r /var/log/auth.log ]]; then
    today=$(date +"%b %e" | tr -s ' ')
    yesterday=$(date -d "yesterday" +"%b %e" | tr -s ' ')
    failed_count=$(grep -E "$today|$yesterday" /var/log/auth.log 2>/dev/null \
        | grep -cE "Failed password|Invalid user")
    failed_count=${failed_count:-0}
fi

# --- Top attacking IPs (if we have data) ---
top_ips=""
if [[ -r /var/log/auth.log ]]; then
    top_ips=$(grep "Failed password" /var/log/auth.log 2>/dev/null \
        | grep -oP "from \K[\d.]+" | sort | uniq -c | sort -rn | head -3 \
        | awk '{printf "%s(%s) ", $2, $1}')
fi

# --- Recent login history ---
printf " ${C_BOLD}${C_CYAN}%-12s | %-20s | %-14s | %s${C_RESET}\n" "User" "Login Time" "From" "Duration"
last -n 6 -R 2>/dev/null \
    | grep -v "^reboot\|^wtmp begins\|^$" \
    | head -6 \
    | while IFS= read -r line; do
        user=$(echo "$line" | awk '{print $1}')
        host=$(echo "$line" | awk '{print $3}')
        time_str=$(echo "$line" | awk '{print $4, $5, $6, $7}')
        dur=$(echo "$line" | grep -oP '\(\K[^)]+' | tail -1)
        printf " %-12s | %-20s | %-14s | %s\n" "$user" "$time_str" "${host:--}" "${dur:-still logged in}"
    done

# --- Summary ---
echo ""
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "SSH Failures (24h):" \
    "$( [[ $failed_count -eq 0 ]] && color_val "None" "None" "n/a" || color_val "$failed_count attempts" "n/a" "^[1-9]" )"
if [[ -n "$top_ips" ]]; then
    printf " ${C_BOLD}%-22s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Top Source IPs:" "$top_ips"
fi