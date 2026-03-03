#!/usr/bin/env bash
# themes/compat.sh — Compatibility theme (ANSI 16-color)
#
# Works on any terminal; no True Color required.
# Gradient vars are defined but unused — compat draw_line/print_header
# use flat ANSI codes instead of per-character RGB sequences.

THEME_TIER="ansi16"

# ── Background ────────────────────────────────────────────────────────────────
C_BG_ESC=''
C_RESET=$'\033[0m'

# ── Security levels ───────────────────────────────────────────────────────────
C_PASS=$'\033[32m'
C_WARN=$'\033[33m'
C_FAIL=$'\033[31m'
# Backward-compat aliases
C_GREEN=$C_PASS
C_YELLOW=$C_WARN
C_RED=$C_FAIL

# ── Structural roles ──────────────────────────────────────────────────────────
C_LABEL=$'\033[1;36m'                 # bold cyan — subsection titles, field labels
C_META=$'\033[36m'                    # cyan      — metadata values
C_SECTION=$'\033[1;33m'              # bold yellow — ── divider lines ──
C_INFO=$'\033[0;37m'                  # gray      — explanatory context
C_DIM=$'\033[0;37m'                   # gray      — secondary text
C_BOLD=$'\033[1m'
C_BLUE=$'\033[34m'
C_CYAN=$C_META                        # backward-compat alias

# ── Gradient anchors ──────────────────────────────────────────────────────────
# Not used by compat — draw_line and print_header use flat ANSI for this tier.
THEME_HDR_R1=0;   THEME_HDR_G1=0;   THEME_HDR_B1=0
THEME_HDR_R2=0;   THEME_HDR_G2=0;   THEME_HDR_B2=0
THEME_LINE_R1=0;  THEME_LINE_G1=0;  THEME_LINE_B1=0
THEME_LINE_R2=0;  THEME_LINE_G2=0;  THEME_LINE_B2=0

THEME_HDR_TXT=''  # unused for compat (print_header uses inline ANSI)

# ── Export body colors ────────────────────────────────────────────────────────
THEME_BG_HEX="#1e1e1e"
THEME_FG_HEX="#d0d0e8"
