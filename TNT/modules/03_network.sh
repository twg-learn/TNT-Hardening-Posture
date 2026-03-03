#!/usr/bin/env bash

print_header "Network Interfaces"
print_explain "Enumerates all active network interfaces and services bound to external addresses. Each externally listening port is a potential entry point for attack. This section surfaces services that may be unintentional, misconfigured, or unnecessary, enabling reduction of the network-facing attack surface."
printf "${C_BOLD}${C_CYAN} %-12s | %-8s | %-18s${C_RESET}\n" "Interface" "State" "Primary IP"

ip -br -4 addr show 2>/dev/null | grep -v "lo" | while read -r iface state addr; do
    clean_ip=$(echo "$addr" | awk '{print $1}')
    printf " %-12s | %-8s | %-18s\n" "$iface" "$state" "$clean_ip"
done

print_header "Exposed Listening Services (External Only)"
printf "${C_BOLD}${C_CYAN} %-8s | %-22s | %-20s${C_RESET}\n" "Proto" "Local Address" "Service/PID"

ss -H -tulpn 2>/dev/null | grep LISTEN | grep -vE '127\.0\.0|\[::1\]' | awk '
    {
        prog = "Restricted (Sudo)"
        if ($7 != "") {
            # Use \x22 (Hex for double-quote) to avoid Bash escaping issues
            split($7, a, "\x22") 
            name = a[2]
            
            # Extract PID
            split($7, b, "pid=")
            split(b[2], c, ",")
            pid = c[1]
            
            if (name != "") {
                prog = name " (pid: " pid ")"
            }
        }
        printf " %-8s | %-22s | %-20s\n", $1, $5, prog
    }' || echo " No externally exposed services found."