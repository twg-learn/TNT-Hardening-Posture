#!/usr/bin/env bash

print_header "Docker"
print_explain "Container security depends heavily on daemon configuration and runtime options. Privileged containers, host network mode, and exposed Docker sockets can all allow container escape to the underlying host. This section audits Docker daemon settings and active container security options."

# --- Check if Docker is installed ---
if ! command -v docker &>/dev/null; then
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Docker:" "Not installed"
    return
fi

# --- Daemon running? ---
docker_active=$(systemctl is-active docker 2>/dev/null)
printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Docker Daemon:" "$(color_val "$docker_active" "active" "n/a")"

if [[ "$docker_active" != "active" ]]; then
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Note:" "Daemon inactive — skipping container checks"
    return
fi

docker_version=$(docker --version 2>/dev/null | grep -oP "[\d]+\.[\d]+\.[\d]+" | head -1)
printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Version:" "${docker_version:-unknown}"

# --- Rootless mode ---
docker_info=$(docker info 2>/dev/null)
rootless=$(echo "$docker_info" | grep -c "rootless")
rootless=${rootless:-0}
[[ $rootless -gt 0 ]] && rootless_disp="Yes (Rootless mode)" || rootless_disp="No (Running as root)"
printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Rootless Mode:" "$(color_val "$rootless_disp" "Yes" "n/a")"

# --- Socket permissions ---
sock="/var/run/docker.sock"
if [[ -S "$sock" ]]; then
    sock_mode=$(stat -c "%a" "$sock" 2>/dev/null)
    sock_owner=$(stat -c "%U:%G" "$sock" 2>/dev/null)
    [[ "$sock_mode" == "660" || "$sock_mode" == "600" ]] \
        && sock_disp="$sock_mode ($sock_owner)" \
        || sock_disp="$sock_mode ($sock_owner) — world-accessible"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Socket ($sock):" \
        "$(color_val "$sock_disp" "660|600" "n/a")"
fi

# --- Container counts ---
running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
total=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
stopped=$(( total - running ))
images=$(docker images -q 2>/dev/null | wc -l | tr -d ' ')

printf " ${C_BOLD}%-26s${C_RESET} %b running, %s stopped, %s total\n" "Containers:" \
    "$(color_val "$running" "^0$" "n/a")" "$stopped" "$total"
printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Images:" "$images"

# --- Security checks (only if containers are running) ---
if [[ $running -gt 0 ]]; then

    # Privileged containers
    priv_count=$(docker ps -q 2>/dev/null \
        | xargs -r docker inspect --format '{{.Name}} {{.HostConfig.Privileged}}' 2>/dev/null \
        | grep -c "true")
    priv_count=${priv_count:-0}
    [[ $priv_count -eq 0 ]] && priv_disp="None" || priv_disp="$priv_count container(s)"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Privileged Containers:" "$(color_val "$priv_disp" "None" "n/a")"

    # Containers running as root (uid 0)
    root_containers=$(docker ps -q 2>/dev/null \
        | xargs -r docker inspect --format '{{.Name}} {{.Config.User}}' 2>/dev/null \
        | awk '$2=="" || $2=="0" || $2=="root" {count++} END {print count+0}')
    root_containers=${root_containers:-0}
    [[ $root_containers -eq 0 ]] && rc_disp="None" || rc_disp="$root_containers container(s)"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Running as Root (uid 0):" "$(color_val "$rc_disp" "None" "n/a")"

    # Host network mode
    host_net=$(docker ps -q 2>/dev/null \
        | xargs -r docker inspect --format '{{.Name}} {{.HostConfig.NetworkMode}}' 2>/dev/null \
        | grep -c "host")
    host_net=${host_net:-0}
    [[ $host_net -eq 0 ]] && hnet_disp="None" || hnet_disp="$host_net container(s)"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Host Network Mode:" "$(color_val "$hnet_disp" "None" "n/a")"

    # Host PID namespace
    host_pid=$(docker ps -q 2>/dev/null \
        | xargs -r docker inspect --format '{{.Name}} {{.HostConfig.PidMode}}' 2>/dev/null \
        | grep -c "host")
    host_pid=${host_pid:-0}
    [[ $host_pid -eq 0 ]] && hpid_disp="None" || hpid_disp="$host_pid container(s)"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Host PID Namespace:" "$(color_val "$hpid_disp" "None" "n/a")"

    # Exposed ports summary
    port_count=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -vc "^$")
    port_count=${port_count:-0}
    printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Containers w/ Exposed Ports:" "$port_count"

    # --- Running container table ---
    printf "\n ${C_BOLD}${C_CYAN}%-20s  %-12s  %-10s  %s${C_RESET}\n" "Name" "Image" "Status" "Ports"
    docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
        | while IFS=$'\t' read -r name image status ports; do
            name="${name#/}"
            image=$(echo "$image" | cut -c1-12)
            status=$(echo "$status" | cut -c1-10)
            ports=$(echo "$ports" | sed 's/0\.0\.0\.0://g' | cut -c1-30)
            printf " %-20s  %-12s  %-10s  %s\n" "$name" "$image" "$status" "${ports:--}"
        done
fi

# --- Daemon hardening (daemon.json) ---
daemon_cfg="/etc/docker/daemon.json"
if [[ -f "$daemon_cfg" ]]; then
    userns=$(grep -c "userns-remap" "$daemon_cfg" 2>/dev/null); userns=${userns:-0}
    no_new_priv=$(grep -c "no-new-privileges" "$daemon_cfg" 2>/dev/null); no_new_priv=${no_new_priv:-0}
    live_restore=$(grep -c "live-restore" "$daemon_cfg" 2>/dev/null); live_restore=${live_restore:-0}

    printf "\n ${C_BOLD}${C_CYAN}%s${C_RESET}\n" "Daemon Config (daemon.json):"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "  User NS Remapping:" \
        "$( [[ $userns -gt 0 ]] && color_val "Enabled" "Enabled" "n/a" || color_val "Disabled" "n/a" "n/a" )"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "  No-New-Privileges:" \
        "$( [[ $no_new_priv -gt 0 ]] && color_val "Enabled" "Enabled" "n/a" || color_val "Disabled" "n/a" "n/a" )"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "  Live Restore:" \
        "$( [[ $live_restore -gt 0 ]] && color_val "Enabled" "Enabled" "n/a" || color_val "Disabled" "n/a" "n/a" )"
else
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Daemon Config:" "No daemon.json found (all defaults)"
fi