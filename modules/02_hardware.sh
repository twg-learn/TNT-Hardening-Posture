#!/usr/bin/env bash

print_header "Hardware & Virtualization"
print_explain "Identifies the underlying hardware platform and execution environment. Knowing whether a system runs on bare metal, inside a VM, or within a container determines which hardware-level protections are available and surfaces additional attack surface introduced by the virtualization or container layer."

printf "${C_BOLD}${C_CYAN} %-10s | %-22s | %-12s | %-5s | %-7s | %-7s${C_RESET}\n" \
    "QEMU Agent" "CPU Name" "Architecture" "Cores" "Threads" "RAM"

qemu_stat=$(systemctl is-active qemu-guest-agent 2>/dev/null)
[[ "$qemu_stat" == "active" ]] && q_print="ENABLED" || q_print="DISABLED"
q_col=$(get_color "$q_print" "ENABLED" "N/A")

cpu_name=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs | sed 's/(R)//g;s/(TM)//g' | cut -c1-22)
ram_size=$(free -h | awk '/^Mem:/ {print $2}')

printf " ${q_col}%-10s${C_RESET} | %-22s | %-12s | %-5s | %-7s | %-7s\n" \
    "$q_print" "${cpu_name:-Unknown}" "$(uname -m)" "$(nproc --all)" \
    "$(grep -c "processor" /proc/cpuinfo)" "$ram_size"

# --- Virtualization / Container Context ---
echo ""
printf " ${C_SECTION}%s${C_RESET}\n" "── Environment ──"

if command -v systemd-detect-virt &>/dev/null; then
    virt_type=$(systemd-detect-virt 2>/dev/null)
else
    virt_type="unknown"
fi

case "$virt_type" in
    none)           context="Bare Metal";                ctx_col="$C_GREEN";  threat_note="Physical host — full hardware attack surface" ;;
    kvm|qemu)       context="KVM / QEMU Guest";          ctx_col="$C_CYAN";   threat_note="Hypervisor escape risk; verify host isolation" ;;
    vmware)         context="VMware Guest";               ctx_col="$C_CYAN";   threat_note="Check VMware tools version and snapshot hygiene" ;;
    microsoft)      context="Hyper-V Guest";              ctx_col="$C_CYAN";   threat_note="Integration services exposure" ;;
    xen)            context="Xen Guest";                  ctx_col="$C_CYAN";   threat_note="Para-virtualized — verify PV attack surface" ;;
    lxc|lxc-libvirt) context="LXC Container";            ctx_col="$C_YELLOW"; threat_note="Shares kernel with host — namespace escape risk" ;;
    docker)         context="Docker Container";           ctx_col="$C_YELLOW"; threat_note="Shares host kernel — check capabilities and seccomp" ;;
    podman)         context="Podman Container";           ctx_col="$C_YELLOW"; threat_note="Rootless preferred; verify no --privileged flag" ;;
    systemd-nspawn) context="systemd-nspawn Container";   ctx_col="$C_YELLOW"; threat_note="Lightweight container — limited isolation" ;;
    wsl|wsl2)       context="WSL (Windows Subsystem)";    ctx_col="$C_YELLOW"; threat_note="Bridged to Windows host filesystem" ;;
    *)              context="Unknown / Other ($virt_type)"; ctx_col="$C_YELLOW"; threat_note="Could not determine environment" ;;
esac

printf " ${C_BOLD}%-26s${C_RESET} ${ctx_col}%s${C_RESET}\n" "Environment:"        "$context"
printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Threat Note:"        "$threat_note"

if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "CPU Hypervisor Flag:" "Present (running inside a VM)"
else
    printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n"  "CPU Hypervisor Flag:" "Absent (bare metal likely)"
fi

# Container-specific checks (only active when running inside a container)
if [[ "$virt_type" == "docker" || "$virt_type" == "lxc" || "$virt_type" == "podman" ]] \
    || [[ -f /.dockerenv ]] || grep -qa "docker\|lxc\|kubepods" /proc/1/cgroup 2>/dev/null; then

    printf "\n ${C_BOLD}${C_CYAN}%s${C_RESET}\n" "Container Security Checks:"

    ctr_uid=$(id -u 2>/dev/null)
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "  Running as UID:" \
        "$( [[ "$ctr_uid" -eq 0 ]] \
            && color_val "0 (root — elevated risk)" "n/a" "n/a" \
            || color_val "$ctr_uid (non-root)" "$ctr_uid" "n/a" )"

    if command -v capsh &>/dev/null; then
        caps=$(capsh --print 2>/dev/null | grep "^Current:" | cut -d= -f2)
        cap_count=$(echo "$caps" | tr ',' '\n' | grep -vc "^$")
        cap_count=${cap_count:-0}
        printf " ${C_BOLD}%-26s${C_RESET} %b\n" "  Capabilities:" \
            "$( [[ $cap_count -le 5 ]] \
                && color_val "$cap_count (minimal)" "$cap_count" "n/a" \
                || color_val "$cap_count (elevated)" "n/a" "n/a" )"
        for dangerous_cap in cap_sys_admin cap_net_admin cap_sys_ptrace cap_dac_override cap_setuid; do
            echo "$caps" | grep -qi "$dangerous_cap" && \
                printf "   ${C_RED}⚠ Dangerous capability: %s${C_RESET}\n" "$dangerous_cap"
        done
    fi

    seccomp=$(grep -oP "Seccomp:\s+\K\d+" /proc/1/status 2>/dev/null)
    case "$seccomp" in
        0) seccomp_disp="Disabled"; scc_col="$C_RED" ;;
        1) seccomp_disp="Strict";   scc_col="$C_GREEN" ;;
        2) seccomp_disp="Filtered"; scc_col="$C_GREEN" ;;
        *) seccomp_disp="Unknown";  scc_col="$C_YELLOW" ;;
    esac
    printf " ${C_BOLD}%-26s${C_RESET} ${scc_col}%s${C_RESET}\n" "  Seccomp Profile:" "$seccomp_disp"

    apparmor_prof=$(cat /proc/1/attr/current 2>/dev/null | tr -d '\0')
    if [[ -n "$apparmor_prof" && "$apparmor_prof" != "unconfined" ]]; then
        printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n"  "  AppArmor Profile:" "$apparmor_prof"
    else
        printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "  AppArmor Profile:" "${apparmor_prof:-unconfined}"
    fi
fi

for agent_svc in qemu-guest-agent open-vm-tools vmware-tools xe-daemon; do
    if systemctl is-active --quiet "$agent_svc" 2>/dev/null; then
        printf " ${C_BOLD}%-26s${C_RESET} ${C_CYAN}%s${C_RESET}\n" "Guest Agent:" "$agent_svc (active)"
        break
    fi
done
