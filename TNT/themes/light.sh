#!/usr/bin/env bash
# themes/light.sh — Light theme (requires True Color)
#
# THEME_TIER declares terminal capability requirement.
# theme.sh (loader) will fall back to compat if TC is unavailable.

THEME_TIER="truecolor"

# ── Background ────────────────────────────────────────────────────────────────
C_BG_ESC=$'\033[48;2;255;255;255m'
# After a full SGR reset, re-apply white background.
C_RESET=$'\033[0m\033[48;2;255;255;255m'

# ── Security levels ───────────────────────────────────────────────────────────
C_PASS=$'\033[38;2;0;140;50m'         # darker green — contrasts on white
C_WARN=$'\033[38;2;160;90;0m'         # darker amber — readable on white
C_FAIL=$'\033[38;2;200;0;0m'          # darker red   — readable on white
# Backward-compat aliases
C_GREEN=$C_PASS
C_YELLOW=$C_WARN
C_RED=$C_FAIL

# ── Structural roles ──────────────────────────────────────────────────────────
C_LABEL=$'\033[1;38;2;0;120;170m'     # bold teal  — subsection titles, field labels
C_META=$'\033[38;2;0;120;170m'        # teal       — metadata values
C_SECTION=$'\033[1;38;2;180;90;0m'    # bold darker orange — ── divider lines ──
C_INFO=$'\033[38;2;80;100;160m'       # muted blue — explanatory context
C_DIM=$'\033[0;38;2;120;120;120m'     # gray       — secondary text
C_BOLD=$'\033[1m'
C_BLUE=$'\033[38;2;0;70;200m'
C_CYAN=$C_META                        # backward-compat alias

# ── Gradient anchors ──────────────────────────────────────────────────────────
# Header: medium blue (left) → medium purple (right)
THEME_HDR_R1=30;   THEME_HDR_G1=70;   THEME_HDR_B1=165
THEME_HDR_R2=110;  THEME_HDR_G2=30;   THEME_HDR_B2=165
# draw_line: cyan-blue gradient
THEME_LINE_R1=10;  THEME_LINE_G1=140; THEME_LINE_B1=200
THEME_LINE_R2=50;  THEME_LINE_G2=80;  THEME_LINE_B2=200

# Text overlaid on the header gradient bar (bold white — high contrast on colored BG)
THEME_HDR_TXT=$'\033[1;38;2;255;255;255m'

# ── Export body colors ────────────────────────────────────────────────────────
THEME_BG_HEX="#ffffff"
THEME_FG_HEX="#1a1a1a"
