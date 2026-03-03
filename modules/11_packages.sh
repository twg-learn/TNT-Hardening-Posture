#!/usr/bin/env bash

print_header "Package & Update Posture"
print_explain "Unpatched software is among the leading causes of successful exploitation. This section checks for pending security updates and whether automatic updates are configured. Systems with outstanding CVEs are significantly easier to compromise and should be patched as a priority."

if command -v apt-get &>/dev/null; then
    # Use cached notifier file if available (fast, no apt resolve)
    notifier_file="/var/lib/update-notifier/updates-available"
    if [[ -f "$notifier_file" ]]; then
        pending=$(grep -oP '^\d+' "$notifier_file" 2>/dev/null | head -1 || echo "?")
        security=$(grep -oP '\d+ security' "$notifier_file" 2>/dev/null | grep -oP '^\d+' || echo "0")
    else
        # Fallback: parse apt list (fast read, no network)
        upgradable=$(apt list --upgradable 2>/dev/null | tail -n +2)
        pending=$(echo "$upgradable" | grep -c . || echo 0)
        security=$(echo "$upgradable" | grep -c "security" || echo 0)
    fi

    # Days since last apt cache update
    cache="/var/cache/apt/pkgcache.bin"
    if [[ -f "$cache" ]]; then
        last_ts=$(stat -c "%Y" "$cache" 2>/dev/null)
        now_ts=$(date +%s)
        days_ago=$(( (now_ts - last_ts) / 86400 ))
        [[ $days_ago -eq 0 ]] && age_disp="Today" || age_disp="${days_ago} days ago"
    else
        days_ago=99
        age_disp="Unknown"
    fi

    # Unattended upgrades
    ua_status=$(systemctl is-active unattended-upgrades 2>/dev/null)
    [[ -z "$ua_status" ]] && ua_status="not installed"

    # Reboot required?
    reboot_needed="No"
    [[ -f /var/run/reboot-required ]] && reboot_needed="YES — kernel or lib updated"

    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Pending Updates:" \
        "$( [[ "$pending" == "0" ]] && color_val "Up to date" "Up to date" "n/a" || color_val "$pending packages" "n/a" "n/a" )"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Security Updates:" \
        "$( [[ "$security" == "0" ]] && color_val "None pending" "None" "n/a" || color_val "$security pending" "n/a" "n/a" )"
    printf " ${C_BOLD}%-26s${C_RESET} %b (%s)\n" "Last apt-get update:" \
        "$( [[ $days_ago -lt 7 ]] && color_val "Recent" "Recent" "n/a" || \
            ( [[ $days_ago -lt 30 ]] && color_val "Aging" "n/a" "Aging" ) || \
            color_val "Stale" "n/a" "n/a" )" "$age_disp"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Unattended Upgrades:" "$(color_val "$ua_status" "active" "n/a")"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Reboot Required:" \
        "$( [[ "$reboot_needed" == "No" ]] && color_val "No" "No" "n/a" || color_val "$reboot_needed" "n/a" "n/a" )"

elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    mgr=$(command -v dnf &>/dev/null && echo "dnf" || echo "yum")
    pending=$($mgr check-update --quiet 2>/dev/null | grep -c "^[a-zA-Z]" || echo "?")
    printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Package Manager:" "$mgr"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Pending Updates:" \
        "$( [[ "$pending" == "0" ]] && color_val "Up to date" "Up to date" "n/a" || color_val "$pending packages" "n/a" "n/a" )"
else
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Package Manager:" "apt/dnf/yum not found"
fi
