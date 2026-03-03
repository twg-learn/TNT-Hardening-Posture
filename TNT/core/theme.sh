#!/usr/bin/env bash
# core/theme.sh — Theme loader/dispatcher
#
# Sources the appropriate themes/<name>.sh file, then verifies the loaded
# theme's THEME_TIER against TNT_TRUECOLOR.  If a truecolor theme is
# requested but the terminal doesn't support it, falls back to compat.
#
# Color variables and gradient anchors are defined entirely in the theme
# files under themes/; this file contains no color definitions.

_resolve_theme() {
    local _t="${TNT_THEME:-dark}"
    local _dir
    _dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    local _tfile="${_dir}/../themes/${_t}.sh"

    # Unknown theme name → fall back to compat
    if [[ ! -f "$_tfile" ]]; then
        _tfile="${_dir}/../themes/compat.sh"
        TNT_THEME=compat
    fi

    # shellcheck source=/dev/null
    source "$_tfile"

    # Theme requires True Color but terminal can't supply it → re-source compat
    if [[ "${THEME_TIER:-ansi16}" == "truecolor" && "${TNT_TRUECOLOR:-yes}" != "yes" ]]; then
        source "${_dir}/../themes/compat.sh"
        TNT_THEME=compat
    fi
}
_resolve_theme

WIDTH=$(tput cols 2>/dev/null || echo 80)
[[ $WIDTH -gt 100 ]] && WIDTH=100
