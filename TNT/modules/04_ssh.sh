#!/usr/bin/env bash

print_header "SSH Hardening"
print_explain "SSH is the most common remote access vector on Linux. Weak configurations — such as password authentication, permitted root login, or outdated ciphers — enable credential brute-force and interception attacks. This section audits the active SSH daemon configuration against hardening best practices."

if [[ -f /etc/ssh/sshd_config ]]; then
    p_root=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
    p_pass=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')

    root_val=${p_root:-prohibit-password}
    [[ "$root_val" == "no" ]]                && root_disp="Disabled (Secure)"
    [[ "$root_val" == "prohibit-password" ]] && root_disp="Keys Only (Standard)"
    [[ "$root_val" == "yes" ]]               && root_disp="Enabled (Weak)"

    pass_val=${p_pass:-yes}
    [[ "$pass_val" == "no" ]]  && pass_disp="Disabled (Key-Only)"
    [[ "$pass_val" == "yes" ]] && pass_disp="Enabled (Password Allowed)"

    printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Permit Root Login:" "$(color_val "$root_disp" "Secure" "Standard")"
    # Context-aware: Internet-Facing or High adversary → password enabled = red;
    # VPN/LAN-Only with lower adversary → yellow (warn only)
    if [[ "${TNT_NETWORK:-Internet-Facing}" == "Internet-Facing" ]] || \
       [[ "${TNT_ADVERSARY:-High}" == "High" ]]; then
        _pass_warn="none"    # nothing is warn → Enabled goes straight to red
    else
        _pass_warn="Enabled" # Enabled is yellow
    fi
    printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Password Auth:" "$(color_val "$pass_disp" "Key-Only" "$_pass_warn")"

    ssh_port=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}')
    ssh_port=${ssh_port:-22}
    is_scoped=$(grep -Ei "^AllowUsers|^AllowGroups|^Match" /etc/ssh/sshd_config | wc -l)

    if [[ "$ssh_port" != "22" ]] && [[ $is_scoped -gt 0 ]]; then ssh_profile="Restricted & Obscured"
    elif [[ $is_scoped -gt 0 ]];                               then ssh_profile="IP/User Restricted"
    elif [[ "$ssh_port" != "22" ]];                            then ssh_profile="Port Obscured"
    else                                                             ssh_profile="Standard (Open)"
    fi

    printf " ${C_BOLD}%-22s${C_RESET} %b (Port: %s)\n" "Access Profile:" \
        "$(color_val "$ssh_profile" "Restricted" "Obscured")" "$ssh_port"
else
    echo -e " ${C_RED}SSH Status: /etc/ssh/sshd_config not found.${C_RESET}"
fi

# --- Authorized Keys Audit ---
echo ""
printf " ${C_SECTION}%s${C_RESET}\n" "── Authorized Keys ──"

key_files=()
issues=0

while IFS=: read -r user _ uid _ _ homedir shell; do
    [[ $uid -ne 0 && $uid -lt 1000 ]] && continue
    echo "$shell" | grep -qE "nologin|false|sync" && continue

    for f in "${homedir}/.ssh/authorized_keys" "${homedir}/.ssh/authorized_keys2"; do
        [[ -f "$f" ]] || continue
        key_count=$(grep -cE "^(ssh-|ecdsa-|sk-)" "$f" 2>/dev/null)
        key_count=${key_count:-0}
        [[ $key_count -eq 0 ]] && continue

        key_files+=("$f")

        fmode=$(stat -c "%a" "$f" 2>/dev/null)
        fowner=$(stat -c "%U" "$f" 2>/dev/null)

        mode_ok=1; owner_ok=1
        [[ "$fmode" != "600" && "$fmode" != "400" ]] && mode_ok=0 && ((issues++))
        [[ "$fowner" != "$user" && "$fowner" != "root" ]] && owner_ok=0 && ((issues++))
        [[ "$user" == "root" ]] && ((issues++))

        printf " ${C_BOLD}%-28s${C_RESET} user:${C_CYAN}%-10s${C_RESET} keys:${C_CYAN}%-3s${C_RESET} " \
            "$f" "$user" "$key_count"
        [[ $mode_ok -eq 1 ]] && printf "mode:${C_GREEN}%-4s${C_RESET} " "$fmode" \
                              || printf "mode:${C_RED}%-4s${C_RESET} "   "$fmode"
        [[ $owner_ok -eq 1 ]] && printf "owner:${C_GREEN}%s${C_RESET}" "$fowner" \
                               || printf "owner:${C_RED}%s${C_RESET}"   "$fowner"
        [[ "$user" == "root" ]] && printf " ${C_RED}[root key — high risk]${C_RESET}"
        printf "\n"
    done
done < /etc/passwd

if [[ ${#key_files[@]} -eq 0 ]]; then
    printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Authorized Keys:" "None found on system"
else
    echo ""
    printf " ${C_BOLD}${C_CYAN}%-28s  %-10s  %s${C_RESET}\n" ".ssh Directory" "Mode" "Status"
    while IFS=: read -r user _ uid _ _ homedir shell; do
        [[ $uid -ne 0 && $uid -lt 1000 ]] && continue
        echo "$shell" | grep -qE "nologin|false|sync" && continue
        ssh_dir="${homedir}/.ssh"
        [[ -d "$ssh_dir" ]] || continue
        dmode=$(stat -c "%a" "$ssh_dir" 2>/dev/null)
        if [[ "$dmode" == "700" || "$dmode" == "600" ]]; then
            printf " %-28s  ${C_GREEN}%-10s${C_RESET}  ${C_GREEN}OK${C_RESET}\n" "$ssh_dir" "$dmode"
        else
            printf " %-28s  ${C_RED}%-10s${C_RESET}  ${C_RED}Should be 700${C_RESET}\n" "$ssh_dir" "$dmode"
            ((issues++))
        fi
    done < /etc/passwd

    echo ""
    if [[ $issues -eq 0 ]]; then
        printf " ${C_BOLD}%-28s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Issues Found:" "None"
    else
        printf " ${C_BOLD}%-28s${C_RESET} ${C_RED}%s permission/ownership issue(s) detected${C_RESET}\n" \
            "Issues Found:" "$issues"
    fi
    printf " ${C_BOLD}%-28s${C_RESET} %s\n" "Total Key Files:" "${#key_files[@]}"
fi
