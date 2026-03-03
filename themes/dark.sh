#!/usr/bin/env bash
# themes/dark.sh — Dark theme (requires True Color)
#
# THEME_TIER declares terminal capability requirement.
# theme.sh (loader) will fall back to compat if TC is unavailable.

THEME_TIER="truecolor"

# ── Background ────────────────────────────────────────────────────────────────
C_BG_ESC=$'\033[48;2;0;0;0m'
# After a full SGR reset, re-apply black background so subsequent text
# never exposes the terminal default background.
C_RESET=$'\033[0m\033[48;2;0;0;0m'

# ── Security levels ───────────────────────────────────────────────────────────
C_PASS=$'\033[38;2;60;235;110m'       # vivid green
C_WARN=$'\033[38;2;255;200;0m'        # amber
C_FAIL=$'\033[38;2;255;75;75m'        # vivid red
# Backward-compat aliases (modules still using C_GREEN / C_YELLOW / C_RED work unchanged)
C_GREEN=$C_PASS
C_YELLOW=$C_WARN
C_RED=$C_FAIL

# ── Structural roles ──────────────────────────────────────────────────────────
C_LABEL=$'\033[1;38;2;0;215;255m'     # bold teal  — subsection titles, field labels
C_META=$'\033[38;2;0;215;255m'        # soft teal  — metadata values (usernames, ports, paths)
C_SECTION=$'\033[1;38;2;255;140;0m'   # bold orange — ── divider lines ──
C_INFO=$'\033[38;2;130;150;200m'      # muted blue-gray — explanatory context, footnotes
C_DIM=$'\033[0;38;2;140;140;140m'     # gray       — secondary / muted text
C_BOLD=$'\033[1m'
C_BLUE=$'\033[38;2;70;130;255m'       # kept for any direct usages in modules
C_CYAN=$C_META                        # backward-compat alias

# ── Gradient anchors ──────────────────────────────────────────────────────────
# Used by print_header() and draw_line() in helpers.sh.
# truecolor themes define start (R1/G1/B1) and end (R2/G2/B2) of each gradient.
THEME_HDR_R1=5;    THEME_HDR_G1=75;   THEME_HDR_B1=115   # header gradient start
THEME_HDR_R2=60;   THEME_HDR_G2=20;   THEME_HDR_B2=150   # header gradient end
THEME_LINE_R1=20;  THEME_LINE_G1=210; THEME_LINE_B1=255   # draw_line gradient start
THEME_LINE_R2=80;  THEME_LINE_G2=130; THEME_LINE_B2=255   # draw_line gradient end

# Text overlaid on the header gradient bar (bold near-white)
THEME_HDR_TXT=$'\033[1;38;2;220;240;255m'

# ── Export body colors ────────────────────────────────────────────────────────
# Used by _ansi_to_html() and _ansi_to_ps() in export.sh.
THEME_BG_HEX="#000000"
THEME_FG_HEX="#d0d0e8"
