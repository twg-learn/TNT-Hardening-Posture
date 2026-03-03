#!/usr/bin/env bash

# Section header — full-width gradient background bar with title text overlaid.
# The bar spans exactly WIDTH columns; the title sits on a per-character BG
# gradient so the colour band is even across the whole line.
#
# truecolor themes: gradient driven by THEME_HDR_R*/G*/B* from the theme file.
# compat theme:     flat bold-blue background bar (no gradient loop).
print_header() {
    local title="  $1  "          # 2-space left pad, text, 2-space right pad
    local title_len=${#title}
    local denom=$(( WIDTH > 1 ? WIDTH - 1 : 1 ))
    local i r g b _ESC=$'\033[' _buf

    printf "\n"
    # Emit an invisible private-mode marker on the same output line as the
    # header bar.  Terminals silently discard unknown ?-mode sequences.
    # The HTML and PS converters already strip ESC[?...h/l automatically.
    # The text-export post-processor in _finalize_export() uses this marker
    # to detect header lines and replace the gradient bar with a dash rule,
    # without affecting any other export format or the live console display.
    printf '\033[?9999h'

    if [[ "${TNT_THEME:-dark}" == "compat" ]]; then
        # Reset first (clears any leaked colour state), then bold blue
        # background with explicit bright-white foreground.
        printf "\033[0m\033[1;44;97m%-*s\033[0m\n" "$WIDTH" "  $1"
    else
        # Gradient header using per-theme anchor RGB values.
        _buf=""
        for (( i=0; i<WIDTH; i++ )); do
            r=$(( THEME_HDR_R1 + (THEME_HDR_R2 - THEME_HDR_R1) * i / denom ))
            g=$(( THEME_HDR_G1 + (THEME_HDR_G2 - THEME_HDR_G1) * i / denom ))
            b=$(( THEME_HDR_B1 + (THEME_HDR_B2 - THEME_HDR_B1) * i / denom ))
            if (( i < title_len )); then
                _buf+="${_ESC}48;2;${r};${g};${b}m${THEME_HDR_TXT}${title:$i:1}"
            else
                _buf+="${_ESC}48;2;${r};${g};${b}m "
            fi
        done
        printf "%s%s\n" "$_buf" "$C_RESET"
    fi
}

# Horizontal rule — full-width gradient line.
# draw_line [char]
#   truecolor themes — per-character 24-bit gradient driven by THEME_LINE_* vars
#   compat           — flat ANSI cyan rule, no gradient
draw_line() {
    local char="${1:-=}"
    local i r g b _ESC=$'\033[' _buf

    if [[ "${TNT_THEME:-dark}" == "compat" ]]; then
        # No loop: printf -v fills a WIDTH-space string, then parameter
        # expansion replaces every space with $char in one shot.
        local _line
        printf -v _line "%*s" "$WIDTH" ""
        printf "%s%s%s\n" "$C_CYAN" "${_line// /$char}" "$C_RESET"
    else
        # Gradient rule using per-theme anchor RGB values.
        _buf="$C_BG_ESC"
        for (( i=1; i<=WIDTH; i++ )); do
            r=$(( THEME_LINE_R1 + (THEME_LINE_R2 - THEME_LINE_R1) * i / WIDTH ))
            g=$(( THEME_LINE_G1 + (THEME_LINE_G2 - THEME_LINE_G1) * i / WIDTH ))
            b=$(( THEME_LINE_B1 + (THEME_LINE_B2 - THEME_LINE_B1) * i / WIDTH ))
            _buf+="${_ESC}38;2;${r};${g};${b}m${char}"
        done
        printf "%s%s\n" "$_buf" "$C_RESET"
    fi
}

# Prints a section explanation paragraph when TNT_EXPLAIN=yes.
# Word-wraps to terminal width with the theme's C_INFO style.
print_explain() {
    [[ "${TNT_EXPLAIN:-no}" == "yes" ]] || return
    printf "\n"
    local wrap=$(( WIDTH - 6 ))
    [[ $wrap -lt 40 ]] && wrap=40
    printf "%s" "$1" | fold -s -w "$wrap" | while IFS= read -r line || [[ -n "$line" ]]; do
        printf "  %s%s%s\n" "$C_INFO" "$line" "$C_RESET"
    done
    printf "\n"
}

# Returns JUST the color code (crucial for perfect table alignment)
get_color() {
    local val=$1 good=$2 warn=$3
    if [[ "$val" =~ $good ]]; then echo -n "$C_GREEN"
    elif [[ -n "$warn" && "$val" =~ $warn ]]; then echo -n "$C_YELLOW"
    else echo -n "$C_RED"; fi
}

# Returns the fully colored string (great for key-value pairs)
color_val() {
    local col=$(get_color "$1" "$2" "$3")
    # Using printf is more robust for variables containing escape bytes
    printf "%s%s%s" "$col" "$1" "$C_RESET"
}
