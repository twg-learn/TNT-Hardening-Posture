#!/usr/bin/env bash

print_header "Kernel Hardening (sysctl)"
print_explain "Kernel sysctl parameters govern low-level OS security behavior including network stack hardening, memory protections, and process isolation. Misconfigured sysctls can enable IP spoofing, ICMP redirect attacks, or allow unprivileged users to inspect or interfere with other processes on the system."

# Helper: read a sysctl value cleanly
_sctl() { sysctl -n "$1" 2>/dev/null; }

# Helper: print a sysctl check row
#   label  key  expected_val  good_pattern  warn_pattern  note
_srow() {
    local label=$1 key=$2 expected=$3 good=$4 warn=$5 note=$6
    local val
    val=$(_sctl "$key")
    if [[ -z "$val" ]]; then
        printf " ${C_BOLD}%-34s${C_RESET} ${C_YELLOW}%-6s${C_RESET}  %s\n" "$label" "N/A" "$key"
        return
    fi
    local col
    if [[ "$val" =~ $good ]]; then col="$C_GREEN"
    elif [[ -n "$warn" && "$val" =~ $warn ]]; then col="$C_YELLOW"
    else col="$C_RED"; fi
    printf " ${C_BOLD}%-34s${C_RESET} ${col}%-6s${C_RESET}  ${C_CYAN}%s${C_RESET}  %s\n" \
        "$label" "$val" "(want: $expected)" "$note"
}

printf " ${C_BOLD}${C_CYAN}%-34s  %-6s  %-16s  %s${C_RESET}\n" "Parameter" "Value" "Target" "Key"

echo ""
printf " ${C_SECTION}%s${C_RESET}\n" "── Network ──"
_srow "IPv4 RP Filter (enp/eth)"    "net.ipv4.conf.all.rp_filter"         "1 or 2"  "^[12]$"  ""      "anti-spoofing"
_srow "TCP SYN Cookies"             "net.ipv4.tcp_syncookies"             "1"       "^1$"     ""      "SYN flood protection"
_srow "ICMP Redirects (send)"       "net.ipv4.conf.all.send_redirects"    "0"       "^0$"     ""      "disable ICMP redirects"
_srow "ICMP Redirects (accept)"     "net.ipv4.conf.all.accept_redirects"  "0"       "^0$"     ""      ""
_srow "IPv6 Redirects (accept)"     "net.ipv6.conf.all.accept_redirects"  "0"       "^0$"     ""      ""
_srow "Source Route (accept)"       "net.ipv4.conf.all.accept_source_route" "0"     "^0$"     ""      "no loose source routing"
_srow "Log Martians"                "net.ipv4.conf.all.log_martians"      "1"       "^1$"     ""      "log spoofed/bogon packets"
# Context-aware: Hypervisor expects forwarding on (green); Server tolerates it (yellow); Desktop flags it (red)
if [[ "${TNT_ROLE:-Mixed}" == "Hypervisor" ]]; then
    _srow "IPv4 Forwarding"         "net.ipv4.ip_forward"  "1 (hypervisor)"  "^[01]$"  ""     "VM host: 1 expected"
elif [[ "${TNT_ROLE:-Mixed}" == "Server" || "${TNT_ROLE:-Mixed}" == "Mixed" ]]; then
    _srow "IPv4 Forwarding"         "net.ipv4.ip_forward"  "0"               "^0$"     "^1$"  "router/VM host: 1 expected"
else
    _srow "IPv4 Forwarding"         "net.ipv4.ip_forward"  "0"               "^0$"     ""     "unexpected on desktop"
fi

echo ""
printf " ${C_SECTION}%s${C_RESET}\n" "── Kernel / Memory ──"
_srow "ASLR"                        "kernel.randomize_va_space"           "2"       "^2$"     "^1$"   "2=full, 1=partial"
_srow "kptr Restrict"               "kernel.kptr_restrict"                "1 or 2"  "^[12]$"  ""      "hide kernel pointers"
_srow "dmesg Restrict"              "kernel.dmesg_restrict"               "1"       "^1$"     ""      "non-root dmesg access"
_srow "SUID Core Dumps"             "fs.suid_dumpable"                    "0"       "^0$"     "^2$"   "0=disabled, 2=ptrace only"
_srow "Perf Event Restrict"         "kernel.perf_event_paranoid"          "2 or 3"  "^[23]$"  "^1$"   "limit perf access"
_srow "BPF Hardening"               "kernel.unprivileged_bpf_disabled"    "1"       "^1$"     ""      "block unpriv eBPF"
# Context-aware: Desktop tolerates enabled (yellow); Server/Hypervisor flags it red
if [[ "${TNT_ROLE:-Mixed}" == "Desktop" ]]; then
    _srow "Unprivileged User NS"    "kernel.unprivileged_userns_clone"  "0"  "^0$"  "^1$"  "container escape vector"
else
    _srow "Unprivileged User NS"    "kernel.unprivileged_userns_clone"  "0"  "^0$"  ""     "container escape vector"
fi
_srow "PID Namespace Restrict"      "kernel.pid_max"                      "see val" ".*"      ""      ""
# Context-aware: Desktop + Low adversary treats scope=0 as yellow; all other contexts treat it as red
if [[ "${TNT_ROLE:-Mixed}" == "Desktop" ]] && [[ "${TNT_ADVERSARY:-High}" == "Low" ]]; then
    _srow "Yama Ptrace Scope"       "kernel.yama.ptrace_scope"  "1 or 2"  "^[12]$"  "^0$"  "0=open, 1=parent only"
else
    _srow "Yama Ptrace Scope"       "kernel.yama.ptrace_scope"  "1 or 2"  "^[12]$"  ""     "0=open, 1=parent only"
fi
# Core Dump Path — three-line renderer
# Line 1: label + short type tag (pipe/path/bare) + want note
# Line 2: full pattern value (can be 80+ chars — never truncated)
# Line 3: handler identification + format-specifier analysis
_cdp_val=$(_sctl "kernel.core_pattern")
if [[ -z "$_cdp_val" ]]; then
    printf " ${C_BOLD}%-34s${C_RESET} ${C_YELLOW}%-6s${C_RESET}  %s\n" "Core Dump Path" "N/A" "kernel.core_pattern"
else
    # Classify: pipe = starts with |, path = starts with /, bare = everything else
    if   [[ "$_cdp_val" == \|* ]]; then _cdp_tag="pipe"
    elif [[ "$_cdp_val" == /*  ]]; then _cdp_tag="path"
    else                                _cdp_tag="bare"; fi
    # Color: pipe or absolute path into /var|/tmp is good; bare "core" is warn; else red
    if   [[ "$_cdp_tag" == "pipe" ]] || [[ "$_cdp_val" =~ /var|/tmp ]]; then _cdp_col="$C_GREEN"
    elif [[ "$_cdp_val" =~ ^core$                                     ]]; then _cdp_col="$C_YELLOW"
    else                                                                        _cdp_col="$C_RED"; fi

    printf " ${C_BOLD}%-34s${C_RESET} ${_cdp_col}%-6s${C_RESET}  ${C_CYAN}%s${C_RESET}\n" \
        "Core Dump Path" "$_cdp_tag" "(want: pipe|/var|/tmp)"
    printf "   ${C_CYAN}↳${C_RESET}  ${_cdp_col}%s${C_RESET}\n" "$_cdp_val"

    # ── Analysis line ─────────────────────────────────────────────────────────
    if [[ "$_cdp_tag" == "pipe" ]]; then
        # Identify the handler binary
        _cdp_bin="${_cdp_val:1}"              # strip leading |
        _cdp_bin="${_cdp_bin%% *}"            # strip arguments
        _cdp_bin=$(basename "$_cdp_bin")      # just the filename
        case "$_cdp_bin" in
            apport)              _cdp_desc="Ubuntu crash reporter" ;;
            systemd-coredump)    _cdp_desc="systemd coredump handler" ;;
            abrt-hook-*)         _cdp_desc="ABRT daemon" ;;
            *)                   _cdp_desc="custom handler" ;;
        esac
        # Parse which security-relevant context the format specifiers capture
        _cdp_caps=()
        [[ "$_cdp_val" =~ %[pP] ]] && _cdp_caps+=("pid")
        [[ "$_cdp_val" =~ %s    ]] && _cdp_caps+=("signal")
        [[ "$_cdp_val" =~ %u    ]] && _cdp_caps+=("uid")
        [[ "$_cdp_val" =~ %g    ]] && _cdp_caps+=("gid")
        [[ "$_cdp_val" =~ %[eE] ]] && _cdp_caps+=("exe")
        [[ "$_cdp_val" =~ %t    ]] && _cdp_caps+=("timestamp")
        [[ "$_cdp_val" =~ %h    ]] && _cdp_caps+=("host")
        _cdp_caps_str=""
        for _c in "${_cdp_caps[@]}"; do
            [[ -n "$_cdp_caps_str" ]] && _cdp_caps_str+=" · "
            _cdp_caps_str+="$_c"
        done
        [[ -z "$_cdp_caps_str" ]] && _cdp_caps_str="${C_YELLOW}none${C_RESET}"
        printf "   ${C_CYAN}↳${C_RESET}  ${C_BOLD}%s${C_RESET}  ${C_CYAN}(%s)${C_RESET}  ${C_CYAN}·${C_RESET}  captures: ${_cdp_col}%s${C_RESET}\n" \
            "$_cdp_bin" "$_cdp_desc" "$_cdp_caps_str"

    elif [[ "$_cdp_tag" == "path" ]]; then
        _cdp_dir=$(dirname "$_cdp_val")
        if [[ -d "$_cdp_dir" ]]; then
            _cdp_dir_note="${C_GREEN}${_cdp_dir} (exists)${C_RESET}"
        else
            _cdp_dir_note="${C_RED}${_cdp_dir} (missing)${C_RESET}"
        fi
        _cdp_caps=()
        [[ "$_cdp_val" =~ %[pP] ]] && _cdp_caps+=("pid")
        [[ "$_cdp_val" =~ %[eE] ]] && _cdp_caps+=("exe")
        [[ "$_cdp_val" =~ %u    ]] && _cdp_caps+=("uid")
        [[ "$_cdp_val" =~ %s    ]] && _cdp_caps+=("signal")
        [[ "$_cdp_val" =~ %t    ]] && _cdp_caps+=("timestamp")
        _cdp_caps_str=""
        for _c in "${_cdp_caps[@]}"; do
            [[ -n "$_cdp_caps_str" ]] && _cdp_caps_str+=" · "
            _cdp_caps_str+="$_c"
        done
        [[ -z "$_cdp_caps_str" ]] && _cdp_caps_str="${C_YELLOW}none${C_RESET}"
        printf "   ${C_CYAN}↳${C_RESET}  path dump  ${C_CYAN}·${C_RESET}  dir: %s  ${C_CYAN}·${C_RESET}  captures: ${_cdp_col}%s${C_RESET}\n" \
            "$_cdp_dir_note" "$_cdp_caps_str"

    else
        # bare — core dumps land in the process CWD
        printf "   ${C_CYAN}↳${C_RESET}  ${C_RED}dumps to process CWD — sensitive data may land in attacker-controlled paths${C_RESET}\n"
    fi
fi
unset _cdp_val _cdp_col _cdp_tag _cdp_bin _cdp_desc _cdp_caps _cdp_caps_str _cdp_dir _cdp_dir_note _c

echo ""
printf " ${C_SECTION}%s${C_RESET}\n" "── Filesystem ──"
_srow "Protected Hardlinks"         "fs.protected_hardlinks"              "1"       "^1$"     ""      "prevent hardlink attacks"
_srow "Protected Symlinks"          "fs.protected_symlinks"               "1"       "^1$"     ""      "prevent symlink attacks"
_srow "Protected FIFOs"             "fs.protected_fifos"                  "1 or 2"  "^[12]$"  ""      ""
_srow "Protected Regular Files"     "fs.protected_regular"                "1 or 2"  "^[12]$"  ""      ""