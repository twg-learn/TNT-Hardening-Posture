#!/usr/bin/env bash

print_header "Web Server"
print_explain "Web servers are among the most targeted services due to their internet exposure. This section checks for common misconfigurations including unnecessary directory listing, absent security headers, and TLS weaknesses that can expose sensitive content or enable cross-site and injection attacks."

# --- Detection ---
nginx_installed=0; apache_installed=0; caddy_installed=0
command -v nginx   &>/dev/null && nginx_installed=1
command -v apache2 &>/dev/null || command -v httpd &>/dev/null && apache_installed=1
command -v caddy   &>/dev/null && caddy_installed=1

if [[ $nginx_installed -eq 0 && $apache_installed -eq 0 && $caddy_installed -eq 0 ]]; then
    printf " ${C_BOLD}%-28s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "Web Server:" "None detected (nginx/apache/caddy)"
    return
fi

# --- Helper: print a config check result ---
config_check() {
    local label=$1 result=$2 good=$3 warn=$4
    printf "   ${C_BOLD}%-26s${C_RESET} %b\n" "$label" "$(color_val "$result" "$good" "$warn")"
}

# =============================================================================
# NGINX
# =============================================================================
if [[ $nginx_installed -eq 1 ]]; then
    nginx_active=$(systemctl is-active nginx 2>/dev/null)
    nginx_ver=$(nginx -v 2>&1 | grep -oP "[\d]+\.[\d]+\.[\d]+" | head -1)
    nginx_user=$(ps -eo user,comm 2>/dev/null | awk '/nginx/ && !/root/ {print $1; exit}')
    [[ -z "$nginx_user" ]] && nginx_user="root"

    printf " ${C_BOLD}%-28s${C_RESET} %b  (v%s, worker: %s)\n" "Nginx:" \
        "$(color_val "$nginx_active" "active" "n/a")" \
        "${nginx_ver:-unknown}" "${nginx_user}"

    # Locate main config
    for cfg in /etc/nginx/nginx.conf /usr/local/etc/nginx/nginx.conf; do
        [[ -f "$cfg" ]] && nginx_cfg="$cfg" && break
    done

    if [[ -n "$nginx_cfg" ]]; then
        # Flatten config (include all referenced files) for reliable grepping
        nginx_flat=$(nginx -T 2>/dev/null || cat "$nginx_cfg")

        # --- Security header checks ---
        printf "   ${C_BOLD}${C_CYAN}%-26s  %s${C_RESET}\n" "Config Check" "Result"

        # server_tokens
        if echo "$nginx_flat" | grep -qE "^\s*server_tokens\s+off"; then
            config_check "server_tokens:" "off (version hidden)" "off" "n/a"
        else
            config_check "server_tokens:" "on (version exposed)" "n/a" "n/a"
        fi

        # TLS versions — flag if old protocols are present
        if echo "$nginx_flat" | grep -qiE "ssl_protocols.*TLSv1[^.23]|ssl_protocols.*TLSv1\.0|ssl_protocols.*TLSv1\.1"; then
            config_check "TLS versions:" "Legacy TLS 1.0/1.1 enabled" "n/a" "n/a"
        elif echo "$nginx_flat" | grep -qiE "ssl_protocols"; then
            tls_line=$(echo "$nginx_flat" | grep -oiP "ssl_protocols[^;]+" | head -1 | xargs)
            config_check "TLS versions:" "$tls_line" "TLSv1.3|TLSv1.2" "n/a"
        else
            config_check "TLS versions:" "Not configured" "n/a" "Not"
        fi

        # HSTS
        echo "$nginx_flat" | grep -qi "Strict-Transport-Security" \
            && config_check "HSTS header:" "Present" "Present" "n/a" \
            || config_check "HSTS header:" "Absent" "n/a" "n/a"

        # X-Frame-Options
        echo "$nginx_flat" | grep -qi "X-Frame-Options" \
            && config_check "X-Frame-Options:" "Present" "Present" "n/a" \
            || config_check "X-Frame-Options:" "Absent" "n/a" "n/a"

        # X-Content-Type-Options
        echo "$nginx_flat" | grep -qi "X-Content-Type-Options" \
            && config_check "X-Content-Type-Options:" "Present" "Present" "n/a" \
            || config_check "X-Content-Type-Options:" "Absent" "n/a" "n/a"

        # autoindex
        echo "$nginx_flat" | grep -qiE "autoindex\s+on" \
            && config_check "autoindex:" "on — directory listing exposed" "n/a" "n/a" \
            || config_check "autoindex:" "off (safe)" "off" "n/a"

        # client_max_body_size
        body_size=$(echo "$nginx_flat" | grep -oiP "client_max_body_size\s+\K[^;]+" | head -1 | xargs)
        config_check "client_max_body_size:" "${body_size:-default (1m)}" "n/a" "n/a"
    else
        printf "   ${C_YELLOW}%s${C_RESET}\n" "Config not found — skipping checks"
    fi

    # --- Sites ---
    sites_available=$(find /etc/nginx/sites-available/ -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    sites_enabled=$(find /etc/nginx/sites-enabled/   -maxdepth 1 -type l,f 2>/dev/null | wc -l | tr -d ' ')
    conf_d=$(find /etc/nginx/conf.d/ -maxdepth 1 -name "*.conf" 2>/dev/null | wc -l | tr -d ' ')
    printf "   ${C_BOLD}%-26s${C_RESET} %s available, %s enabled, %s in conf.d\n" \
        "Sites:" "$sites_available" "$sites_enabled" "$conf_d"

    # --- TLS certificate expiry check ---
    if echo "$nginx_flat" | grep -q "ssl_certificate "; then
        cert_file=$(echo "$nginx_flat" | grep -oP "ssl_certificate\s+\K[^;]+" | grep -v "key" | head -1 | xargs)
        if [[ -f "$cert_file" ]]; then
            expiry_raw=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
            if [[ -n "$expiry_raw" ]]; then
                expiry_epoch=$(date -d "$expiry_raw" +%s 2>/dev/null)
                now_epoch=$(date +%s)
                days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
                if   [[ $days_left -le 14 ]]; then cert_col="$C_RED"
                elif [[ $days_left -le 30 ]]; then cert_col="$C_YELLOW"
                else cert_col="$C_GREEN"; fi
                printf "   ${C_BOLD}%-26s${C_RESET} ${cert_col}%s days (expires %s)${C_RESET}\n" \
                    "TLS Cert expiry:" "$days_left" "$expiry_raw"
            fi
        fi
    fi

    echo ""
fi

# =============================================================================
# APACHE
# =============================================================================
if [[ $apache_installed -eq 1 ]]; then
    apache_bin=$(command -v apache2 2>/dev/null || command -v httpd 2>/dev/null)
    apache_svc=$(systemctl is-active apache2 2>/dev/null || systemctl is-active httpd 2>/dev/null)
    apache_ver=$("$apache_bin" -v 2>/dev/null | grep -oP "Apache/\K[\d.]+" | head -1)
    apache_user=$(ps -eo user,comm 2>/dev/null | grep -E "apache2|httpd" | awk '!/root/ {print $1; exit}')
    [[ -z "$apache_user" ]] && apache_user="root"

    printf " ${C_BOLD}%-28s${C_RESET} %b  (v%s, worker: %s)\n" "Apache:" \
        "$(color_val "$apache_svc" "active" "n/a")" \
        "${apache_ver:-unknown}" "${apache_user}"

    # Locate config root
    for cfg in /etc/apache2/apache2.conf /etc/httpd/conf/httpd.conf; do
        [[ -f "$cfg" ]] && apache_cfg="$cfg" && break
    done

    if [[ -n "$apache_cfg" ]]; then
        apache_flat=$(grep -rh "" "$(dirname "$apache_cfg")" 2>/dev/null)

        printf "   ${C_BOLD}${C_CYAN}%-26s  %s${C_RESET}\n" "Config Check" "Result"

        # ServerTokens
        if echo "$apache_flat" | grep -qiE "ServerTokens\s+Prod"; then
            config_check "ServerTokens:" "Prod (version hidden)" "Prod" "n/a"
        else
            stok=$(echo "$apache_flat" | grep -oiP "ServerTokens\s+\K\S+" | head -1)
            config_check "ServerTokens:" "${stok:-default (Full)}" "Prod" "n/a"
        fi

        # ServerSignature
        if echo "$apache_flat" | grep -qiE "ServerSignature\s+Off"; then
            config_check "ServerSignature:" "Off" "Off" "n/a"
        else
            ssig=$(echo "$apache_flat" | grep -oiP "ServerSignature\s+\K\S+" | head -1)
            config_check "ServerSignature:" "${ssig:-default (On)}" "Off" "n/a"
        fi

        # mod_security
        echo "$apache_flat" | grep -qiE "mod_security|security2" \
            && config_check "ModSecurity:" "Loaded" "Loaded" "n/a" \
            || config_check "ModSecurity:" "Not loaded" "n/a" "n/a"

        # Options Indexes (directory listing)
        echo "$apache_flat" | grep -qiE "Options.*Indexes" \
            && config_check "Directory listing:" "Indexes enabled — exposed" "n/a" "n/a" \
            || config_check "Directory listing:" "Disabled (safe)" "Disabled" "n/a"

        # TRACE method
        echo "$apache_flat" | grep -qiE "TraceEnable\s+Off" \
            && config_check "TraceEnable:" "Off" "Off" "n/a" \
            || config_check "TraceEnable:" "On (default — XST risk)" "Off" "n/a"
    fi

    # Sites
    sites_enabled=$(find /etc/apache2/sites-enabled/ -maxdepth 1 -type l,f 2>/dev/null | wc -l | tr -d ' ')
    sites_available=$(find /etc/apache2/sites-available/ -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    printf "   ${C_BOLD}%-26s${C_RESET} %s available, %s enabled\n" \
        "Virtual Hosts:" "$sites_available" "$sites_enabled"

    echo ""
fi

# =============================================================================
# CADDY
# =============================================================================
if [[ $caddy_installed -eq 1 ]]; then
    caddy_active=$(systemctl is-active caddy 2>/dev/null)
    caddy_ver=$(caddy version 2>/dev/null | grep -oP "v[\d.]+" | head -1)

    printf " ${C_BOLD}%-28s${C_RESET} %b  (%s)\n" "Caddy:" \
        "$(color_val "$caddy_active" "active" "n/a")" \
        "${caddy_ver:-unknown version}"

    for cfile in /etc/caddy/Caddyfile /usr/local/etc/caddy/Caddyfile; do
        [[ -f "$cfile" ]] && caddy_cfg="$cfile" && break
    done

    if [[ -n "$caddy_cfg" ]]; then
        site_count=$(grep -cE "^\S+.*\{" "$caddy_cfg" 2>/dev/null); site_count=${site_count:-0}
        printf "   ${C_BOLD}%-26s${C_RESET} %s  (%s)\n" "Caddyfile:" "$caddy_cfg" "$site_count site block(s)"
        # Caddy handles TLS/HTTPS automatically — note this
        printf "   ${C_BOLD}%-26s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Automatic HTTPS:" "Managed by Caddy"
    else
        printf "   ${C_YELLOW}%s${C_RESET}\n" "Caddyfile not found"
    fi

    echo ""
fi

# =============================================================================
# LISTENING PORTS (80, 443 and common alternates)
# =============================================================================
web_ports=$(ss -H -tlpn 2>/dev/null | awk '$4 ~ /:80$|:443$|:8080$|:8443$|:3000$|:8000$/' )
if [[ -n "$web_ports" ]]; then
    printf " ${C_BOLD}${C_CYAN}%-8s  %-22s  %s${C_RESET}\n" "Proto" "Address" "Service"
    echo "$web_ports" | awk '{
        split($7, a, "\""); name=a[2]
        split($7, b, "pid="); split(b[2], c, ","); pid=c[1]
        prog = (name != "") ? name " (pid:" pid ")" : "unknown"
        printf " %-8s  %-22s  %s\n", $1, $4, prog
    }'
fi