#!/usr/bin/env bash
# core/banner.sh — TNT app banner: logo + title + optional timestamp
#
# Provides:
#   _grad str r1 g1 b1 r2 g2 b2  — 24-bit foreground gradient across a string
#   _draw_banner [fd] [seps] [ts]
#     fd   — output file descriptor (default: 1 = stdout for reports)
#             pass 3 to write to /dev/tty when drawing inside menus
#     seps — yes|no  draw separator lines above and below (default: yes)
#     ts   — yes|no  show timestamp line (default: yes)
#
# Auto-detects rendering context on each call:
#   Full-theme — draw_line() exists and C_RESET is set (theme.sh already sourced)
#                Uses 24-bit gradient art + themed background escape codes.
#   Menu       — theme.sh not yet sourced; uses _UI_* vars set by config.sh,
#                dark-theme gradient defaults for TC, ANSI-16 otherwise.

# ── Gradient helper (True Color only) ─────────────────────────────────────────
# Interpolates 24-bit foreground colour character-by-character across a string.
# Uses C_BG_ESC / C_RESET when available (full-theme); falls back gracefully.
_grad() {
    local s="$1" r1=$2 g1=$3 b1=$4 r2=$5 g2=$6 b2=$7
    local n=${#s} i r g b
    (( n == 0 )) && return
    local _rst="${C_RESET:-${_UI_RST:-$'\033[0m'}}"
    # Seed the buffer with the background escape (empty in compat/menu context).
    local _ESC=$'\033[' _buf="${C_BG_ESC:-}"
    for (( i=0; i<n; i++ )); do
        if (( n > 1 )); then
            r=$(( r1 + (r2-r1)*i/(n-1) ))
            g=$(( g1 + (g2-g1)*i/(n-1) ))
            b=$(( b1 + (b2-b1)*i/(n-1) ))
        else
            r=$r1; g=$g1; b=$b1
        fi
        _buf+="${_ESC}1;38;2;${r};${g};${b}m${s:$i:1}"
    done
    printf "%s%s" "$_buf" "$_rst"
}

# ── App banner ─────────────────────────────────────────────────────────────────
# All output is grouped into { } >&$_fd so every printf and draw_line call
# automatically targets the correct file descriptor without per-line redirects.
_draw_banner() {
    local _fd="${1:-1}"
    local _seps="${2:-yes}"
    local _ts="${3:-yes}"

    # Width: use WIDTH if already set by theme.sh, else detect locally
    local _bw="${WIDTH:-$(tput cols 2>/dev/null || echo 80)}"
    [[ $_bw -gt 100 ]] && _bw=100

    local _ap=$(( (_bw - 25) / 2 ))   # art pad       (art = 25 chars wide)
    local _sp=$(( (_bw - 33) / 2 ))   # subtitle pad  ("Linux Host Security Posture Audit" = 33 chars)
    local _tp=$(( _bw - 16 ))          # timestamp     (YYYY-MM-DD HH:MM = 16 chars, right-aligned)

    # Full-theme mode: theme.sh has been sourced (draw_line + C_RESET available)
    local _full=0
    declare -f draw_line > /dev/null 2>&1 && [[ -n "${C_RESET:-}" ]] && _full=1

    # Timestamp string: use global TIMESTAMP if already set (report context keeps
    # top/bottom banners in sync), otherwise get a fresh reading.
    local _ts_str
    [[ "$_ts" == "yes" ]] && _ts_str="${TIMESTAMP:-$(date +'%Y-%m-%d %H:%M')}"

    # ── Separator helper ────────────────────────────────────────────────────────
    # In full-theme mode delegates to draw_line (themed gradient + background).
    # In menu mode (theme.sh not yet sourced) draws its own gradient/flat line
    # using _bw and _UI_* vars from _draw_banner's local scope (dynamic scoping).
    _banner_sep() {
        if (( _full )); then
            draw_line "="
        elif [[ "$TNT_TRUECOLOR" == "yes" ]]; then
            local _si _sr _sg _ESC=$'\033[' _buf=""
            for (( _si=1; _si<=_bw; _si++ )); do
                _sr=$(( 20  + 60*_si/_bw ))
                _sg=$(( 210 - 80*_si/_bw ))
                _buf+="${_ESC}38;2;${_sr};${_sg};255m="
            done
            printf "%s%s\n" "$_buf" "${_UI_RST:-$'\033[0m'}"
        else
            local _line
            printf -v _line "%*s" "$_bw" ""
            printf "%s%s%s\n" "${_UI_SEL:-$'\033[1;36m'}" "${_line// /=}" "${_UI_RST:-$'\033[0m'}"
        fi
    }

    {
        # ── Top separator ───────────────────────────────────────────────────────
        if [[ "$_seps" == "yes" ]]; then
            _banner_sep
            printf "\n"
        fi

        # ── Art + subtitle + timestamp ──────────────────────────────────────────
        if [[ "$TNT_TRUECOLOR" == "yes" ]]; then

            # True Color gradient art.
            # Light theme gets its own cooler palette; dark + menu share the
            # warm yellow→red gradient (C_BG_ESC is empty in menu mode so _grad
            # simply skips the background step — looks right on any terminal bg).
            if (( _full )) && [[ "${TNT_THEME:-dark}" == "light" ]]; then
                printf "%*s" $_ap ""; _grad " _______  _   _  _______ "  160 130  10  160 100   0; printf "\n"
                printf "%*s" $_ap ""; _grad "|__   __|| \\ | ||__   __|"  160 100   0  150  70   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   | |   |  \\| |   | |   "  140  55   0  120  30   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   | |   | |\\  |   | |   "  110  20   0   90   0   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   |_|   |_| \\_|   |_|   "   80   0   0   60   0   0; printf "\n"
                printf "\n"
                printf "%*s" $_sp ""; _grad "Linux Host Security Posture Audit"   0 100 160  120  40 180; printf "\n"
                if [[ "$_ts" == "yes" ]]; then
                    printf "%s\033[38;2;140;90;0m%*s%s%s\n" \
                        "$C_BG_ESC" $_tp "" "$_ts_str" "$C_RESET"
                fi
            elif (( _full )) && [[ -n "${THEME_BANNER_R1:-}" ]]; then
                # Theme-defined subtitle gradient (e.g. vampire)
                printf "%*s" $_ap ""; _grad " _______  _   _  _______ "  255 255 200  255 235  60; printf "\n"
                printf "%*s" $_ap ""; _grad "|__   __|| \\ | ||__   __|"  255 220  40  255 165   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   | |   |  \\| |   | |   "  255 150   0  240  90   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   | |   | |\\  |   | |   "  220  70   0  185  30   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   |_|   |_| \\_|   |_|   "  170  20   0  110   0   0; printf "\n"
                printf "\n"
                printf "%*s" $_sp ""; _grad "Linux Host Security Posture Audit" \
                    "$THEME_BANNER_R1" "$THEME_BANNER_G1" "$THEME_BANNER_B1" \
                    "$THEME_BANNER_R2" "$THEME_BANNER_G2" "$THEME_BANNER_B2"; printf "\n"
                if [[ "$_ts" == "yes" ]]; then
                    local _bgc="${C_BG_ESC:-}" _rc="${C_RESET:-${_UI_RST:-$'\033[0m'}}"
                    printf "%s\033[38;2;255;175;40m%*s%s%s\n" "$_bgc" $_tp "" "$_ts_str" "$_rc"
                fi
            else
                # Dark theme (report) or any TC menu (no C_BG_ESC → no background fill)
                printf "%*s" $_ap ""; _grad " _______  _   _  _______ "  255 255 200  255 235  60; printf "\n"
                printf "%*s" $_ap ""; _grad "|__   __|| \\ | ||__   __|"  255 220  40  255 165   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   | |   |  \\| |   | |   "  255 150   0  240  90   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   | |   | |\\  |   | |   "  220  70   0  185  30   0; printf "\n"
                printf "%*s" $_ap ""; _grad "   |_|   |_| \\_|   |_|   "  170  20   0  110   0   0; printf "\n"
                printf "\n"
                printf "%*s" $_sp ""; _grad "Linux Host Security Posture Audit"    0 215 255  185  80 255; printf "\n"
                if [[ "$_ts" == "yes" ]]; then
                    local _bgc="${C_BG_ESC:-}" _rc="${C_RESET:-${_UI_RST:-$'\033[0m'}}"
                    printf "%s\033[38;2;255;175;40m%*s%s%s\n" "$_bgc" $_tp "" "$_ts_str" "$_rc"
                fi
            fi

        else
            # ANSI 16-color — compat theme report or no-TC menu
            local _ac="${_UI_TITLE:-$'\033[1;33m'}"
            local _sc="${_UI_SEL:-${C_CYAN:-$'\033[1;36m'}}"
            local _dc="${_UI_DIM:-$'\033[0;37m'}"
            local _rc="${C_RESET:-${_UI_RST:-$'\033[0m'}}"
            printf "%*s${_ac} _______  _   _  _______ ${_rc}\n" $_ap ""
            printf "%*s${_ac}|__   __|| \\ | ||__   __|${_rc}\n" $_ap ""
            printf "%*s${_ac}   | |   |  \\| |   | |   ${_rc}\n" $_ap ""
            printf "%*s${_ac}   | |   | |\\  |   | |   ${_rc}\n" $_ap ""
            printf "%*s${_ac}   |_|   |_| \\_|   |_|   ${_rc}\n" $_ap ""
            printf "\n"
            printf "%*s${_sc}Linux Host Security Posture Audit${_rc}\n" $_sp ""
            [[ "$_ts" == "yes" ]] && printf "${_dc}%*s%s${_rc}\n" $_tp "" "$_ts_str"
        fi

        printf "\n"

        # ── Bottom separator ────────────────────────────────────────────────────
        if [[ "$_seps" == "yes" ]]; then
            _banner_sep
        fi

    } >&$_fd
}
