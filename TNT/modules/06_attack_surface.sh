#!/usr/bin/env bash

print_header "Attack Surface Density"
print_explain "A minimal attack surface limits the opportunities available to an attacker. This section counts installed packages, enabled services, and listening daemons to assess unnecessary software presence. Reducing installed and running software directly reduces the number of exploitable vulnerabilities on the system."

total_running=$(systemctl list-units --type=service --state=running --no-pager | grep -c "\.service")

leaky_list=("avahi-daemon" "cups" "bluetooth" "rpcbind" "snapd")
leaks_found=0
leaky_names=()
for service in "${leaky_list[@]}"; do
    if systemctl is-active --quiet "$service"; then
        ((leaks_found++))
        leaky_names+=("$service")
    fi
done

if [[ $total_running -lt 25 ]] && [[ $leaks_found -eq 0 ]]; then density_label="Minimal"
elif [[ $leaks_found -gt 0 ]]; then density_label="Standard (Extraneous Daemons Active)"
elif [[ $total_running -gt 50 ]]; then density_label="High Exposure"
else density_label="Standard"
fi

printf " ${C_BOLD}%-22s${C_RESET} %b | %s active services\n" "Surface Profile:" "$(color_val "$density_label" "Minimal" "Standard")" "$total_running"

if [[ $leaks_found -eq 0 ]]; then
    printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Extraneous Daemons:" "$(color_val "None Detected" "None Detected" "n/a")"
else
    # Context-aware: avahi/cups/bluetooth are expected on Desktop; Server or Internet-Facing = red
    if [[ "${TNT_ROLE:-Mixed}" == "Desktop" ]] && \
       [[ "${TNT_NETWORK:-Internet-Facing}" != "Internet-Facing" ]]; then
        _daemon_col="$C_YELLOW"
    else
        _daemon_col="$C_RED"
    fi
    printf " ${C_BOLD}%-22s${C_RESET} ${_daemon_col}%s${C_RESET} — ${C_YELLOW}%s${C_RESET}\n" \
        "Extraneous Daemons:" "Detected ($leaks_found)" "$(IFS=', '; echo "${leaky_names[*]}")"
fi

is_ro=$(grep -w "/" /proc/mounts | grep -c "ro,")
fs_val=$([[ $is_ro -eq 1 ]] && echo "Read-Only (Immutable)" || echo "Read-Write (Standard)")
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Root Filesystem:" "$(color_val "$fs_val" "Read-Only" "Read-Write")"