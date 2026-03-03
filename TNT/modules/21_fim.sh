#!/usr/bin/env bash

print_header "File Integrity Monitoring"
print_explain "File integrity monitoring detects unauthorized changes to critical system files such as binaries, libraries, and configuration. Tools like AIDE or Tripwire alert when files are modified outside of normal maintenance windows, providing early warning of compromise or tampered system software."

fim_found=0

# --- AIDE ---
if command -v aide &>/dev/null; then
    fim_found=1
    aide_ver=$(aide --version 2>/dev/null | head -1 | grep -oP "[\d.]+")
    aide_db="/var/lib/aide/aide.db"
    aide_db_new="/var/lib/aide/aide.db.new"

    if [[ -f "$aide_db" ]]; then
        db_age_days=$(( ( $(date +%s) - $(stat -c "%Y" "$aide_db" 2>/dev/null || echo 0) ) / 86400 ))
        [[ $db_age_days -eq 0 ]] && db_age_disp="Today" || db_age_disp="${db_age_days} days ago"
        db_disp="Present (last updated: $db_age_disp)"
        db_col=$( [[ $db_age_days -le 7 ]] && echo "$C_GREEN" || \
                  [[ $db_age_days -le 30 ]] && echo "$C_YELLOW" || echo "$C_RED" )
    else
        db_disp="NOT INITIALIZED — no baseline database"
        db_col="$C_RED"
    fi

    printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET} (v%s)\n" "AIDE:" "Installed" "${aide_ver:-unknown}"
    printf " ${C_BOLD}%-28s${C_RESET} ${db_col}%s${C_RESET}\n" "  Database:" "$db_disp"
    [[ -f "$aide_db_new" ]] && printf " ${C_BOLD}%-28s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" \
        "  Pending DB:" "aide.db.new exists — run aide --update to commit"

    # Check if aide check is scheduled
    aide_cron=$(grep -r "aide" /etc/cron* /var/spool/cron/crontabs/ 2>/dev/null | grep -vc "^#")
    aide_cron=${aide_cron:-0}
    aide_timer=$(systemctl list-timers --all --no-pager 2>/dev/null | grep -c "aide")
    aide_timer=${aide_timer:-0}
    scheduled=$(( aide_cron + aide_timer ))
    printf " ${C_BOLD}%-28s${C_RESET} %b\n" "  Scheduled Checks:" \
        "$( [[ $scheduled -gt 0 ]] \
            && color_val "Yes ($scheduled schedule(s))" "Yes" "n/a" \
            || color_val "Not scheduled" "n/a" "n/a" )"
fi

# --- Tripwire ---
if command -v tripwire &>/dev/null; then
    fim_found=1
    tw_db=$(find /var/lib/tripwire /etc/tripwire -name "*.twd" 2>/dev/null | head -1)
    printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Tripwire:" "Installed"
    printf " ${C_BOLD}%-28s${C_RESET} %b\n" "  Database:" \
        "$( [[ -n "$tw_db" ]] \
            && color_val "Present: $tw_db" "Present" "n/a" \
            || color_val "Not initialized" "n/a" "n/a" )"
fi

# --- Samhain ---
if command -v samhain &>/dev/null; then
    fim_found=1
    printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Samhain:" "Installed"
fi

# --- dm-verity (immutable root — common in containers/appliances) ---
if dmsetup status 2>/dev/null | grep -qi "verity"; then
    fim_found=1
    printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "dm-verity:" "Active (immutable block layer)"
elif [[ -f /proc/sys/kernel/verity_enabled ]]; then
    fim_found=1
    printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "dm-verity:" "Enabled"
fi

# --- INotify-based tools ---
for tool in inotifywait incron auditctl; do
    if command -v "$tool" &>/dev/null; then
        fim_found=1
        printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "${tool}:" "Available"
    fi
done

# --- Auditd FIM rules ---
if command -v auditctl &>/dev/null && systemctl is-active --quiet auditd 2>/dev/null; then
    fim_watch_rules=$(auditctl -l 2>/dev/null | grep -c "\-w ")
    fim_watch_rules=${fim_watch_rules:-0}
    printf " ${C_BOLD}%-28s${C_RESET} %b\n" "Auditd Watch Rules:" \
        "$( [[ $fim_watch_rules -gt 0 ]] \
            && color_val "$fim_watch_rules active -w rules" "$fim_watch_rules" "n/a" \
            || color_val "None configured" "n/a" "n/a" )"
fi

if [[ $fim_found -eq 0 ]]; then
    printf " ${C_BOLD}%-28s${C_RESET} ${C_RED}%s${C_RESET}\n" "FIM Status:" \
        "No FIM solution detected — binary tampering would go undetected"
fi