#!/usr/bin/env bash

print_header "VPN Assessment"
print_explain "VPN software encrypts traffic and masks the system's network origin, which is especially important on untrusted or internet-facing networks. This section detects installed VPN clients and daemons, checks their active status, and audits key security metrics including cipher strength, kill switch presence, tunnel mode, and DNS/IPv6 leak exposure."

vpn_found=0

# Section sub-header helper
_vpn_svc() { printf "\n ${C_SECTION}── %s ──${C_RESET}\n" "$1"; }

# ── WireGuard ──────────────────────────────────────────────────────────────────
_wg_ifaces=$(ip link show 2>/dev/null | grep -oP "(?<=\d: )(wg\w+|nordlynx)(?=:)" | tr '\n' ' ' | xargs)

if command -v wg &>/dev/null || command -v wg-quick &>/dev/null || [[ -n "$_wg_ifaces" ]]; then
    vpn_found=1
    _vpn_svc "WireGuard"

    wg_ver=$(wg --version 2>/dev/null | grep -oP "[\d.]+" | head -1)
    [[ -n "$wg_ver" ]] && printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Version:" "$wg_ver"

    # Active systemd instances
    wg_units=$(systemctl list-units --state=active --no-legend 'wg-quick@*.service' 2>/dev/null \
        | awk '{print $1}' | tr '\n' ' ' | xargs)
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Interfaces:" \
        "$( [[ -n "$_wg_ifaces" ]] \
            && color_val "$_wg_ifaces" "wg|nordlynx" "n/a" \
            || color_val "None active" "n/a" "None" )"

    # Per-interface detail (requires root for wg show)
    if command -v wg &>/dev/null && [[ -n "$_wg_ifaces" ]]; then
        for iface in $_wg_ifaces; do
            wg_out=$(wg show "$iface" 2>/dev/null)
            [[ -z "$wg_out" ]] && continue

            peers=$(echo "$wg_out" | grep -c "^peer:")
            endpoint=$(echo "$wg_out" | grep "endpoint:" | head -1 | awk '{print $2}')
            latest_hs=$(echo "$wg_out" | grep "latest handshake:" | head -1 \
                | sed 's/.*latest handshake: //')
            transfer=$(echo "$wg_out" | grep "transfer:" | head -1 | sed 's/.*transfer: //')
            allowed=$(echo "$wg_out" | grep "allowed ips:" | head -1 | awk '{$1=$2=""; print $0}' | xargs)

            printf " ${C_BOLD}  [%s] %-20s${C_RESET} %s peer(s)\n" "$iface" "" "$peers"
            [[ -n "$endpoint"  ]] && printf "   ${C_BOLD}%-24s${C_RESET} %s\n"  "Endpoint:"      "$endpoint"
            [[ -n "$latest_hs" ]] && printf "   ${C_BOLD}%-24s${C_RESET} %b\n"  "Last Handshake:" \
                "$(color_val "$latest_hs" "second|minute" "hour")"
            [[ -n "$transfer"  ]] && printf "   ${C_BOLD}%-24s${C_RESET} %s\n"  "Transfer:"      "$transfer"

            if echo "$allowed" | grep -qE "0\.0\.0\.0/0|::/0"; then
                printf "   ${C_BOLD}%-24s${C_RESET} ${C_GREEN}%s${C_RESET}\n" \
                    "Tunnel Mode:" "Full tunnel (0.0.0.0/0)"
            else
                printf "   ${C_BOLD}%-24s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" \
                    "Tunnel Mode:" "Split tunnel (${allowed:-unknown allowed IPs})"
            fi
        done
    fi

    # Kill switch — look for nftables/iptables rules locking to WireGuard
    _wg_ks=0
    nft list ruleset 2>/dev/null | grep -qiE "wg|wireguard" && _wg_ks=1
    iptables -L 2>/dev/null | grep -qiE "wg|wireguard"      && _wg_ks=1
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Kill Switch (fw rules):" \
        "$( [[ $_wg_ks -eq 1 ]] \
            && color_val "Detected" "Detected" "n/a" \
            || color_val "Not detected" "n/a" "Not" )"
fi

# ── OpenVPN ────────────────────────────────────────────────────────────────────
if command -v openvpn &>/dev/null || \
   systemctl list-unit-files --no-legend 2>/dev/null | grep -qE "^openvpn"; then
    vpn_found=1
    _vpn_svc "OpenVPN"

    ovpn_ver=$(openvpn --version 2>/dev/null | head -1 | grep -oP "OpenVPN \K[\d.]+")
    [[ -n "$ovpn_ver" ]] && printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Version:" "$ovpn_ver"

    # Service status (plain or instanced)
    ovpn_active=$(systemctl is-active openvpn 2>/dev/null)
    if [[ "$ovpn_active" != "active" ]]; then
        ovpn_active=$(systemctl list-units --state=active --no-legend 'openvpn@*.service' \
            2>/dev/null | head -1 | awk '{print "active (" $1 ")"}')
    fi
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Service:" \
        "$(color_val "${ovpn_active:-inactive}" "active" "n/a")"

    # TUN/TAP interfaces
    _tun=$(ip link show 2>/dev/null | grep -oP "(?<=\d: )(tun|tap)\w*(?=:)" | tr '\n' ' ' | xargs)
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "TUN/TAP Interfaces:" \
        "$( [[ -n "$_tun" ]] \
            && color_val "$_tun" "tun|tap" "n/a" \
            || color_val "None" "n/a" "None" )"

    # Config audit — first .conf or .ovpn found
    ovpn_conf=""
    for _d in /etc/openvpn /etc/openvpn/client /etc/openvpn/server; do
        _f=$(find "$_d" -maxdepth 1 \( -name "*.conf" -o -name "*.ovpn" \) 2>/dev/null | head -1)
        [[ -n "$_f" ]] && ovpn_conf="$_f" && break
    done

    if [[ -n "$ovpn_conf" ]]; then
        printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Config:" "$ovpn_conf"
        _cipher=$(grep -iE "^cipher|^data-ciphers" "$ovpn_conf" 2>/dev/null | head -1 | cut -d' ' -f2-)
        _auth=$(grep -i "^auth " "$ovpn_conf" 2>/dev/null | awk '{print $2}')
        _tlsmin=$(grep -i "tls-version-min" "$ovpn_conf" 2>/dev/null | awk '{print $2}')
        _comp=$(grep -iE "^comp-lzo|^compress" "$ovpn_conf" 2>/dev/null | head -1)

        [[ -n "$_cipher" ]] && printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Cipher:" \
            "$(color_val "$_cipher" "AES-256|CHACHA20" "AES-128")"
        [[ -n "$_auth" ]] && printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Auth Digest:" \
            "$(color_val "$_auth" "SHA256|SHA384|SHA512" "SHA1")"
        [[ -n "$_tlsmin" ]] && printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Min TLS Version:" \
            "$(color_val "$_tlsmin" "1\.2|1\.3" "1\.1")"
        [[ -n "$_comp" ]] && printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" \
            "Compression:" "$_comp  (VORACLE attack risk)"
    fi
fi

# ── strongSwan / IPsec ─────────────────────────────────────────────────────────
if command -v ipsec &>/dev/null || command -v swanctl &>/dev/null || \
   systemctl list-unit-files --no-legend 2>/dev/null | grep -qE "^(strongswan|ipsec)"; then
    vpn_found=1
    _vpn_svc "strongSwan / IPsec"

    ss_active="inactive"
    for _s in strongswan strongswan-starter ipsec; do
        _st=$(systemctl is-active "$_s" 2>/dev/null)
        [[ "$_st" == "active" ]] && ss_active="active ($s)" && break
    done
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Service:" \
        "$(color_val "${ss_active}" "active" "n/a")"

    if [[ "$ss_active" == active* ]]; then
        if command -v swanctl &>/dev/null; then
            _sas=$(swanctl --list-sas 2>/dev/null | grep -c "ESTABLISHED")
            printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Established SAs:" \
                "$( [[ ${_sas:-0} -gt 0 ]] \
                    && color_val "${_sas} established" "established" "n/a" \
                    || color_val "None" "n/a" "None" )"
        elif command -v ipsec &>/dev/null; then
            _sas=$(ipsec status 2>/dev/null | grep -c "ESTABLISHED")
            printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Established SAs:" "${_sas:-0}"
        fi
    fi
fi

# ── Tailscale ──────────────────────────────────────────────────────────────────
if command -v tailscale &>/dev/null || \
   systemctl list-unit-files --no-legend 2>/dev/null | grep -q "^tailscaled"; then
    vpn_found=1
    _vpn_svc "Tailscale"

    ts_active=$(systemctl is-active tailscaled 2>/dev/null)
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Daemon:" \
        "$(color_val "${ts_active:-inactive}" "active" "n/a")"

    if [[ "$ts_active" == "active" ]] && command -v tailscale &>/dev/null; then
        ts_ip=$(tailscale ip 2>/dev/null | head -1)
        ts_status_raw=$(tailscale status 2>/dev/null)
        ts_peers=$(echo "$ts_status_raw" | grep -cE "^\s*100\.")

        [[ -n "$ts_ip" ]] && printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Tailscale IP:" "$ts_ip"
        printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Known Peers:" "${ts_peers:-0}"

        # Exit node
        ts_exit=$(echo "$ts_status_raw" | grep -i "exit node" | head -1)
        if [[ -n "$ts_exit" ]]; then
            printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Exit Node:" "$ts_exit"
        else
            printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Exit Node:" "Not in use"
        fi

        # MagicDNS via JSON
        if command -v jq &>/dev/null; then
            ts_mdns=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix // empty')
            if [[ -n "$ts_mdns" ]]; then
                printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "MagicDNS:" "Enabled ($ts_mdns)"
            else
                printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "MagicDNS:" "Disabled"
            fi
        fi
    fi
fi

# ── Commercial VPN clients ─────────────────────────────────────────────────────
# [ "Display Name" "binary" "systemd service" ]
_cvpns=(
    "NordVPN      nordvpn    nordvpnd"
    "Mullvad      mullvad    mullvad-daemon"
    "ProtonVPN    protonvpn-cli  protonvpn"
    "ExpressVPN   expressvpn    expressvpnd"
)

for _entry in "${_cvpns[@]}"; do
    read -r _cname _ccmd _csvc <<< "$_entry"
    if command -v "$_ccmd" &>/dev/null || \
       systemctl list-unit-files --no-legend 2>/dev/null | grep -q "^${_csvc}"; then
        vpn_found=1
        _vpn_svc "$_cname"
        _cstatus=$(systemctl is-active "$_csvc" 2>/dev/null)
        printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Daemon:" \
            "$(color_val "${_cstatus:-inactive}" "active" "n/a")"

        if [[ "${_cstatus}" == "active" ]] && command -v "$_ccmd" &>/dev/null; then
            case "$_cname" in
                NordVPN)
                    _cs=$(nordvpn status 2>/dev/null | grep -E "Status:|Server:|IP:" | head -3)
                    [[ -n "$_cs" ]] && while IFS= read -r _l; do
                        printf "   ${C_CYAN}%s${C_RESET}\n" "$_l"
                    done <<< "$_cs"
                    _ks=$(nordvpn settings 2>/dev/null | grep -i "Kill Switch" | awk '{print $NF}')
                    [[ -n "$_ks" ]] && printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Kill Switch:" \
                        "$(color_val "$_ks" "enabled" "disabled")"
                    ;;
                Mullvad)
                    _cs=$(mullvad status 2>/dev/null | head -2)
                    [[ -n "$_cs" ]] && printf "   ${C_CYAN}%s${C_RESET}\n" "$_cs"
                    _lk=$(mullvad lockdown-mode get 2>/dev/null)
                    [[ -n "$_lk" ]] && printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Lockdown Mode:" \
                        "$(color_val "$_lk" "on" "off")"
                    ;;
                ProtonVPN)
                    _cs=$(protonvpn-cli status 2>/dev/null | head -3)
                    [[ -n "$_cs" ]] && while IFS= read -r _l; do
                        printf "   ${C_CYAN}%s${C_RESET}\n" "$_l"
                    done <<< "$_cs"
                    ;;
            esac
        fi
    fi
done

# ── OpenConnect ────────────────────────────────────────────────────────────────
if command -v openconnect &>/dev/null; then
    vpn_found=1
    _vpn_svc "OpenConnect (Cisco/Juniper/Palo Alto)"
    _ocver=$(openconnect --version 2>/dev/null | head -1 | grep -oP "[\d.]+" | head -1)
    _ocsess=$(pgrep -x openconnect &>/dev/null && echo "active" || echo "inactive")
    printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Version:" "${_ocver:-unknown}"
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Session:" \
        "$(color_val "$_ocsess" "active" "n/a")"
fi

# ── tinc ───────────────────────────────────────────────────────────────────────
if command -v tincd &>/dev/null; then
    vpn_found=1
    _vpn_svc "tinc"
    _tinc_active=$(pgrep -x tincd &>/dev/null && echo "active" || echo "inactive")
    printf " ${C_BOLD}%-26s${C_RESET} %b\n" "Daemon:" \
        "$(color_val "${_tinc_active}" "active" "n/a")"
fi

# ── Network Interface Overview ─────────────────────────────────────────────────
echo ""
printf " ${C_SECTION}%s${C_RESET}\n" "── Network Interface Overview ──"

_vpn_iface_pat="wg[0-9]|nordlynx|tun[0-9]|tap[0-9]|ipsec[0-9]|ts[0-9]|proton[0-9]|utun[0-9]"
_vpn_ifaces=$(ip link show 2>/dev/null \
    | grep -oP "(?<=\d: )(${_vpn_iface_pat})(?=:)" \
    | sort -u | tr '\n' ' ' | xargs)

if [[ -n "$_vpn_ifaces" ]]; then
    printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "VPN-like interfaces:" "$_vpn_ifaces"
else
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "VPN-like interfaces:" "None detected"
fi

# ── DNS Configuration ──────────────────────────────────────────────────────────
echo ""
printf " ${C_SECTION}%s${C_RESET}\n" "── DNS Configuration ──"

_ns=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | xargs)
if [[ -n "$_ns" ]]; then
    _leak=0
    for _n in $_ns; do
        echo "$_n" | grep -qE "^8\.8\.|^1\.1\.1\.|^1\.0\.0\.|^9\.9\.9\.|^208\.67\." && _leak=1
    done
    if [[ $_leak -eq 1 ]]; then
        printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "DNS Servers:" \
            "$_ns  (public resolver — may leak queries outside VPN tunnel)"
    else
        printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "DNS Servers:" "$_ns"
    fi
fi

# systemd-resolved upstream servers
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    _rdns=$(resolvectl status 2>/dev/null \
        | awk '/DNS Servers/{found=1} found{print}' \
        | grep -oP "\d+\.\d+\.\d+\.\d+" | head -3 | tr '\n' ' ' | xargs)
    [[ -n "$_rdns" ]] && printf " ${C_BOLD}%-26s${C_RESET} %s\n" "Resolved upstream DNS:" "$_rdns"
fi

# ── IPv6 Leak Check ────────────────────────────────────────────────────────────
_ip6_global=$(ip -6 addr show 2>/dev/null | grep "scope global" | grep -cv "::1")
if [[ ${_ip6_global:-0} -gt 0 ]]; then
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "IPv6 Leak Risk:" \
        "${_ip6_global} interface(s) with global IPv6 addresses — may bypass VPN tunnel"
else
    printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "IPv6 Leak Risk:" \
        "No global IPv6 addresses detected"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
if [[ $vpn_found -eq 0 ]]; then
    printf " ${C_BOLD}%-26s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "VPN Status:" \
        "No VPN software detected — traffic unencrypted at network layer"
else
    printf " ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "VPN Status:" \
        "VPN software present on this system"
fi
