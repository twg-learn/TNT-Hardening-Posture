#!/usr/bin/env bash

print_header "Filesystem Security"
print_explain "Mount options and file permissions form a core defensive layer. Mounting /tmp and /dev/shm with noexec and nosuid prevents many common privilege escalation techniques. Correct permissions on files like /etc/passwd and /etc/shadow prevent credential exposure and unauthorized system modification."

# --- Mount flag checker ---
check_mount() {
    local mnt=$1
    local flags
    flags=$(grep -E " $mnt " /proc/mounts 2>/dev/null | awk '{print $4}' | head -1)

    if [[ -z "$flags" ]]; then
        printf " ${C_BOLD}%-22s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "$mnt" "not separately mounted"
        return
    fi

    local ne_col ns_col nd_col ne_sym ns_sym nd_sym

    if [[ "$flags" == *"noexec"* ]]; then
        ne_col="$C_GREEN"; ne_sym="✓ active  "
    else
        ne_col="$C_RED";   ne_sym="✗ absent  "
    fi
    if [[ "$flags" == *"nosuid"* ]]; then
        ns_col="$C_GREEN"; ns_sym="✓ active  "
    else
        ns_col="$C_RED";   ns_sym="✗ absent  "
    fi
    if [[ "$flags" == *"nodev"* ]]; then
        nd_col="$C_GREEN"; nd_sym="✓ active  "
    else
        nd_col="$C_RED";   nd_sym="✗ absent  "
    fi

    printf " ${C_BOLD}%-22s${C_RESET} ${ne_col}%-12s${C_RESET} ${ns_col}%-12s${C_RESET} ${nd_col}%-12s${C_RESET}\n" \
        "$mnt" "$ne_sym" "$ns_sym" "$nd_sym"
}

printf " ${C_BOLD}${C_CYAN}%-22s   %-12s %-12s %-12s${C_RESET}\n" "Mount Point" "noexec" "nosuid" "nodev"
for mnt in /tmp /var /home /dev/shm; do
    check_mount "$mnt"
done

# --- Disk usage ---
printf "\n ${C_BOLD}${C_CYAN}%-30s  %-6s  %-6s  %-6s${C_RESET}\n" "Filesystem" "Size" "Used" "Use%"
df -h --output=target,size,used,pcent 2>/dev/null \
    | grep -vE "^Filesystem|tmpfs|udev|overlay|/boot/efi" \
    | grep -E "^/[^ ]*" | head -5 \
    | while read -r target size used pct; do
        use_num=${pct//%/}
        col="$C_GREEN"
        [[ $use_num -ge 75 ]] && col="$C_YELLOW"
        [[ $use_num -ge 90 ]] && col="$C_RED"
        printf " %-30s  %-6s  %-6s  ${col}%-6s${C_RESET}\n" "$target" "$size" "$used" "$pct"
    done

print_header "Sensitive File Permissions"
printf " ${C_BOLD}${C_CYAN}%-28s  %-6s  %-12s  %s${C_RESET}\n" "File" "Mode" "Owner:Group" "Status"

check_perm() {
    local file=$1 expected_mode=$2
    if [[ ! -f "$file" ]]; then
        printf " %-28s  %-6s  %-12s  ${C_YELLOW}%s${C_RESET}\n" "$file" "-" "-" "Not found"
        return
    fi
    local stat_out mode owner group
    stat_out=$(stat -c "%a %U %G" "$file" 2>/dev/null)
    mode=$(echo "$stat_out"  | awk '{print $1}')
    owner=$(echo "$stat_out" | awk '{print $2}')
    group=$(echo "$stat_out" | awk '{print $3}')
    if [[ "$mode" == "$expected_mode" ]]; then
        printf " %-28s  %-6s  %-12s  ${C_GREEN}%s${C_RESET}\n" "$file" "$mode" "${owner}:${group}" "OK"
    else
        printf " %-28s  %-6s  %-12s  ${C_RED}%s${C_RESET}\n"   "$file" "$mode" "${owner}:${group}" "Expected ${expected_mode}"
    fi
}

check_perm "/etc/passwd"          "644"
check_perm "/etc/shadow"          "640"
check_perm "/etc/gshadow"         "640"
check_perm "/etc/sudoers"         "440"
check_perm "/etc/ssh/sshd_config" "600"
check_perm "/etc/crontab"         "600"