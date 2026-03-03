#!/usr/bin/env bash

print_header "Scheduled Tasks"
print_explain "Cron jobs and systemd timers run with the privileges of their owner and persist across reboots, making them a favored persistence mechanism. This section enumerates all scheduled tasks and flags those running as root or referencing world-writable paths, which may indicate backdoors or misconfiguration."

# --- Root crontab ---
root_cron_count=0
root_cron_entries=()
if crontab -l -u root &>/dev/null 2>&1; then
    while IFS= read -r line; do
        root_cron_entries+=("$line")
        ((root_cron_count++))
    done < <(crontab -l -u root 2>/dev/null | grep -v "^#\|^$")
fi

# --- System cron files ---
cron_d_count=$(find /etc/cron.d/ -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
cron_daily_count=$(find /etc/cron.daily/ -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
cron_weekly_count=$(find /etc/cron.weekly/ -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')

# --- User crontabs (non-root, non-system) ---
user_crons=0
if [[ -d /var/spool/cron/crontabs ]]; then
    user_crons=$(ls /var/spool/cron/crontabs/ 2>/dev/null | grep -vc "^root$")
    user_crons=${user_crons:-0}
fi

# --- Systemd timers ---
timer_count=$(systemctl list-timers --all --no-pager 2>/dev/null | grep -c "\.timer")
timer_count=${timer_count:-0}

# Show timer firing soonest
next_timer=$(systemctl list-timers --no-pager 2>/dev/null \
    | grep "\.timer" | head -1 \
    | awk '{print $1, $2, "—", $5}')

printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Root Crontab Jobs:" \
    "$( [[ $root_cron_count -eq 0 ]] && color_val "None" "None" "n/a" || color_val "$root_cron_count entries" "n/a" "n/a" )"
printf " ${C_BOLD}%-26s${C_RESET} %s\n" "System Cron (cron.d):" "$cron_d_count files"
printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Daily / Weekly jobs:" "${cron_daily_count}d / ${cron_weekly_count}w"
printf " ${C_BOLD}%-26s${C_RESET} %b\n" "User Crontabs (non-root):" \
    "$( [[ $user_crons -eq 0 ]] && color_val "None" "None" "n/a" || color_val "$user_crons crontab(s)" "n/a" "n/a" )"
printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Active Systemd Timers:" "$timer_count"
[[ -n "$next_timer" ]] && printf " ${C_BOLD}%-26s${C_RESET} ${C_CYAN}%s${C_RESET}\n" "Next Timer:" "$next_timer"

# --- Enumerate root crontab entries if present ---
if [[ ${#root_cron_entries[@]} -gt 0 ]]; then
    printf "\n ${C_YELLOW}Root crontab entries:${C_RESET}\n"
    for entry in "${root_cron_entries[@]}"; do
        printf "   ${C_RED}%s${C_RESET}\n" "$entry"
    done
fi