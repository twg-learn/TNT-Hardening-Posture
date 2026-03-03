#!/usr/bin/env bash

print_header "SUID / SGID Binaries"
print_explain "SUID and SGID binaries execute with elevated privileges regardless of who invokes them. Non-standard SUID binaries are a common privilege escalation vector — attackers either exploit vulnerabilities within them or deliberately install them as backdoors. This section flags binaries not expected on a standard system."

# Known-good SUID directories — exact parent directory of the binary must match
_known_suid_dirs=(
    # Standard binary paths
    "/usr/bin" "/usr/sbin" "/bin" "/sbin"
    "/usr/local/bin" "/usr/local/sbin"
    # Top-level lib paths (for binaries placed directly here)
    "/usr/lib" "/usr/lib64" "/usr/lib/x86_64-linux-gnu"
    "/lib"     "/lib64"     "/lib/x86_64-linux-gnu"
    "/usr/libexec"
    # Known system subsystem helper directories
    "/usr/lib/openssh"
    "/usr/lib/polkit-1"       "/usr/libexec/polkit-1"
    "/usr/lib/dbus-1.0"
    "/usr/lib/xorg"
    "/usr/lib/policykit-1"
    "/usr/lib/eject"
    "/usr/lib/snapd"
    "/usr/lib/vmware-tools"
)

# Path prefixes for container/runtime overlay layers (excluded from host classification)
_container_prefixes=("/var/lib/docker" "/var/lib/containers" "/run/containerd")

# Find all SUID and SGID binaries (skip /proc, /sys, /dev, other mounts)
mapfile -t all_suid < <(find / -xdev -perm /4000 -type f 2>/dev/null | sort)
mapfile -t all_sgid < <(find / -xdev -perm /2000 -type f 2>/dev/null | sort)

suid_total=${#all_suid[@]}
sgid_total=${#all_sgid[@]}

# Classify SUID binaries into: standard, non-standard, container-layer
non_standard=()
standard_suid=()
container_suid=()

for f in "${all_suid[@]}"; do
    in_container=0
    for p in "${_container_prefixes[@]}"; do
        [[ "$f" == "$p"* ]] && in_container=1 && break
    done
    if [[ $in_container -eq 1 ]]; then
        container_suid+=("$f")
        continue
    fi
    dir=$(dirname "$f")
    is_known=0
    for d in "${_known_suid_dirs[@]}"; do
        [[ "$dir" == "$d" ]] && is_known=1 && break
    done
    if [[ $is_known -eq 1 ]]; then
        standard_suid+=("$f")
    else
        non_standard+=("$f")
    fi
done

ns_count=${#non_standard[@]}
container_count=${#container_suid[@]}
std_count=${#standard_suid[@]}

printf " ${C_BOLD}%-28s${C_RESET} %b\n" "SUID Binaries (total):" \
    "$(color_val "$suid_total" "^[0-9]$|^1[0-5]$" "^[2-4][0-9]$")"
printf " ${C_BOLD}%-28s${C_RESET} %b\n" "SGID Binaries (total):" \
    "$(color_val "$sgid_total" "^[0-9]$|^1[0-5]$" "^[2-4][0-9]$")"
# Context-aware non-standard SUID coloring:
#   Desktop/Mixed + non-High + non-Internet-Facing: up to 2 = yellow, more = red
#   Server / Internet-Facing / High adversary: any count > 0 = red
if [[ $ns_count -eq 0 ]]; then
    _ns_display="$(color_val "None" "None" "n/a")"
elif [[ "${TNT_ROLE:-Mixed}" == "Desktop" || "${TNT_ROLE:-Mixed}" == "Mixed" ]] && \
     [[ "${TNT_ADVERSARY:-High}" != "High" ]] && \
     [[ "${TNT_NETWORK:-Internet-Facing}" != "Internet-Facing" ]]; then
    if [[ $ns_count -le 2 ]]; then
        _ns_display="${C_YELLOW}${ns_count} found${C_RESET}"
    else
        _ns_display="${C_RED}${ns_count} found${C_RESET}"
    fi
else
    _ns_display="${C_RED}${ns_count} found${C_RESET}"
fi
printf " ${C_BOLD}%-28s${C_RESET} %b\n" "Non-Standard SUID paths:" "$_ns_display"
printf " ${C_BOLD}%-28s${C_RESET} %b\n" "Container-Layer SUID:" \
    "$( [[ $container_count -eq 0 ]] \
        && color_val "None" "None" "n/a" \
        || color_val "$container_count in overlays" "n/a" "overlays" )"

# List non-standard SUID binaries
if [[ $ns_count -gt 0 ]]; then
    printf "\n ${C_BOLD}${C_CYAN}%-46s  %-6s  %-16s  %s${C_RESET}\n" \
        "Path" "Mode" "Owner:Group" "Modified"
    for f in "${non_standard[@]}"; do
        read -r mode owner group mtime _ < <(stat -c "%a %U %G %y" "$f" 2>/dev/null)
        printf " ${C_RED}%-46s${C_RESET}  %-6s  %-16s  %s\n" \
            "$f" "$mode" "${owner}:${group}" "$mtime"
    done
fi

# World-writable SUID (critical) — reuse all_suid, no additional find
ww_suid=0
for f in "${all_suid[@]}"; do
    perm=$(stat -c "%a" "$f" 2>/dev/null)
    (( (perm % 10) & 2 )) && (( ww_suid++ ))
done

printf "\n ${C_BOLD}%-28s${C_RESET} %b\n" "World-Writable SUID:" \
    "$( [[ $ww_suid -eq 0 ]] \
        && color_val "None" "None" "n/a" \
        || color_val "$ww_suid CRITICAL" "n/a" "n/a" )"

# Known-safe SUID basenames: long-established, well-audited, minimal attack surface
_known_safe_suid=(
    su newgrp passwd chfn chsh gpasswd
    mount umount fusermount fusermount3
    ping ping6 traceroute6
    write wall crontab expiry
)

# Display all standard SUID binaries with color classification:
#   green  = known-safe, expected on any standard system
#   yellow = legitimate location but notable attack surface (sudo, pkexec, etc.)
echo ""
printf " ${C_BOLD}%-28s${C_RESET}\n" "Standard SUID binaries:"
for f in "${standard_suid[@]}"; do
    base=$(basename "$f")
    in_safe=0
    for s in "${_known_safe_suid[@]}"; do
        [[ "$base" == "$s" ]] && in_safe=1 && break
    done
    if [[ $in_safe -eq 1 ]]; then
        printf "   ${C_GREEN}%s${C_RESET}\n" "$f"
    else
        printf "   ${C_YELLOW}%s${C_RESET}\n" "$f"
    fi
done
