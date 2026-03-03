#!/usr/bin/env bash
# themes/vampire.sh — Vampire theme (requires True Color)
#
# Palette:
#   Dark Crypt   #3b1010  rgb(59,16,16)   — background; deep dark red
#   Fresh Blood  #FF0000  rgb(255,0,0)    — primary; FAIL indicators, section dividers
#   Dark Clot    #8B0000  rgb(139,0,0)    — secondary; draw_line gradient, accent
#   Bone White   #F5F5F5  rgb(245,245,245)— structural labels, overlay text
#   Ash Grey     #4A4A4A  rgb(74,74,74)   — detail / dim text
#
# Invented supporting colors:
#   Pale Moss    rgb(120,210,90)  — PASS; a rare, sickly sign of life
#   Dying Ember  rgb(215,145,0)   — WARN; the last warmth before dark
#   Pale Ichor   rgb(230,210,210) — META; blood-tinted parchment
#   Crypt Shadow rgb(165,140,140) — INFO; dust and old stone
#   Midnight     rgb(120,80,200)  — BLUE; the color of a bruise, or moonlit velvet

THEME_TIER="truecolor"

# ── Background ────────────────────────────────────────────────────────────────
C_BG_ESC=$'\033[48;2;41;9;9m'
# After a full SGR reset, re-apply warm foreground + dark-red background so
# plain text (bare values, key columns) inherits an on-theme color, not the
# terminal default.
C_RESET=$'\033[0m\033[38;2;240;220;220m\033[48;2;41;9;9m'

# ── Security levels ───────────────────────────────────────────────────────────
C_PASS=$'\033[38;2;120;210;90m'       # pale moss   — rare signs of life
C_WARN=$'\033[38;2;215;145;0m'        # dying ember — last warmth before darkness
C_FAIL=$'\033[38;2;255;0;0m'          # fresh blood — critical
# Backward-compat aliases
C_GREEN=$C_PASS
C_YELLOW=$C_WARN
C_RED=$C_FAIL

# ── Structural roles ──────────────────────────────────────────────────────────
C_LABEL=$'\033[1;38;2;245;245;245m'   # bold bone white  — subsection titles, field labels
C_META=$'\033[38;2;135;22;22m'      # pale ichor       — metadata values (usernames, ports, paths)
C_SECTION=$'\033[1;38;2;255;0;0m'     # bold fresh blood — ── divider lines ──
C_INFO=$'\033[38;2;165;140;140m'      # crypt shadow     — explanatory context, footnotes
C_DIM=$'\033[38;2;110;90;90m'         # dried ash        — secondary / muted text
C_BOLD=$'\033[1m'
C_BLUE=$'\033[38;2;120;80;200m'       # midnight violet  — kept for any direct usages
C_CYAN=$C_META                        # backward-compat alias

# ── Gradient anchors ──────────────────────────────────────────────────────────
# Header: Pure Abyss → smoldering deep crimson
THEME_HDR_R1=30;   THEME_HDR_G1=0;   THEME_HDR_B1=5    # near-black with blood tint
THEME_HDR_R2=120;  THEME_HDR_G2=0;   THEME_HDR_B2=20   # deep crimson with hint of purple
# draw_line: Dark Clot → Fresh Blood
THEME_LINE_R1=80;  THEME_LINE_G1=0;  THEME_LINE_B1=0   # dark clot
THEME_LINE_R2=220; THEME_LINE_G2=0;  THEME_LINE_B2=0   # brightening toward fresh blood

# Text overlaid on the header gradient bar (bold bone white)
THEME_HDR_TXT=$'\033[1;38;2;209;160;151m'

# ── Banner subtitle gradient ──────────────────────────────────────────────────
# "Linux Host Security Posture Audit" — bone-pink fading to deep blood-red
THEME_BANNER_R1=230; THEME_BANNER_G1=120; THEME_BANNER_B1=120   # warm rose
THEME_BANNER_R2=140; THEME_BANNER_G2=10;  THEME_BANNER_B2=10    # deep crimson

# ── Export body colors ────────────────────────────────────────────────────────
THEME_BG_HEX="#290909"
THEME_FG_HEX="#F5F5F5"
