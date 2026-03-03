#!/usr/bin/env bash
# themes/powershell.sh — Windows PowerShell Classic theme (requires True Color)
#
# Palette: the iconic deep-navy PowerShell console
#   PS Navy      #012456  rgb(1,36,86)     — background; the classic PS blue
#   PS White     #EEEDF0  rgb(238,237,240) — foreground; near-white console text
#   PS Cyan      #00BCD4  rgb(0,188,212)   — label / verbose accent
#   PS Yellow    #FFD700  rgb(255,215,0)   — section headers, warnings, PS prompt
#   PS Green     #00C800  rgb(0,200,0)     — pass / success
#   PS Red       #CD3131  rgb(205,49,49)   — error / fail
#   PS LightBlue #6488EA  rgb(100,136,234) — metadata / info values
#   PS Dim       #6478A8  rgb(100,120,168) — muted secondary text

THEME_TIER="truecolor"

# ── Background ────────────────────────────────────────────────────────────────
C_BG_ESC=$'\033[48;2;1;36;86m'
# After a full SGR reset, restore the PS navy background and near-white
# foreground so bare text inherits on-theme colours rather than terminal defaults.
C_RESET=$'\033[0m\033[38;2;238;237;240m\033[48;2;1;36;86m'

# ── Security levels ───────────────────────────────────────────────────────────
C_PASS=$'\033[38;2;0;200;0m'         # ps green  — pass / success
C_WARN=$'\033[38;2;255;215;0m'       # ps yellow — warnings (classic PS warning colour)
C_FAIL=$'\033[38;2;205;49;49m'       # ps red    — errors / fail
# Backward-compat aliases
C_GREEN=$C_PASS
C_YELLOW=$C_WARN
C_RED=$C_FAIL

# ── Structural roles ──────────────────────────────────────────────────────────
C_LABEL=$'\033[1;38;2;0;188;212m'    # bold ps cyan      — subsection titles, field labels
C_META=$'\033[38;2;148;178;255m'     # soft ps light-blue — metadata values (paths, ports, names)
C_SECTION=$'\033[1;38;2;255;215;0m'  # bold ps yellow    — ── divider lines ──
C_INFO=$'\033[38;2;121;140;185m'     # muted blue-gray   — explanatory context, footnotes
C_DIM=$'\033[0;38;2;100;120;168m'    # ps dim blue       — secondary / muted text
C_BOLD=$'\033[1m'
C_BLUE=$'\033[38;2;100;136;234m'     # ps blue           — kept for any direct module usages
C_CYAN=$C_META                       # backward-compat alias

# ── Gradient anchors ──────────────────────────────────────────────────────────
# Header: deep PS navy → lighter powershell blue
THEME_HDR_R1=1;    THEME_HDR_G1=36;   THEME_HDR_B1=86    # PS Navy (authentic #012456)
THEME_HDR_R2=0;    THEME_HDR_G2=60;   THEME_HDR_B2=175   # medium PS blue

# draw_line: PS blue → PS cyan sweep
THEME_LINE_R1=0;   THEME_LINE_G1=100; THEME_LINE_B1=200   # deep PS blue
THEME_LINE_R2=0;   THEME_LINE_G2=188; THEME_LINE_B2=212   # PS cyan

# Text overlaid on the header gradient bar (bold near-white for contrast on navy)
THEME_HDR_TXT=$'\033[1;38;2;238;237;240m'

# ── Banner subtitle gradient ──────────────────────────────────────────────────
# "Linux Host Security Posture Audit" — PS near-white fading to PS cyan
THEME_BANNER_R1=238; THEME_BANNER_G1=237; THEME_BANNER_B1=240  # PS near-white
THEME_BANNER_R2=0;   THEME_BANNER_G2=188; THEME_BANNER_B2=212  # PS cyan

# ── Export body colors ────────────────────────────────────────────────────────
# Used by _ansi_to_html() and _ansi_to_ps() in export.sh.
THEME_BG_HEX="#012456"
THEME_FG_HEX="#EEEDF0"
