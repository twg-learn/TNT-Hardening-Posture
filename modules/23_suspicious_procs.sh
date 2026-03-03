#!/usr/bin/env bash

print_header "Suspicious Process Indicators"
print_explain "Running processes reveal what is actively executing on the system. This section looks for processes running from temporary directories, with deleted executables, or bearing names associated with common attack tools. These patterns are strong indicators of active compromise or persistent malware presence."

suspicious_total=0

# --- Helper: print a finding ---
_finding() {
    local sev=$1 label=$2 detail=$3
    case "$sev" in
        CRIT) col="$C_RED" ;;
        WARN) col="$C_YELLOW" ;;
        *)    col="$C_CYAN" ;;
    esac
    printf " ${col}[%s]${C_RESET} ${C_BOLD}%s${C_RESET}  %s\n" "$sev" "$label" "$detail"
    ((suspicious_total++))
}

# --- 1. Processes executing from /tmp, /dev/shm, /run (non-systemd), /var/tmp ---
printf " ${C_BOLD}${C_CYAN}%s${C_RESET}\n" "Processes running from suspicious paths:"
found_path=0
for pid in /proc/[0-9]*; do
    [[ -d "$pid" ]] || continue
    exe=$(readlink "${pid}/exe" 2>/dev/null)
    [[ -z "$exe" ]] && continue
    if echo "$exe" | grep -qE "^/tmp/|^/dev/shm/|^/var/tmp/|^/run/user/[0-9]+/[^s]"; then
        cmd=$(cat "${pid}/cmdline" 2>/dev/null | tr '\0' ' ' | cut -c1-60)
        pidnum=$(basename "$pid")
        _finding "CRIT" "Proc from $exe" "pid:$pidnum  cmd:$cmd"
        found_path=1
    fi
done
[[ $found_path -eq 0 ]] && printf "   ${C_GREEN}None found${C_RESET}\n"

# --- 2. Processes with deleted executable on disk ---
echo ""
printf " ${C_BOLD}${C_CYAN}%s${C_RESET}\n" "Processes with deleted/replaced binaries:"
found_deleted=0
for pid in /proc/[0-9]*; do
    [[ -d "$pid" ]] || continue
    exe_link="${pid}/exe"
    # readlink will append " (deleted)" if the inode is gone
    exe_str=$(readlink "$exe_link" 2>/dev/null)
    if echo "$exe_str" | grep -q "(deleted)"; then
        exe_clean=$(echo "$exe_str" | sed 's/ (deleted)//')
        cmd=$(cat "${pid}/cmdline" 2>/dev/null | tr '\0' ' ' | cut -c1-50)
        pidnum=$(basename "$pid")
        # Exclude known benign cases (systemd socket activation, etc.)
        echo "$exe_clean" | grep -qE "^/usr/|^/lib/|^/bin/|^/sbin/" \
            && sev="WARN" || sev="CRIT"
        _finding "$sev" "Deleted binary: $exe_clean" "pid:$pidnum  cmd:$cmd"
        found_deleted=1
    fi
done
[[ $found_deleted -eq 0 ]] && printf "   ${C_GREEN}None found${C_RESET}\n"

# --- 3. Processes with no executable path (kernel threads are ok, filter them) ---
echo ""
printf " ${C_BOLD}${C_CYAN}%s${C_RESET}\n" "Processes with no readable exe link (non-kernel):"
found_noexe=0
for pid in /proc/[0-9]*; do
    [[ -d "$pid" ]] || continue
    pidnum=$(basename "$pid")
    # Kernel threads have empty cmdline
    [[ -s "${pid}/cmdline" ]] || continue
    exe=$(readlink "${pid}/exe" 2>/dev/null)
    if [[ -z "$exe" ]]; then
        comm=$(cat "${pid}/comm" 2>/dev/null)
        cmd=$(tr '\0' ' ' < "${pid}/cmdline" 2>/dev/null | cut -c1-50)
        _finding "WARN" "No exe: $comm" "pid:$pidnum  cmd:$cmd"
        found_noexe=1
    fi
done
[[ $found_noexe -eq 0 ]] && printf "   ${C_GREEN}None found${C_RESET}\n"

# --- 4. Processes listening on unexpected high ports (>1024) as root ---
echo ""
printf " ${C_BOLD}${C_CYAN}%s${C_RESET}\n" "Root processes on high ports (>1024, non-standard):"
found_highport=0
while IFS= read -r line; do
    port=$(echo "$line" | grep -oP ":\K\d+" | tail -1)
    [[ -z "$port" || $port -le 1024 ]] && continue
    pid_info=$(echo "$line" | grep -oP 'pid=\K\d+')
    [[ -z "$pid_info" ]] && continue
    uid=$(awk '{print $9}' "/proc/${pid_info}/status" 2>/dev/null | head -1)
    [[ "$uid" != "0" ]] && continue
    prog=$(cat "/proc/${pid_info}/comm" 2>/dev/null)
    # Skip known expected services
    echo "$prog" | grep -qE "sshd|systemd|docker|containerd|kubelet|dnsmasq|kdeconnect" && continue
    _finding "WARN" "Root on port $port" "pid:$pid_info  proc:$prog"
    found_highport=1
done < <(ss -H -tlpn 2>/dev/null | grep LISTEN)
[[ $found_highport -eq 0 ]] && printf "   ${C_GREEN}None found${C_RESET}\n"

# --- Summary ---
echo ""
if [[ $suspicious_total -eq 0 ]]; then
    printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Overall:" "No suspicious indicators detected"
else
    printf " ${C_BOLD}%-26s${C_RESET} ${C_RED}%s indicator(s) flagged${C_RESET}\n" "Overall:" "$suspicious_total"
fi