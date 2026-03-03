#!/usr/bin/env bash
# themes/manila.sh — Manila theme (requires True Color)
#
# Palette: warm paper, dark ink — like a formal printed report on natural stock
#   Manila Paper  #F8ECBC  rgb(248,236,188) — background; warm natural manila
#   Espresso      #3A200A  rgb(58,32,10)    — foreground; rich dark ink
#   Walnut        #5F3008  rgb(95,48,8)     — labels; deep walnut brown
#   Saddle        #804412  rgb(128,68,18)   — metadata; warm saddle brown
#   Amber         #AC5F0C  rgb(172,95,12)   — sections, warnings; burnt amber
#   Forest        #28803A  rgb(40,128,58)   — pass; earthy forest green
#   Brick         #AF2323  rgb(175,35,35)   — fail; deep brick red
#   Olive         #645535  rgb(100,85,53)   — info; muted olive-brown
#   Tan           #9B8260  rgb(155,130,96)  — dim; faded parchment tan
#   Ink Blue      #3E5289  rgb(62,82,137)   — blue; a drop of ink in the well

THEME_TIER="truecolor"

# ── Background ────────────────────────────────────────────────────────────────
C_BG_ESC=$'\033[48;2;248;236;188m'
# After a full SGR reset, restore manila background with espresso foreground so
# bare text (key columns, plain values) reads like ink on paper throughout.
C_RESET=$'\033[0m\033[38;2;58;32;10m\033[48;2;248;236;188m'

# ── Security levels ───────────────────────────────────────────────────────────
C_PASS=$'\033[38;2;40;128;58m'        # forest green — earthy, readable on manila
C_WARN=$'\033[38;2;172;95;12m'        # burnt amber  — warm, readable on manila
C_FAIL=$'\033[38;2;175;35;35m'        # brick red     — deep, readable on manila
# Backward-compat aliases
C_GREEN=$C_PASS
C_YELLOW=$C_WARN
C_RED=$C_FAIL

# ── Structural roles ──────────────────────────────────────────────────────────
C_LABEL=$'\033[1;38;2;95;48;8m'       # bold walnut   — subsection titles, field labels
C_META=$'\033[38;2;128;68;18m'        # saddle brown  — metadata values (paths, ports, names)
C_SECTION=$'\033[1;38;2;172;95;12m'   # bold amber    — ── divider lines ──
C_INFO=$'\033[38;2;100;85;53m'        # olive-brown   — explanatory context, footnotes
C_DIM=$'\033[0;38;2;155;130;96m'      # parchment tan — secondary / muted text
C_BOLD=$'\033[1m'
C_BLUE=$'\033[38;2;62;82;137m'        # ink blue      — kept for any direct module usages
C_CYAN=$C_META                        # backward-compat alias

# ── Gradient anchors ──────────────────────────────────────────────────────────
# Header: dark espresso → rich umber (deep ink bar across manila)
THEME_HDR_R1=55;   THEME_HDR_G1=25;   THEME_HDR_B1=6    # near-black espresso
THEME_HDR_R2=120;  THEME_HDR_G2=58;   THEME_HDR_B2=16   # rich umber

# draw_line: amber → golden wheat sweep
THEME_LINE_R1=175; THEME_LINE_G1=105; THEME_LINE_B1=20   # burnt amber
THEME_LINE_R2=215; THEME_LINE_G2=160; THEME_LINE_B2=55   # golden wheat

# Text overlaid on the header gradient bar (bold warm cream — high contrast on espresso)
THEME_HDR_TXT=$'\033[1;38;2;252;240;205m'

# ── Banner subtitle gradient ──────────────────────────────────────────────────
# "Linux Host Security Posture Audit" — espresso fading out to warm amber
THEME_BANNER_R1=88;  THEME_BANNER_G1=42;  THEME_BANNER_B1=8    # espresso
THEME_BANNER_R2=195; THEME_BANNER_G2=118; THEME_BANNER_B2=28   # amber

# ── Export body colors ────────────────────────────────────────────────────────
# Used by _ansi_to_html() and _ansi_to_ps() in export.sh.
THEME_BG_HEX="#F8ECBC"
THEME_FG_HEX="#3A200A"
