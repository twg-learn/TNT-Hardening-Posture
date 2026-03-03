#!/usr/bin/env bash
# core/export.sh — Export formatting and file writing for TNT Security Posture

# ── ANSI → HTML converter ──────────────────────────────────────────────────────
# $1 = path to the raw ANSI capture file.
# Writes a complete HTML document to stdout.
# Body colors read from THEME_BG_HEX / THEME_FG_HEX (set by active theme file).
# Implemented in pure awk; no external language runtime required.
_ansi_to_html() {
    local _file="$1"

    # Body colors come from the active theme's THEME_BG_HEX / THEME_FG_HEX vars,
    # which are sourced from the theme file before _finalize_export() is called.
    local _body_style="background:${THEME_BG_HEX:-#000000}; color:${THEME_FG_HEX:-#d0d0e8};"

    # HTML header (bash handles theme interpolation; awk handles body content)
    printf '<!DOCTYPE html>\n<html lang="en">\n<head>\n'
    printf '  <meta charset="UTF-8">\n'
    printf '  <meta name="viewport" content="width=device-width, initial-scale=1">\n'
    printf '  <title>TNT Security Posture Report</title>\n'
    printf '  <style>\n'
    printf '    * { box-sizing: border-box; margin: 0; padding: 0; }\n'
    printf '    html, body {\n      %s\n' "$_body_style"
    printf "      font-family: 'Cascadia Code', 'JetBrains Mono', 'Fira Code',\n"
    printf "                   'Source Code Pro', 'Consolas', 'Courier New', monospace;\n"
    printf '      font-size: 13px;\n      line-height: 1.45;\n    }\n'
    printf '    body { padding: 24px 32px; }\n'
    printf '    pre  { white-space: pre-wrap; word-break: break-all; }\n'
    printf '  </style>\n</head>\n<body><pre>'

    awk 'BEGIN {
        ESC = sprintf("%c", 27)   # portable: avoids \033 in regex literals

        fg16[30]="#2e2e2e"; fg16[31]="#cc0000"; fg16[32]="#4e9a06"; fg16[33]="#c4a000"
        fg16[34]="#3465a4"; fg16[35]="#75507b"; fg16[36]="#06989a"; fg16[37]="#d3d7cf"
        fg16[90]="#555753"; fg16[91]="#ef2929"; fg16[92]="#8ae234"; fg16[93]="#fce94f"
        fg16[94]="#729fcf"; fg16[95]="#ad7fa8"; fg16[96]="#34e2e2"; fg16[97]="#eeeeec"
        bg16[40]="#2e2e2e"; bg16[41]="#cc0000"; bg16[42]="#4e9a06"; bg16[43]="#c4a000"
        bg16[44]="#3465a4"; bg16[45]="#75507b"; bg16[46]="#06989a"; bg16[47]="#d3d7cf"
        bg16[100]="#555753"; bg16[101]="#ef2929"; bg16[102]="#8ae234"; bg16[103]="#fce94f"
        bg16[104]="#729fcf"; bg16[105]="#ad7fa8"; bg16[106]="#34e2e2"; bg16[107]="#eeeeec"

        bold = 0; fg_col = ""; bg_col = ""; open_span = 0
        ORS = ""
    }

    function html_escape(s,    t) {
        t = s
        gsub(/&/, "\\&amp;",  t)
        gsub(/</, "\\&lt;",   t)
        gsub(/>/, "\\&gt;",   t)
        return t
    }

    function close_span() {
        if (open_span) { printf "</span>"; open_span = 0 }
    }

    function do_open_span(    style, sep) {
        style = ""; sep = ""
        if (bold)         { style = style sep "font-weight:bold"; sep = ";" }
        if (fg_col != "") { style = style sep "color:"      fg_col;  sep = ";" }
        if (bg_col != "") { style = style sep "background:" bg_col }
        if (style != "") { printf "<span style=\"%s\">", style; open_span = 1 }
    }

    function process_sgr(seq,    n, params, i, p) {
        if (seq == "") { bold = 0; fg_col = ""; bg_col = ""; return }
        n = split(seq, params, ";")
        for (i = 1; i <= n; i++) params[i] = (params[i] == "") ? 0 : params[i]+0
        i = 1
        while (i <= n) {
            p = params[i]
            if      (p == 0)  { bold = 0; fg_col = ""; bg_col = "" }
            else if (p == 1)  { bold = 1 }
            else if (p == 22) { bold = 0 }
            else if ((p >= 30 && p <= 37) || (p >= 90 && p <= 97))   { fg_col = (p in fg16) ? fg16[p] : "" }
            else if ((p >= 40 && p <= 47) || (p >= 100 && p <= 107)) { bg_col = (p in bg16) ? bg16[p] : "" }
            else if (p == 38 && (i+4) <= n && params[i+1] == 2) {
                fg_col = "rgb(" (params[i+2]+0) "," (params[i+3]+0) "," (params[i+4]+0) ")"
                i += 4
            }
            else if (p == 48 && (i+4) <= n && params[i+1] == 2) {
                bg_col = "rgb(" (params[i+2]+0) "," (params[i+3]+0) "," (params[i+4]+0) ")"
                i += 4
            }
            else if (p == 39) { fg_col = "" }
            else if (p == 49) { bg_col = "" }
            i++
        }
    }

    {
        line = $0
        # Strip non-SGR control sequences (cursor movement, private modes, clear screen)
        gsub(ESC "\\[[0-9]*[ABCDEFGHJKSTsu]", "", line)
        gsub(ESC "\\[\\?[0-9;]*[hl]",         "", line)
        gsub(ESC "\\[2J",                      "", line)
        gsub(ESC "\\[H",                       "", line)

        sgr_pat = ESC "\\[[0-9;]*m"
        while (length(line) > 0) {
            if (match(line, sgr_pat)) {
                if (RSTART > 1) {
                    txt = substr(line, 1, RSTART - 1)
                    gsub(ESC ".", "", txt)   # drop residual lone ESC sequences
                    if (length(txt) > 0) {
                        if (!open_span) do_open_span()
                        printf "%s", html_escape(txt)
                    }
                }
                raw = substr(line, RSTART, RLENGTH)
                close_span()
                process_sgr(substr(raw, 3, length(raw) - 3))
                line = substr(line, RSTART + RLENGTH)
            } else {
                gsub(ESC ".", "", line)
                if (length(line) > 0) {
                    if (!open_span) do_open_span()
                    printf "%s", html_escape(line)
                }
                break
            }
        }
        close_span()
        printf "\n"
    }

    END { close_span() }
    ' "$_file"

    printf '</pre></body></html>\n'
}

# ── ANSI → PostScript converter ────────────────────────────────────────────────
# $1 = path to the raw ANSI capture file
# Writes a complete DSC-conforming PostScript document to stdout.
# Body colors read from THEME_BG_HEX / THEME_FG_HEX (set by active theme file).
# Implemented in pure awk; no external language runtime required.
# Unicode box-drawing / arrow characters are substituted with ASCII equivalents
# because standard PostScript fonts (Courier) cover only Latin-1.
_ansi_to_ps() {
    local _file="$1"
    # Pass hex colors from the active theme into awk as fractional RGB values.
    # _hex_to_frac converts "#rrggbb" → three space-separated 0.0–1.0 values.
    _hex_to_frac() {
        local hex="${1#\#}"
        local r=$(( 16#${hex:0:2} )) g=$(( 16#${hex:2:2} )) b=$(( 16#${hex:4:2} ))
        printf "%s %s %s" "$(awk "BEGIN{printf \"%.4f\",$r/255}")" \
                          "$(awk "BEGIN{printf \"%.4f\",$g/255}")" \
                          "$(awk "BEGIN{printf \"%.4f\",$b/255}")"
    }
    local _fg_frac _bg_frac
    _fg_frac=$(_hex_to_frac "${THEME_FG_HEX:-#d0d0e8}")
    _bg_frac=$(_hex_to_frac "${THEME_BG_HEX:-#000000}")

    LC_ALL=C awk -v _fg_frac="$_fg_frac" -v _bg_frac="$_bg_frac" '
    BEGIN {
        ESC = sprintf("%c", 27)

        # ── 16-color fg palette (normalized 0.0-1.0) ───────────────────────
        # bg codes 40-47 / 100-107 are looked up via equiv = p - 10
        fg16_r[30]=0.1804; fg16_g[30]=0.1804; fg16_b[30]=0.1804
        fg16_r[31]=0.8000; fg16_g[31]=0.0000; fg16_b[31]=0.0000
        fg16_r[32]=0.3059; fg16_g[32]=0.6039; fg16_b[32]=0.0235
        fg16_r[33]=0.7686; fg16_g[33]=0.6275; fg16_b[33]=0.0000
        fg16_r[34]=0.2039; fg16_g[34]=0.3961; fg16_b[34]=0.6431
        fg16_r[35]=0.4588; fg16_g[35]=0.3137; fg16_b[35]=0.4824
        fg16_r[36]=0.0235; fg16_g[36]=0.5961; fg16_b[36]=0.6039
        fg16_r[37]=0.8275; fg16_g[37]=0.8431; fg16_b[37]=0.8118
        fg16_r[90]=0.3333; fg16_g[90]=0.3412; fg16_b[90]=0.3255
        fg16_r[91]=0.9373; fg16_g[91]=0.1608; fg16_b[91]=0.1608
        fg16_r[92]=0.5412; fg16_g[92]=0.8863; fg16_b[92]=0.2039
        fg16_r[93]=0.9882; fg16_g[93]=0.9137; fg16_b[93]=0.3098
        fg16_r[94]=0.4471; fg16_g[94]=0.6235; fg16_b[94]=0.8118
        fg16_r[95]=0.6784; fg16_g[95]=0.4980; fg16_b[95]=0.6588
        fg16_r[96]=0.2039; fg16_g[96]=0.8863; fg16_b[96]=0.8863
        fg16_r[97]=0.9333; fg16_g[97]=0.9333; fg16_b[97]=0.9255

        # ── Page geometry (points) ─────────────────────────────────────────
        PH = 842; ML = 34; MB = 34; MT = 34
        FS = 9; CW = 5.4; LH = 13       # font-size, char-width, line-height
        page_top = PH - MT - FS         # 799: baseline of first line

        # ── Theme default fg / bg (passed in as fractional RGB triplets) ──────
        n = split(_fg_frac, fg_parts, " ")
        def_fg_r = fg_parts[1]+0; def_fg_g = fg_parts[2]+0; def_fg_b = fg_parts[3]+0
        n = split(_bg_frac, bg_parts, " ")
        def_bg_r = bg_parts[1]+0; def_bg_g = bg_parts[2]+0; def_bg_b = bg_parts[3]+0

        # ── Ordinal table for ps_escape ────────────────────────────────────
        for (i = 0; i < 256; i++) ord_tbl[sprintf("%c",i)] = i

        # ── DSC header + prolog ────────────────────────────────────────────
        print "%!PS-Adobe-3.0"
        print "%%BoundingBox: 0 0 595 842"
        print "%%Pages: (atend)"
        print "%%DocumentNeededFonts: Courier Courier-Bold"
        print "%%EndComments"
        print "%%BeginProlog"
        print "/F_REG  /Courier      findfont 9 scalefont def"
        print "/F_BOLD /Courier-Bold findfont 9 scalefont def"
        print "%%EndProlog"
        print "%%BeginSetup"
        print "<< /PageSize [595 842] >> setpagedevice"
        print "%%EndSetup"

        # ── Initial SGR state ──────────────────────────────────────────────
        bold=0; has_bg=0
        fg_r=def_fg_r; fg_g=def_fg_g; fg_b=def_fg_b
        bg_r=def_bg_r; bg_g=def_bg_g; bg_b=def_bg_b

        page_num=0
        new_page()
    }

    # Escape special PS string chars; octal-escape non-printable bytes
    function ps_escape(s,    i, c, code, out) {
        out = ""
        for (i = 1; i <= length(s); i++) {
            c    = substr(s, i, 1)
            code = ord_tbl[c]
            if      (c == "(")                out = out "\\("
            else if (c == ")")                out = out "\\)"
            else if (c == "\\")               out = out "\\\\"
            else if (code < 32 || code > 126) out = out sprintf("\\%03o", code)
            else                              out = out c
        }
        return out
    }

    function new_page() {
        if (page_num > 0) print "showpage"
        page_num++
        printf "%%%%Page: %d %d\n", page_num, page_num
        printf "%g %g %g setrgbcolor\n", def_bg_r, def_bg_g, def_bg_b
        print "0 0 595 842 rectfill"
        print "F_REG setfont"
        y = page_top; x = ML
    }

    function emit_text_run(txt,    n, rw, esc) {
        if (length(txt) == 0) return
        n   = length(txt)
        rw  = n * CW
        esc = ps_escape(txt)
        if (bold) print "F_BOLD setfont"
        else      print "F_REG  setfont"
        if (has_bg) {
            printf "%g %g %g setrgbcolor\n", bg_r, bg_g, bg_b
            printf "%g %g %g %g rectfill\n", x, (y - 2), rw, LH
        }
        printf "%g %g %g setrgbcolor\n", fg_r, fg_g, fg_b
        printf "%g %g moveto\n",         x, y
        printf "(%s) show\n",            esc
        x += rw
    }

    function process_sgr(seq,    n, params, i, p, eq) {
        if (seq == "") {
            bold=0; has_bg=0
            fg_r=def_fg_r; fg_g=def_fg_g; fg_b=def_fg_b
            return
        }
        n = split(seq, params, ";")
        for (i=1; i<=n; i++) params[i] = (params[i]=="") ? 0 : params[i]+0
        i = 1
        while (i <= n) {
            p = params[i]
            if (p == 0) {
                bold=0; has_bg=0
                fg_r=def_fg_r; fg_g=def_fg_g; fg_b=def_fg_b
            }
            else if (p == 1)  { bold = 1 }
            else if (p == 22) { bold = 0 }
            else if ((p>=30 && p<=37) || (p>=90 && p<=97)) {
                if (p in fg16_r) { fg_r=fg16_r[p]; fg_g=fg16_g[p]; fg_b=fg16_b[p] }
            }
            else if ((p>=40 && p<=47) || (p>=100 && p<=107)) {
                eq = p - 10
                if (eq in fg16_r) {
                    bg_r=fg16_r[eq]; bg_g=fg16_g[eq]; bg_b=fg16_b[eq]; has_bg=1
                }
            }
            else if (p==38 && (i+4)<=n && params[i+1]==2) {
                fg_r=params[i+2]/255; fg_g=params[i+3]/255; fg_b=params[i+4]/255; i+=4
            }
            else if (p==48 && (i+4)<=n && params[i+1]==2) {
                bg_r=params[i+2]/255; bg_g=params[i+3]/255; bg_b=params[i+4]/255; has_bg=1; i+=4
            }
            else if (p==39) { fg_r=def_fg_r; fg_g=def_fg_g; fg_b=def_fg_b }
            else if (p==49) { has_bg=0 }
            i++
        }
    }

    {
        line = $0
        gsub(/\r/, "", line)

        # Strip non-SGR control sequences
        gsub(ESC "\\[[0-9]*[ABCDEFGHJKSTsu]", "", line)
        gsub(ESC "\\[\\?[0-9;]*[hl]",         "", line)
        gsub(ESC "\\[2J",                      "", line)
        gsub(ESC "\\[H",                       "", line)

        gsub(/\t/, "        ", line)

        # Unicode → ASCII substitution (3-byte UTF-8 sequences first)
        gsub(/\342\224\200/, "-",   line)   # ─
        gsub(/\342\225\220/, "=",   line)   # ═
        gsub(/\342\224\202/, "|",   line)   # │
        gsub(/\342\225\221/, "|",   line)   # ║
        gsub(/\342\224\214/, "+",   line)   # ┌
        gsub(/\342\224\220/, "+",   line)   # ┐
        gsub(/\342\224\224/, "+",   line)   # └
        gsub(/\342\224\230/, "+",   line)   # ┘
        gsub(/\342\224\234/, "+",   line)   # ├
        gsub(/\342\224\244/, "+",   line)   # ┤
        gsub(/\342\224\254/, "+",   line)   # ┬
        gsub(/\342\224\264/, "+",   line)   # ┴
        gsub(/\342\224\274/, "+",   line)   # ┼
        gsub(/\342\226\266/, ">",   line)   # ▶
        gsub(/\342\234\223/, "*",   line)   # ✓
        gsub(/\342\234\227/, "x",   line)   # ✗
        gsub(/\342\234\230/, "x",   line)   # ✘
        gsub(/\342\200\242/, ".",   line)   # •
        gsub(/\342\200\246/, "...", line)   # …
        gsub(/\342\206\222/, "->",  line)   # →
        gsub(/\342\206\220/, "<-",  line)   # ←
        # 2-byte UTF-8
        gsub(/\302\267/, ".", line)         # · (U+00B7)
        gsub(/\302\240/, " ", line)         # NBSP

        # Fallback: replace remaining multi-byte sequences with ?
        gsub(/[\300-\337][\200-\277]/,                      "?", line)
        gsub(/[\340-\357][\200-\277][\200-\277]/,            "?", line)
        gsub(/[\360-\367][\200-\277][\200-\277][\200-\277]/, "?", line)
        gsub(/[\001-\010\013-\032\034-\037\177]/, "", line)

        sgr_pat = ESC "\\[[0-9;]*m"
        while (length(line) > 0) {
            if (match(line, sgr_pat)) {
                if (RSTART > 1) {
                    txt = substr(line, 1, RSTART - 1)
                    gsub(ESC ".", "", txt)
                    if (length(txt) > 0) emit_text_run(txt)
                }
                raw = substr(line, RSTART, RLENGTH)
                process_sgr(substr(raw, 3, length(raw) - 3))
                line = substr(line, RSTART + RLENGTH)
            } else {
                gsub(ESC ".", "", line)
                if (length(line) > 0) emit_text_run(line)
                break
            }
        }

        y -= LH; x = ML
        if (y < MB) new_page()
    }

    END {
        print "showpage"
        print "%%Trailer"
        printf "%%%%Pages: %d\n", page_num
        print "%%EOF"
    }
    ' "$_file"
}

# ── Fix export file permissions ────────────────────────────────────────────────
# posture.sh runs as root (sudo). Output files are created root:root 600 by
# default, which prevents the real user from opening them in a browser or viewer.
# This sets them world-readable and, when SUDO_USER is available, transfers
# ownership back to the invoking user.
_fix_export_perms() {
    local _file="$1"
    chmod 644 "$_file" 2>/dev/null
    if [[ -n "${SUDO_USER:-}" ]]; then
        chown "$SUDO_USER:" "$_file" 2>/dev/null
    fi
}

# ── ANSI → PS → PDF ────────────────────────────────────────────────────────────
# Converts capture directly to PDF via PostScript (no browser required).
# $1 = raw ANSI capture file  $2 = output .pdf path
# Returns 0 on success, 1 if ps2pdf unavailable or conversion failed.
_generate_pdf_from_ps() {
    local _capture="$1" _pdf="$2"
    command -v ps2pdf &>/dev/null || return 1
    local _ps_tmp _pdf_tmp
    _ps_tmp=$(mktemp --suffix=.ps)  || return 1
    _pdf_tmp=$(mktemp --suffix=.pdf) || { rm -f "$_ps_tmp"; return 1; }
    _ansi_to_ps "$_capture" > "$_ps_tmp"
    # Write to /tmp first — AppArmor's GhostScript profile (usr.bin.gs) denies
    # writes to arbitrary paths outside /tmp; move the result afterwards.
    ps2pdf "$_ps_tmp" "$_pdf_tmp" 2>/dev/tty
    local _rc=$?
    rm -f "$_ps_tmp"
    if [[ $_rc -eq 0 && -s "$_pdf_tmp" ]]; then
        mv "$_pdf_tmp" "$_pdf"
        return $?
    fi
    rm -f "$_pdf_tmp"
    return 1
}

# ── PDF generator (HTML path) ──────────────────────────────────────────────────
# Tries available HTML→PDF tools in order. Returns 0 on success, 1 if none found.
_generate_pdf_from_html() {
    local _html="$1" _pdf="$2"

    if command -v wkhtmltopdf &>/dev/null; then
        wkhtmltopdf --background --quiet --print-media-type \
            --page-size A4 --dpi 150 \
            --margin-top 10mm --margin-bottom 10mm \
            --margin-left 12mm --margin-right 12mm \
            "$_html" "$_pdf" 2>/dev/null && return 0
    fi
    if command -v chromium &>/dev/null; then
        chromium --headless --no-sandbox \
            --print-to-pdf="$_pdf" "file://${_html}" 2>/dev/null && return 0
    fi
    if command -v google-chrome &>/dev/null; then
        google-chrome --headless --no-sandbox \
            --print-to-pdf="$_pdf" "file://${_html}" 2>/dev/null && return 0
    fi
    if command -v chromium-browser &>/dev/null; then
        chromium-browser --headless --no-sandbox \
            --print-to-pdf="$_pdf" "file://${_html}" 2>/dev/null && return 0
    fi
    if command -v weasyprint &>/dev/null; then
        weasyprint "$_html" "$_pdf" 2>/dev/null && return 0
    fi
    return 1
}

# ── Export finalizer ───────────────────────────────────────────────────────────
# Called after all report output is complete.
# Reads:  _TNT_CAPTURE_FILE (temp file with raw ANSI output)
#         TNT_EXPORT_TYPE, TNT_EXPORT_PATH, TNT_EXPORT_NAME
_finalize_export() {
    [[ "${TNT_EXPORT:-no}" != "yes" ]] && return

    # Ensure common binary dirs are in PATH (script runs as root via sudo, which
    # may apply a restrictive secure_path depending on sudoers configuration).
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

    local _dest="${TNT_EXPORT_PATH%/}/${TNT_EXPORT_NAME}"
    local _type

    mkdir -p "$TNT_EXPORT_PATH"
    # Transfer directory ownership back to the invoking user so they can manage
    # the files (delete, move, etc.) without needing sudo.
    [[ -n "${SUDO_USER:-}" ]] && chown "$SUDO_USER:" "$TNT_EXPORT_PATH" 2>/dev/null

    for _type in ${TNT_EXPORT_TYPE:-text}; do
    case "$_type" in
        text)
            # Convert the raw ANSI capture to plain text.
            # Module headers are identified by the ESC[?9999h private-mode marker
            # that print_header() emits immediately before the gradient/compat bar.
            # Terminals silently ignore unknown ?-mode sequences, and the HTML/PS
            # converters already strip ESC[?...h/l automatically.
            #
            # awk runs inside an explicit subshell so its stdout is set with
            # exec BEFORE awk starts, guaranteeing the output goes to the report
            # file regardless of any fd inheritance from exec > >(tee ...).
            (
                exec 1>"${_dest}.txt" 2>/dev/null
                awk -v _W="${WIDTH:-100}" \
                'BEGIN { ESC = sprintf("%c", 27) }
                {
                    line = $0
                    if (line ~ (ESC "\\[\\?9999h")) {
                        clean = line
                        gsub(ESC "\\[[0-9;?]*[A-Za-z]", "", clean)
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", clean)
                        if (length(clean) > 0) {
                            hdr = "- " clean " "
                            rem = _W - length(hdr)
                            if (rem < 1) rem = 1
                            printf "%s", hdr
                            for (j = 0; j < rem; j++) printf "-"
                            printf "\n"
                        }
                    } else {
                        gsub(ESC "\\[[0-9;?]*[A-Za-z]", "", line)
                        print line
                    }
                }' "$_TNT_CAPTURE_FILE"
            ) && { _fix_export_perms "${_dest}.txt"
                   printf '\nExport saved:  %s.txt\n' "$_dest" >/dev/tty; } \
              || printf '\nExport failed: %s.txt\n' "$_dest" >/dev/tty
            ;;

        html)
            _ansi_to_html "$_TNT_CAPTURE_FILE" > "${_dest}.html" \
                && { _fix_export_perms "${_dest}.html"
                     printf '\nExport saved:  %s.html\n' "$_dest" >/dev/tty; } \
                || printf '\nExport failed: %s.html\n' "$_dest" >/dev/tty
            ;;

        pdf)
            if _generate_pdf_from_ps \
                    "$_TNT_CAPTURE_FILE" "${_dest}.pdf"; then
                _fix_export_perms "${_dest}.pdf"
                printf '\nExport saved:  %s.pdf\n' "$_dest" >/dev/tty
            else
                _ansi_to_html "$_TNT_CAPTURE_FILE" > "${_dest}.html"
                if _generate_pdf_from_html "${_dest}.html" "${_dest}.pdf"; then
                    rm -f "${_dest}.html"
                    _fix_export_perms "${_dest}.pdf"
                    printf '\nExport saved:  %s.pdf\n' "$_dest" >/dev/tty
                else
                    _fix_export_perms "${_dest}.html"
                    if command -v ps2pdf &>/dev/null; then
                        printf '\nWarning: ps2pdf conversion failed (see errors above); ' >/dev/tty
                        printf 'saved as HTML instead.\n' >/dev/tty
                    else
                        printf '\nWarning: no PDF generator found ' >/dev/tty
                        printf '(install ghostscript, wkhtmltopdf, or chromium)\n' >/dev/tty
                    fi
                    printf 'Export saved:  %s.html\n' "$_dest" >/dev/tty
                fi
            fi
            ;;
    esac
    done
}
