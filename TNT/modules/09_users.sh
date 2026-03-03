#!/usr/bin/env bash

print_header "Users & Privileges"
print_explain "Privilege escalation is a critical step in most attacks. This section audits accounts with elevated privileges, sudo configuration, and password policy. Overly broad sudo rights, passwordless sudo, or excessive root-equivalent accounts dramatically increase the potential impact of any initial breach."

# --- UID 0 accounts (should only be root) ---
uid0_accounts=$(awk -F: '$3==0 {print $1}' /etc/passwd | tr '\n' ' ' | sed 's/ $//')
uid0_count=$(awk -F: '$3==0' /etc/passwd | wc -l | tr -d ' ')
[[ $uid0_count -eq 1 ]] && uid0_disp="root only" || uid0_disp="${uid0_count} found: ${uid0_accounts}"

# --- Login-shell users (non-system, UID >= 1000) ---
shell_users=$(awk -F: '$3>=1000 && $7 !~ /nologin|false|sync/ {print $1}' /etc/passwd | tr '\n' ' ' | sed 's/ $//')
shell_count=$(awk -F: '$3>=1000 && $7 !~ /nologin|false|sync/' /etc/passwd | wc -l | tr -d ' ')

# --- Sudoers (rules granting ALL) ---
# grep -c exits 1 on zero matches, so never use || echo 0 — use ${var:-0} instead
sudo_rules=0
if [[ -r /etc/sudoers ]]; then
    sudo_rules=$(grep -v "^#\|^$\|^Defaults" /etc/sudoers 2>/dev/null | grep -c "ALL")
    sudo_rules=${sudo_rules:-0}
fi
if [[ -d /etc/sudoers.d ]]; then
    extra=$(grep -rh --include='*' -v "^#\|^$" /etc/sudoers.d/ 2>/dev/null | grep -c "ALL")
    extra=${extra:-0}
    sudo_rules=$(( sudo_rules + extra ))
fi

# --- NOPASSWD rules ---
nopass_rules=$(grep -rh "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -vc "^#")
nopass_rules=${nopass_rules:-0}
[[ $nopass_rules -eq 0 ]] && nopass_disp="None" || nopass_disp="${nopass_rules} rule(s) found"

# --- Active sessions ---
active_sessions=$(who 2>/dev/null | wc -l | tr -d ' ')

# --- Last login ---
last_entry=$(last -n1 -R 2>/dev/null | grep -v "^reboot\|^wtmp\|^$" | head -1)
last_user=$(echo "$last_entry" | awk '{print $1}')
last_from=$(echo "$last_entry" | awk '{print $3}')
last_time=$(echo "$last_entry" | awk '{print $4, $5, $6, $7}')
[[ -n "$last_user" ]] && last_disp="${last_user} from ${last_from} @ ${last_time}" || last_disp="No data"

printf " ${C_BOLD}%-22s${C_RESET} %b\n"  "UID 0 Accounts:"    "$(color_val "$uid0_disp"      "root only"  "n/a")"
printf " ${C_BOLD}%-22s${C_RESET} ${C_CYAN}%s${C_RESET} (%s)\n" "Login Shell Users:" "$shell_users" "$shell_count"
# Context-aware sudo thresholds:
#   High adversary:   0-1 = green, 2+ = red  (tightest)
#   Moderate (default): 0-1 = green, 2-4 = yellow, 5+ = red
#   Low adversary:    0-4 = green, 5-7 = yellow, 8+ = red  (most lenient)
if [[ "${TNT_ADVERSARY:-High}" == "High" ]]; then
    _sudo_good="^[01]$"
    _sudo_warn="^NOMATCH$"   # 2+ goes straight to red
elif [[ "${TNT_ADVERSARY:-High}" == "Low" ]]; then
    _sudo_good="^[0-4]$"
    _sudo_warn="^[5-7]$"
else
    _sudo_good="^[01]$"
    _sudo_warn="^[2-4]$"
fi
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Sudo (ALL rules):" "$(color_val "$sudo_rules" "$_sudo_good" "$_sudo_warn")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n"  "NOPASSWD Rules:"    "$(color_val "$nopass_disp"    "None"       "n/a")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n"  "Active Sessions:"   "$(color_val "$active_sessions" "^[01]$"    "^[2-4]$")"
printf " ${C_BOLD}%-22s${C_RESET} %s\n"  "Last Login:"        "$last_disp"