#!/usr/bin/env bash

print_header "Logging & Protection"
print_explain "Audit logging and intrusion prevention are foundational detective and preventive controls. This section checks for active logging daemons, auditd configuration, and tools like fail2ban that block repeated authentication failures before accounts can be compromised."

log_status=$(systemctl is-active systemd-journald 2>/dev/null)
ufw_status=$(systemctl is-active ufw 2>/dev/null)
f2b_status=$(systemctl is-active fail2ban 2>/dev/null)

printf " ${C_BOLD}%-22s${C_RESET} %b\n" "System Logging:" "$(color_val "$log_status" "active" "n/a")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "UFW Firewall:" "$(color_val "$ufw_status" "active" "n/a")"
# Context-aware: Internet-Facing or High adversary → inactive = red;
# LAN-Only / lower adversary → inactive = yellow (warn)
if [[ "${TNT_NETWORK:-Internet-Facing}" == "Internet-Facing" ]] || \
   [[ "${TNT_ADVERSARY:-High}" == "High" ]]; then
    _f2b_warn="n/a"       # inactive does not match "n/a" → red
else
    _f2b_warn="inactive"  # inactive matches → yellow
fi
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Fail2Ban Service:" "$(color_val "$f2b_status" "active" "$_f2b_warn")"

# AppArmor
if command -v aa-status &>/dev/null; then
    aa_mode=$(aa-status 2>/dev/null | grep -oP "apparmor module is \K\w+" | head -1)
    [[ -z "$aa_mode" ]] && aa_mode="unknown"
    aa_enforced=$(aa-status 2>/dev/null | grep -oP "^\d+ profiles are in enforce" | grep -oP "^\d+" || echo "0")
    aa_complain=$(aa-status 2>/dev/null | grep -oP "^\d+ profiles are in complain" | grep -oP "^\d+" || echo "0")
    aa_disp="${aa_mode} (enforce:${aa_enforced} complain:${aa_complain})"
    printf " ${C_BOLD}%-22s${C_RESET} %b\n" "AppArmor:" "$(color_val "$aa_disp" "enabled" "complain")"
else
    printf " ${C_BOLD}%-22s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "AppArmor:" "Not installed"
fi

# Audit strategy
auditd_status=$(systemctl is-active auditd 2>/dev/null || echo "inactive")
[[ "$auditd_status" == "active" ]] && audit_disp="Active" || audit_disp="Inactive"

is_remote=0
[[ -f /etc/rsyslog.conf ]] && grep -q "@" /etc/rsyslog.conf 2>/dev/null && is_remote=1
systemctl is-active --quiet systemd-journal-upload 2>/dev/null && is_remote=1

if [[ $is_remote -eq 1 ]]; then
    audit_level="Remote Forwarding (Centralized)"
elif [[ "$auditd_status" == "active" ]]; then
    audit_level="Enhanced (Auditd Enabled)"
else
    audit_level="Standard (Syslog/Journald)"
fi

printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Audit Strategy:" "$(color_val "$audit_level" "Remote" "Enhanced")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Auditd Service:" "$(color_val "$audit_disp" "Active" "n/a")"
