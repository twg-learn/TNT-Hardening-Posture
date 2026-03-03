#!/usr/bin/env bash
# posture.sh — Linux Host Security Posture Report
# Usage: sudo bash posture.sh [--config <file>]

BASE_DIR="$(dirname "$(readlink -f "$0")")"

# ─── Argument parsing ─────────────────────────────────────────────────────────
# --config / -c  Load settings from a config file (skips interactive prompts).
# -tc            Force compat (non-True Color) theme for testing.
_TNT_CONFIG_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config|-c) _TNT_CONFIG_FILE="${2:-}"; shift ;;
        -tc)         export TNT_TRUECOLOR=no ;;
    esac
    shift
done

# Config must be sourced and called first so TNT_THEME is set before theme.sh
source "$BASE_DIR/core/config.sh"
source "$BASE_DIR/core/banner.sh"
_prompt_config
_prompt_modules

source "$BASE_DIR/core/theme.sh"
source "$BASE_DIR/core/helpers.sh"
source "$BASE_DIR/core/export.sh"

# ─── Export capture setup ─────────────────────────────────────────────────────
# Raw ANSI output is captured to a temp file; _finalize_export() converts it
# to the chosen format (text / html / pdf) after all modules have run.
_TNT_CAPTURE_FILE=""
if [[ "$TNT_EXPORT" == "yes" ]]; then
    _TNT_CAPTURE_FILE=$(mktemp /tmp/tnt_XXXXXX)
    exec > >(tee "$_TNT_CAPTURE_FILE") 2>&1
    printf "Export queued: %s/%s  [%s]\n" \
        "$TNT_EXPORT_PATH" "$TNT_EXPORT_NAME" "${TNT_EXPORT_TYPE:-text}" >/dev/tty
fi

# ─── Apply theme background and clear screen ─────────────────────────────────
# For dark/light True Color themes: set the background colour before clearing
# so the terminal fills entirely with the theme background.
# For compat: C_BG_ESC is empty so this is a no-op.
[[ -n "$C_BG_ESC" ]] && printf "%s" "$C_BG_ESC"
clear

TIMESTAMP=$(date +'%Y-%m-%d %H:%M')

[[ "${TNT_BANNER:-yes}" != "no" ]] && _draw_banner

# ─── Load modules in numerical order (guarded by TNT_MOD_* selection) ─────────
[[ "${TNT_MOD_IDENTITY:-yes}"       == "yes" ]] && source "$BASE_DIR/modules/01_identity.sh"
[[ "${TNT_MOD_HARDWARE:-yes}"       == "yes" ]] && source "$BASE_DIR/modules/02_hardware.sh"
[[ "${TNT_MOD_NETWORK:-yes}"        == "yes" ]] && source "$BASE_DIR/modules/03_network.sh"
[[ "${TNT_MOD_SSH:-yes}"            == "yes" ]] && source "$BASE_DIR/modules/04_ssh.sh"
[[ "${TNT_MOD_SECURITY:-yes}"       == "yes" ]] && source "$BASE_DIR/modules/05_security.sh"
[[ "${TNT_MOD_ATTACK_SURFACE:-yes}" == "yes" ]] && source "$BASE_DIR/modules/06_attack_surface.sh"
[[ "${TNT_MOD_HW_SECURITY:-yes}"    == "yes" ]] && source "$BASE_DIR/modules/08_hardware_security.sh"
[[ "${TNT_MOD_USERS:-yes}"          == "yes" ]] && source "$BASE_DIR/modules/09_users.sh"
[[ "${TNT_MOD_FILESYSTEM:-yes}"     == "yes" ]] && source "$BASE_DIR/modules/10_filesystem.sh"
[[ "${TNT_MOD_PACKAGES:-yes}"       == "yes" ]] && source "$BASE_DIR/modules/11_packages.sh"
[[ "${TNT_MOD_AUTH_EVENTS:-yes}"    == "yes" ]] && source "$BASE_DIR/modules/12_auth_events.sh"
[[ "${TNT_MOD_SCHEDULED:-yes}"      == "yes" ]] && source "$BASE_DIR/modules/13_scheduled_tasks.sh"
[[ "${TNT_MOD_DOCKER:-yes}"         == "yes" ]] && source "$BASE_DIR/modules/14_docker.sh"
[[ "${TNT_MOD_WEBSERVER:-yes}"      == "yes" ]] && source "$BASE_DIR/modules/15_webserver.sh"
[[ "${TNT_MOD_CPU_VULN:-yes}"       == "yes" ]] && source "$BASE_DIR/modules/16_cpu_vuln.sh"
[[ "${TNT_MOD_KERNEL:-yes}"         == "yes" ]] && source "$BASE_DIR/modules/17_kernel.sh"
[[ "${TNT_MOD_NTP:-yes}"            == "yes" ]] && source "$BASE_DIR/modules/19_ntp.sh"
[[ "${TNT_MOD_SUID:-yes}"           == "yes" ]] && source "$BASE_DIR/modules/20_suid.sh"
[[ "${TNT_MOD_FIM:-yes}"            == "yes" ]] && source "$BASE_DIR/modules/21_fim.sh"
[[ "${TNT_MOD_VPN:-yes}"            == "yes" ]] && source "$BASE_DIR/modules/22_vpn.sh"
[[ "${TNT_MOD_SUSPICIOUS:-yes}"     == "yes" ]] && source "$BASE_DIR/modules/23_suspicious_procs.sh"
[[ "${TNT_MOD_WORLD_WRITABLE:-yes}" == "yes" ]] && source "$BASE_DIR/modules/24_world_writable.sh"

if [[ "${TNT_BANNER:-yes}" != "no" ]]; then
    echo ""
    _draw_banner
fi

# ─── Finalize export ──────────────────────────────────────────────────────────
if [[ "$TNT_EXPORT" == "yes" && -n "$_TNT_CAPTURE_FILE" ]]; then
    exec 1>/dev/tty 2>/dev/tty   # close BOTH write ends of the tee pipe;
    sleep 0.2                    # tee sees EOF and flushes; wait for it to finish
    _finalize_export
    rm -f "$_TNT_CAPTURE_FILE"
fi

# ─── Full terminal reset — restore default colours before returning to shell ──
printf '\033[0m\n'
