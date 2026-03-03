#!/usr/bin/env bash
# core/config.sh — Interactive configuration prompts for TNT Security Posture

# ── True Color detection ───────────────────────────────────────────────────────
# Sets TNT_TRUECOLOR=yes|no based on terminal capability signals.
# This must run before any 24-bit escape codes are emitted.
_detect_truecolor() {
    # If already set externally (e.g. a dev flag), honour it and skip probing.
    [[ -n "${TNT_TRUECOLOR:-}" ]] && return

    # COLORTERM is the most reliable signal — set by Kitty, Alacritty, WezTerm,
    # foot, and all modern VTE-based terminals (GNOME Terminal, Tilix, etc.)
    case "${COLORTERM:-}" in
        truecolor|24bit) TNT_TRUECOLOR=yes; export TNT_TRUECOLOR; return ;;
    esac

    # VTE-based terminals (GNOME Terminal ≥ 3.12, Tilix, XFCE Terminal)
    # set VTE_VERSION as an integer; True Color support arrived at 3600.
    if [[ -n "${VTE_VERSION:-}" ]] && (( VTE_VERSION >= 3600 )) 2>/dev/null; then
        TNT_TRUECOLOR=yes; export TNT_TRUECOLOR; return
    fi

    # Known True Color TERM_PROGRAM values
    case "${TERM_PROGRAM:-}" in
        iTerm.app|Hyper|WezTerm|mintty|vscode) TNT_TRUECOLOR=yes; export TNT_TRUECOLOR; return ;;
    esac

    # xterm-direct explicitly advertises direct-color (True Color) support
    case "${TERM:-}" in
        *direct*) TNT_TRUECOLOR=yes; export TNT_TRUECOLOR; return ;;
    esac

    TNT_TRUECOLOR=no
    export TNT_TRUECOLOR
}

# Returns the home directory of the actual invoking user.
# When run via sudo, $HOME is /root; SUDO_USER points to the real user.
_tnt_real_home() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || printf '%s' "$HOME"
    else
        printf '%s' "$HOME"
    fi
}

_prompt_config() {
    # Detect True Color capability first — this drives theme options and UI styling.
    _detect_truecolor

    # Resolve the real invoking user's home directory once for use as the default export path.
    local _real_home; _real_home="$(_tnt_real_home)"

    # ── Config file mode ──────────────────────────────────────────────────────
    # If --config / -c was passed on the command line, load values from the file
    # and skip all interactive prompts entirely.
    if [[ -n "${_TNT_CONFIG_FILE:-}" ]]; then
        _load_config_file "$_TNT_CONFIG_FILE"
        return
    fi

    # If stdin is not a tty (piped / redirected / no controlling terminal),
    # silently accept all defaults and return immediately.
    if [[ ! -t 0 ]]; then
        # Default theme: dark if TC available, compat if not (honour pre-set env var)
        if [[ -z "${TNT_THEME:-}" ]]; then
            [[ "$TNT_TRUECOLOR" == "yes" ]] && TNT_THEME=dark || TNT_THEME=compat
        fi
        TNT_ROLE=${TNT_ROLE:-Mixed}
        TNT_NETWORK=${TNT_NETWORK:-Internet-Facing}
        TNT_ADVERSARY=${TNT_ADVERSARY:-High}
        TNT_PHYSICAL=${TNT_PHYSICAL:-Untrusted}
        TNT_EXPORT=${TNT_EXPORT:-no}
        TNT_EXPORT_TYPE=${TNT_EXPORT_TYPE:-text}
        TNT_EXPORT_PATH=${TNT_EXPORT_PATH:-$_real_home}
        TNT_EXPORT_NAME=${TNT_EXPORT_NAME:-posture_$(date +%Y%m%d_%H%M)}
        TNT_EXPLAIN=${TNT_EXPLAIN:-no}
        TNT_BANNER=${TNT_BANNER:-yes}
        TNT_FULL_REPORT=${TNT_FULL_REPORT:-yes}
        export TNT_THEME TNT_ROLE TNT_NETWORK TNT_ADVERSARY TNT_PHYSICAL \
               TNT_EXPORT TNT_EXPORT_TYPE TNT_EXPORT_PATH TNT_EXPORT_NAME TNT_EXPLAIN TNT_BANNER TNT_FULL_REPORT
        # All modules enabled by default in non-interactive mode
        TNT_MOD_IDENTITY=yes TNT_MOD_HARDWARE=yes TNT_MOD_NETWORK=yes
        TNT_MOD_SSH=yes TNT_MOD_SECURITY=yes TNT_MOD_ATTACK_SURFACE=yes
        TNT_MOD_HW_SECURITY=yes TNT_MOD_USERS=yes TNT_MOD_FILESYSTEM=yes
        TNT_MOD_PACKAGES=yes TNT_MOD_AUTH_EVENTS=yes TNT_MOD_SCHEDULED=yes
        TNT_MOD_DOCKER=yes TNT_MOD_WEBSERVER=yes TNT_MOD_CPU_VULN=yes
        TNT_MOD_KERNEL=yes TNT_MOD_NTP=yes TNT_MOD_SUID=yes
        TNT_MOD_FIM=yes TNT_MOD_VPN=yes TNT_MOD_SUSPICIOUS=yes TNT_MOD_WORLD_WRITABLE=yes
        export TNT_MOD_IDENTITY TNT_MOD_HARDWARE TNT_MOD_NETWORK TNT_MOD_SSH \
               TNT_MOD_SECURITY TNT_MOD_ATTACK_SURFACE TNT_MOD_HW_SECURITY \
               TNT_MOD_USERS TNT_MOD_FILESYSTEM TNT_MOD_PACKAGES \
               TNT_MOD_AUTH_EVENTS TNT_MOD_SCHEDULED TNT_MOD_DOCKER \
               TNT_MOD_WEBSERVER TNT_MOD_CPU_VULN TNT_MOD_KERNEL TNT_MOD_NTP \
               TNT_MOD_SUID TNT_MOD_FIM TNT_MOD_VPN TNT_MOD_SUSPICIOUS TNT_MOD_WORLD_WRITABLE
        return
    fi

    # All prompts go to /dev/tty so the export redirect never captures them.
    exec 3>/dev/tty
    exec 4</dev/tty

    # ── UI color palette — adaptive: 24-bit if TC detected, ANSI-16 otherwise ──
    if [[ "$TNT_TRUECOLOR" == "yes" ]]; then
        _UI_BOX=$'\033[1;38;2;0;215;255m'
        _UI_TITLE=$'\033[1;38;2;255;200;0m'
        _UI_SEL=$'\033[1;38;2;0;215;255m'
        _UI_DIM=$'\033[38;2;150;150;150m'
        _UI_DIMGRAY=$'\033[38;2;100;100;100m'
        _UI_WARN=$'\033[1;38;2;255;165;0m'
        _UI_CHK=$'\033[1;38;2;80;220;80m'
    else
        _UI_BOX=$'\033[1;36m'
        _UI_TITLE=$'\033[1;33m'
        _UI_SEL=$'\033[1;36m'
        _UI_DIM=$'\033[0;37m'
        _UI_DIMGRAY=$'\033[0;37m'
        _UI_WARN=$'\033[1;33m'
        _UI_CHK=$'\033[1;32m'
    fi
    _UI_RST=$'\033[0m'

    # ── Module state — shared with _submenu_modules ───────────────────────────
    # Interleaved VAR_SUFFIX / Display Name pairs (same list as old _prompt_modules)
    local -a _mod_keys=(
        "IDENTITY"       "System Identity"
        "HARDWARE"       "Hardware & Virtualization"
        "NETWORK"        "Network Interfaces & Services"
        "SSH"            "SSH Hardening"
        "SECURITY"       "Logging & Protection"
        "ATTACK_SURFACE" "Attack Surface Density"
        "HW_SECURITY"    "Hardware Security"
        "USERS"          "Users & Privileges"
        "FILESYSTEM"     "Filesystem Security"
        "PACKAGES"       "Package & Update Posture"
        "AUTH_EVENTS"    "Authentication Events"
        "SCHEDULED"      "Scheduled Tasks"
        "DOCKER"         "Docker"
        "WEBSERVER"      "Web Server"
        "CPU_VULN"       "CPU Vulnerability Mitigations"
        "KERNEL"         "Kernel Hardening (sysctl)"
        "NTP"            "Time Sync & NTP"
        "SUID"           "SUID / SGID Binaries"
        "FIM"            "File Integrity Monitoring"
        "VPN"            "VPN Assessment"
        "SUSPICIOUS"     "Suspicious Process Indicators"
        "WORLD_WRITABLE" "World-Writable & Sticky Bit"
    )
    local _n_mods=$(( ${#_mod_keys[@]} / 2 ))
    local -a _mod_selected
    for (( _m=0; _m<_n_mods; _m++ )); do _mod_selected[$_m]=1; done

    # ── Dynamic theme discovery ───────────────────────────────────────────────
    # Scans themes/*.sh, excludes compat (TC fallback, not user-selectable),
    # and builds parallel display-name / value arrays used by the submenu and
    # the final value-extraction block below.
    local _cfg_dir
    _cfg_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    local _themes_dir="${_cfg_dir}/../themes"
    local -a _TC_THEME_VALS=() _TC_THEME_NAMES=()
    local _tfd _tfs _tfn
    for _tfd in "$_themes_dir"/*.sh; do
        _tfs="${_tfd##*/}"; _tfs="${_tfs%.sh}"
        [[ "$_tfs" == "compat" ]] && continue
        _TC_THEME_VALS+=("$_tfs")
        _TC_THEME_NAMES+=("${_tfs^}")
    done

    # ── Theme state — shared with _submenu_themes ────────────────────────────
    local _theme_idx=0   # index into _TC_THEME_VALS (TC only; ignored when compat)

    # ── Threshold state — shared with _submenu_thresholds ────────────────────
    local _thr_role=3    # 0=Desktop 1=Server 2=Hypervisor 3=Mixed
    local _thr_net=2     # 0=LAN-Only 1=VPN 2=Internet-Facing
    local _thr_adv=2     # 0=Low 1=Moderate 2=High
    local _thr_phys=2    # 0=Trusted 1=Semi-Trusted 2=Untrusted

    # ── Module Options state — shared with _submenu_mod_opts ─────────────────
    local _exp_idx=0     # 0=No 1=Yes (Explanations)
    local _ban_idx=0     # 0=Visible 1=Hidden (Banner)

    # ── Export state — shared with _submenu_export ────────────────────────────
    local _export_enabled="no"
    local _export_type="${TNT_EXPORT_TYPE:-text}"
    local _export_path="$_real_home"
    local _export_name="posture_$(date +%Y%m%d_%H%M)"

    # ── Row definitions ───────────────────────────────────────────────────────
    # Parallel arrays: label, option spec or sentinel, initial cursor index.
    # Sentinels:  ""                  → button row (Enter activates)
    #             "__sub_modules__"   → Full Report submenu (Enter navigates in)
    #             "__sub_export__"    → Export Report submenu (Enter navigates in)
    #             "__sub_thresholds__"→ Report Thresholds submenu
    #             "__sub_themes__"    → Themes submenu (TC only; grayed in compat)
    #             "__sub_mod_opts__"  → Module Options submenu
    local -a _rlabels _ropts _rcursors
    local _ri=0

    _rlabels[$_ri]="Themes:";             _ropts[$_ri]="__sub_themes__";      _rcursors[$_ri]=0; (( _ri++ ))
    _rlabels[$_ri]="Report Thresholds:";  _ropts[$_ri]="__sub_thresholds__";  _rcursors[$_ri]=0; (( _ri++ ))
    _rlabels[$_ri]="Module Options:";       _ropts[$_ri]="__sub_mod_opts__";    _rcursors[$_ri]=0; (( _ri++ ))
    _rlabels[$_ri]="Reporting Modules:";    _ropts[$_ri]="__sub_modules__";                  _rcursors[$_ri]=0; (( _ri++ ))
    _rlabels[$_ri]="Export Report:";        _ropts[$_ri]="__sub_export__";                   _rcursors[$_ri]=0; (( _ri++ ))
    _rlabels[$_ri]="[Generate Report]";     _ropts[$_ri]="";                                 _rcursors[$_ri]=0; (( _ri++ ))
    local _nrows=$_ri

    # ── Full-form redraw ──────────────────────────────────────────────────────
    _draw_config_form() {
        local _active_row=$1
        local _i _j _col

        printf '\033[2J\033[H' >&3
        _draw_banner 3 yes yes

        # Compat notice (shown when 24-bit color is unavailable)
        if [[ "$TNT_TRUECOLOR" != "yes" ]]; then
            printf "  ${_UI_WARN}Note:${_UI_RST} ${_UI_DIM}Truecolor not detected — compat theme applied.${_UI_RST}\n" >&3
        fi

        printf "  ${_UI_DIM}Choose your report options:${_UI_RST}\n" >&3
        printf "  ${_UI_DIM}←→ select  ↑↓ move  Enter navigate / open submenu${_UI_RST}\n\n" >&3

        for (( _i=0; _i<_nrows; _i++ )); do
            if [[ -z "${_ropts[$_i]}" ]]; then
                # ── Button row ─────────────────────────────────────────────
                printf "\n" >&3
                if (( _i == _active_row )); then
                    printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m%s\033[0m\n" "${_rlabels[$_i]}" >&3
                else
                    printf "     ${_UI_DIM}%s${_UI_RST}\n" "${_rlabels[$_i]}" >&3
                fi

            elif [[ "${_ropts[$_i]}" == "__sub_modules__" ]]; then
                # ── Full Report submenu nav row ────────────────────────────
                local _sc=0
                for (( _m=0; _m<_n_mods; _m++ )); do (( _mod_selected[_m] )) && (( _sc++ )); done
                local _msummary
                (( _sc == _n_mods )) && _msummary="All modules" || _msummary="${_sc}/${_n_mods} modules"
                if (( _i == _active_row )); then
                    printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m%-20s${_UI_SEL}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_msummary" >&3
                else
                    printf "     %-20s${_UI_DIM}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_msummary" >&3
                fi

            elif [[ "${_ropts[$_i]}" == "__sub_export__" ]]; then
                # ── Export Report submenu nav row ──────────────────────────
                local _esummary
                [[ "$_export_enabled" == "yes" ]] && _esummary="Enabled" || _esummary="Disabled"
                if (( _i == _active_row )); then
                    printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m%-20s${_UI_SEL}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_esummary" >&3
                else
                    printf "     %-20s${_UI_DIM}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_esummary" >&3
                fi

            elif [[ "${_ropts[$_i]}" == "__sub_thresholds__" ]]; then
                # ── Report Thresholds submenu nav row ──────────────────────
                local -a _tsrn=("Desktop" "Server" "Hypervisor" "Mixed")
                local -a _tsan=("Low" "Moderate" "High")
                local _tsummary="${_tsrn[$_thr_role]} · ${_tsan[$_thr_adv]}"
                if (( _i == _active_row )); then
                    printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m%-20s${_UI_SEL}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_tsummary" >&3
                else
                    printf "     %-20s${_UI_DIM}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_tsummary" >&3
                fi

            elif [[ "${_ropts[$_i]}" == "__sub_themes__" ]]; then
                # ── Themes submenu nav row — grayed/disabled in compat mode ──
                if [[ "$TNT_TRUECOLOR" == "yes" ]]; then
                    local _thsummary="${_TC_THEME_NAMES[$_theme_idx]}"
                    if (( _i == _active_row )); then
                        printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m%-20s${_UI_SEL}[ %s ▸ ]${_UI_RST}\n" \
                            "${_rlabels[$_i]}" "$_thsummary" >&3
                    else
                        printf "     %-20s${_UI_DIM}[ %s ▸ ]${_UI_RST}\n" \
                            "${_rlabels[$_i]}" "$_thsummary" >&3
                    fi
                else
                    if (( _i == _active_row )); then
                        printf "  ${_UI_SEL}▶${_UI_RST}  ${_UI_DIMGRAY}%-20s[ Compat — no truecolor ]${_UI_RST}\n" \
                            "${_rlabels[$_i]}" >&3
                    else
                        printf "     ${_UI_DIMGRAY}%-20s[ Compat — no truecolor ]${_UI_RST}\n" \
                            "${_rlabels[$_i]}" >&3
                    fi
                fi

            elif [[ "${_ropts[$_i]}" == "__sub_mod_opts__" ]]; then
                # ── Module Options submenu nav row ─────────────────────────
                local -a _expn=("No" "Yes")
                local -a _bann=("Visible" "Hidden")
                local _mosummary="Explanations: ${_expn[$_exp_idx]}  Banner: ${_bann[$_ban_idx]}"
                if (( _i == _active_row )); then
                    printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m%-20s${_UI_SEL}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_mosummary" >&3
                else
                    printf "     %-20s${_UI_DIM}[ %s ▸ ]${_UI_RST}\n" \
                        "${_rlabels[$_i]}" "$_mosummary" >&3
                fi

            else
                # ── Option row (left/right selectable) ────────────────────
                local -a _row_opts
                IFS='|' read -ra _row_opts <<< "${_ropts[$_i]}"
                _col=${_rcursors[$_i]}
                if (( _i == _active_row )); then
                    printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m%-20s\033[0m" "${_rlabels[$_i]}" >&3
                else
                    printf "     %-20s" "${_rlabels[$_i]}" >&3
                fi
                for (( _j=0; _j<${#_row_opts[@]}; _j++ )); do
                    if (( _j == _col )); then
                        printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_row_opts[$_j]}" >&3
                    else
                        printf "  ${_UI_DIMGRAY}%s${_UI_RST}" "${_row_opts[$_j]}" >&3
                    fi
                done
                printf "\n" >&3
            fi
        done
        printf "\n" >&3
    }

    # ── Full Report submenu ───────────────────────────────────────────────────
    # Presents the module checklist; [Continue] returns to main menu.
    # Reads/writes _mod_selected[] and _mod_keys[] from the outer scope.
    _submenu_modules() {
        local _sm_cursor=0

        _draw_modules_form() {
            printf '\033[2J\033[H' >&3
            _draw_banner 3 yes yes
            printf "  ${_UI_DIM}Choose which modules to include:${_UI_RST}\n" >&3
            printf "  ${_UI_DIM}↑↓ move  Space/←→ toggle  Enter jump to [Continue]${_UI_RST}\n\n" >&3
            local _m _mlabel _mchk _mlcolor
            for (( _m=0; _m<_n_mods; _m++ )); do
                _mlabel="${_mod_keys[$(( _m * 2 + 1 ))]}"
                if (( _mod_selected[_m] == 1 )); then
                    _mchk="${_UI_CHK}[✓]${_UI_RST}"; _mlcolor="${_UI_RST}"
                else
                    _mchk="${_UI_DIMGRAY}[ ]${_UI_RST}"; _mlcolor="${_UI_DIMGRAY}"
                fi
                if (( _m == _sm_cursor )); then
                    printf "  ${_UI_SEL}▶${_UI_RST} %s ${_mlcolor}%-36s${_UI_RST}\n" "$_mchk" "$_mlabel" >&3
                else
                    printf "    %s ${_mlcolor}%-36s${_UI_RST}\n" "$_mchk" "$_mlabel" >&3
                fi
            done
            printf '\n' >&3
            if (( _sm_cursor == _n_mods )); then
                printf "  ${_UI_SEL}▶${_UI_RST}  \033[1m[Continue]\033[0m\n" >&3
            else
                printf "     ${_UI_DIM}[Continue]${_UI_RST}\n" >&3
            fi
            printf '\n' >&3
        }

        _draw_modules_form
        local _sm_key _sm_esc
        while true; do
            IFS= read -r -s -n1 -t 60 _sm_key <&4
            case "$_sm_key" in
                '')   # Enter — exit on [Continue], otherwise jump to [Continue]
                    if (( _sm_cursor == _n_mods )); then
                        break
                    else
                        _sm_cursor=$_n_mods; _draw_modules_form
                    fi ;;
                ' ')  # Space — toggle
                    if (( _sm_cursor < _n_mods )); then
                        _mod_selected[$_sm_cursor]=$(( 1 - _mod_selected[$_sm_cursor] ))
                        _draw_modules_form
                    fi ;;
                $'\x1b')
                    IFS= read -r -s -n2 -t 0.1 _sm_esc <&4
                    case "$_sm_esc" in
                        '[A')  # Up — wrap from first item to [Continue]
                            if (( _sm_cursor == 0 )); then
                                _sm_cursor=$_n_mods
                            else
                                (( _sm_cursor-- ))
                            fi
                            _draw_modules_form ;;
                        '[B')  # Down — wrap from [Continue] to first item
                            if (( _sm_cursor == _n_mods )); then
                                _sm_cursor=0
                            else
                                (( _sm_cursor++ ))
                            fi
                            _draw_modules_form ;;
                        '[D')  # Left — disable
                            if (( _sm_cursor < _n_mods )); then
                                _mod_selected[$_sm_cursor]=0; _draw_modules_form
                            fi ;;
                        '[C')  # Right — enable
                            if (( _sm_cursor < _n_mods )); then
                                _mod_selected[$_sm_cursor]=1; _draw_modules_form
                            fi ;;
                    esac ;;
            esac
        done
    }

    # ── Export Report submenu ─────────────────────────────────────────────────
    # Rows: Enable (opt) | Type (opt) | File Name (text) | Directory (text) | [Continue]
    # Reads/writes _export_enabled, _export_type, _export_name, _export_path (outer scope).
    _submenu_export() {
        local -a _EO=("No" "Yes")               # Enable options
        local -a _TO=("Text" "HTML" "PDF")       # Type options
        local _ei; [[ "$_export_enabled" == "yes" ]] && _ei=1 || _ei=0
        # Check for PDF export dependencies (wkhtmltopdf, chromium family, weasyprint)
        local _pdf_avail=0
        { command -v ps2pdf || command -v wkhtmltopdf || command -v chromium || \
          command -v google-chrome || command -v chromium-browser || \
          command -v weasyprint; } &>/dev/null && _pdf_avail=1
        local _ti=0
        case "${_export_type:-text}" in html) _ti=1;; pdf) _ti=2;; esac
        (( ! _pdf_avail && _ti == 2 )) && _ti=1   # downgrade pdf→html if deps missing
        local _ex_name="$_export_name"
        local _ex_dir="$_export_path"
        local _ex_dir_orig="$_export_path"  # fallback when user declines dir creation
        local _ex_cur=0  # active row 0-4
        local _dir_pending=0  # 1 = entered dir doesn't exist, awaiting create confirm
        local _dir_create=0   # 0 = No, 1 = Yes (create the dir)

        # ── Draw the full export form ───────────────────────────────────────
        # $1 = active row  $2 = row currently in edit mode ("" = none)
        _draw_export_form() {
            local _ar=$1 _edit=${2:-""} _en=$(( _ei == 1 )) _i _j _ap
            printf '\033[2J\033[H' >&3
            _draw_banner 3 yes yes
            printf "  ${_UI_DIM}Configure export options:${_UI_RST}\n" >&3
            printf "  ${_UI_DIM}←→ select  ↑↓ move  Enter edit text / navigate${_UI_RST}\n\n" >&3

            for (( _i=0; _i<5; _i++ )); do
                (( _i == _ar )) && _ap="  ${_UI_SEL}▶${_UI_RST}  " || _ap="     "
                [[ -n "$_edit" && "$_edit" == "$_i" ]] && _ap="  ${_UI_SEL}*${_UI_RST}  "
                local _act=$(( _i == _ar ))
                case $_i in
                    0)  # Enable Export — always bright
                        (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Enable Export:" >&3 \
                                   || printf "%s%-22s" "$_ap" "Enable Export:" >&3
                        for (( _j=0; _j<2; _j++ )); do
                            (( _j == _ei )) \
                                && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_EO[$_j]}" >&3 \
                                || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_EO[$_j]}" >&3
                        done
                        printf "\n" >&3 ;;
                    1)  # Export Type — dimmed when export disabled
                        if (( _en )); then
                            (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Export Type:" >&3 \
                                       || printf "%s%-22s" "$_ap" "Export Type:" >&3
                            for (( _j=0; _j<2; _j++ )); do
                                (( _j == _ti )) \
                                    && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_TO[$_j]}" >&3 \
                                    || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_TO[$_j]}" >&3
                            done
                            if (( _pdf_avail )); then
                                (( _ti == 2 )) \
                                    && printf "  ${_UI_SEL}[ PDF ]${_UI_RST}" >&3 \
                                    || printf "  ${_UI_DIMGRAY}PDF${_UI_RST}" >&3
                            else
                                printf "  ${_UI_DIMGRAY}|  PDF ${_UI_WARN}(install ghostscript, wkhtmltopdf, or chromium)${_UI_RST}" >&3
                            fi
                            printf "\n" >&3
                        else
                            printf "%s${_UI_DIMGRAY}%-22s Text  HTML  PDF${_UI_RST}\n" "$_ap" "Export Type:" >&3
                        fi ;;
                    2)  # File Name — text field
                        local _ext2; case $_ti in 0) _ext2="txt";; 1) _ext2="html";; 2) _ext2="pdf";; esac
                        if (( _en )); then
                            if [[ "$_edit" == "2" ]]; then
                                # Inline editing: label + 2-space align + cursor-save + dim ext hint + cursor-restore
                                printf "%s\033[1m%-22s\033[0m  " "$_ap" "File Name:" >&3
                                printf '\033[s' >&3
                                printf " ${_UI_DIMGRAY}.%s${_UI_RST}" "$_ext2" >&3
                                printf '\033[u' >&3
                                return
                            elif (( _act )); then
                                printf "%s\033[1m%-22s${_UI_RST}  ${_UI_DIM}%s.%s${_UI_RST}\n" "$_ap" "File Name:" "$_ex_name" "$_ext2" >&3
                            else
                                printf "%s%-22s  ${_UI_DIM}%s.%s${_UI_RST}\n" "$_ap" "File Name:" "$_ex_name" "$_ext2" >&3
                            fi
                        else
                            printf "%s${_UI_DIMGRAY}%-22s %s.%s${_UI_RST}\n" "$_ap" "File Name:" "$_ex_name" "$_ext2" >&3
                        fi ;;
                    3)  # Save Directory — text field
                        if (( _en )); then
                            if [[ "$_edit" == "3" ]]; then
                                # Inline editing: label + 2-space align + cursor-save at value start
                                printf "%s\033[1m%-22s\033[0m  " "$_ap" "Save Directory:" >&3
                                printf '\033[s' >&3
                                return
                            elif (( _act )); then
                                printf "%s\033[1m%-22s${_UI_RST}  ${_UI_DIM}%s${_UI_RST}\n" "$_ap" "Save Directory:" "$_ex_dir" >&3
                            else
                                printf "%s%-22s  ${_UI_DIM}%s${_UI_RST}\n" "$_ap" "Save Directory:" "$_ex_dir" >&3
                            fi
                            # Create-pending prompt (only when dir doesn't exist and awaiting confirm)
                            if (( _dir_pending )); then
                                printf "     ${_UI_WARN}Directory does not exist! Create?${_UI_RST}" >&3
                                (( _dir_create == 0 )) \
                                    && printf "   ${_UI_SEL}[ No ]${_UI_RST}  ${_UI_DIM}Yes${_UI_RST}\n" >&3 \
                                    || printf "   ${_UI_DIMGRAY}No${_UI_RST}  ${_UI_SEL}[ Yes ]${_UI_RST}\n" >&3
                            fi
                        else
                            printf "%s${_UI_DIMGRAY}%-22s %s${_UI_RST}\n" "$_ap" "Save Directory:" "$_ex_dir" >&3
                        fi ;;
                    4)  # [Continue] button — hidden while create-dir decision is pending
                        (( _dir_pending )) && continue
                        printf "\n" >&3
                        (( _act )) && printf "%s\033[1m[Continue]\033[0m\n" "$_ap" >&3 \
                                   || printf "%s${_UI_DIM}[Continue]${_UI_RST}\n" "$_ap" >&3 ;;
                esac
            done
            printf "\n" >&3
        }

        # Teal→purple shifting colour for typed input (mirrors banner gradient palette)
        # Uses chars 0-19 as gradient steps; chars beyond 19 hold the purple end-colour.
        _render_input_colored() {
            local _s="$1" _n=${#1}
            (( _n == 0 )) && return
            if [[ "$TNT_TRUECOLOR" == "yes" ]]; then
                local _i _step _r _g _buf="" _ESC=$'\033['
                for (( _i=0; _i<_n; _i++ )); do
                    _step=$(( _i > 19 ? 19 : _i ))
                    _r=$(( 185 * _step / 19 ))
                    _g=$(( 215 - 135 * _step / 19 ))
                    _buf+="${_ESC}38;2;${_r};${_g};255m${_s:_i:1}"
                done
                printf '%s%s' "$_buf" "$_UI_RST"
            else
                printf '%s%s%s' "$_UI_SEL" "$_s" "$_UI_RST"
            fi
        }

        _draw_export_form $_ex_cur
        local _ex_key _ex_esc
        while true; do
            IFS= read -r -s -n1 -t 60 _ex_key <&4
            case "$_ex_key" in
                '')  # Enter
                    case $_ex_cur in
                        0|1)  # Opt rows — advance to next
                            (( _ex_cur < 4 )) && (( _ex_cur++ ))
                            (( ! _ei && _ex_cur >= 1 && _ex_cur <= 3 )) && _ex_cur=4
                            _draw_export_form $_ex_cur ;;
                        2)  # File Name — char-by-char inline edit; ext hint stays right
                            if (( _ei )); then
                                local _ext2; case $_ti in 0) _ext2="txt";; 1) _ext2="html";; 2) _ext2="pdf";; esac
                                _draw_export_form 2 "2"   # draws partial form, \033[s saved at value start
                                printf '\033[?25h' >&3
                                # Initial render: empty buffer + hint (cursor at col 29 via \033[u from draw)
                                printf '\033[K' >&3
                                printf " ${_UI_DIMGRAY}.%s${_UI_RST}" "$_ext2" >&3
                                printf '\033[%dD' $(( ${#_ext2} + 2 )) >&3
                                local _ibuf="" _ich _iesc
                                while true; do
                                    IFS= read -r -s -n1 -t 60 _ich <&4
                                    [[ $? -ne 0 ]] && break
                                    case "$_ich" in
                                        '')          break ;;
                                        $'\x7f'|$'\x08') [[ -n "$_ibuf" ]] && _ibuf="${_ibuf%?}" ;;
                                        $'\x1b')     IFS= read -r -s -n2 -t 0.1 _iesc <&4 ;;
                                        [[:print:]]) [[ ${#_ibuf} -lt 60 ]] && _ibuf+="$_ich" ;;
                                    esac
                                    printf '\033[u' >&3
                                    printf '\033[K' >&3
                                    _render_input_colored "$_ibuf" >&3
                                    printf " ${_UI_DIMGRAY}.%s${_UI_RST}" "$_ext2" >&3
                                    printf '\033[%dD' $(( ${#_ext2} + 2 )) >&3
                                done
                                printf '\033[?25l' >&3
                                if [[ -n "$_ibuf" ]]; then
                                    _ibuf="${_ibuf//[\/\\]}"
                                    _ibuf="${_ibuf//[[:cntrl:]]}"
                                    [[ -n "$_ibuf" ]] && _ex_name="$_ibuf"
                                fi
                                _draw_export_form $_ex_cur
                            fi ;;
                        3)  # Save Directory — char-by-char inline edit / create-dir confirm
                            if (( _ei )); then
                                if (( _dir_pending )); then
                                    # Confirm create-directory decision
                                    if (( _dir_create )); then
                                        if mkdir -p "$_ex_dir" 2>/dev/null; then
                                            # Restore ownership to the invoking user when run via sudo
                                            [[ -n "${SUDO_USER:-}" ]] && \
                                                chown "${SUDO_USER}:" "$_ex_dir" 2>/dev/null
                                            _dir_pending=0
                                        else
                                            _ex_dir="$_ex_dir_orig"
                                            _dir_pending=0
                                        fi
                                    else
                                        _ex_dir="$_ex_dir_orig"  # user said No — restore default
                                        _dir_pending=0
                                    fi
                                    _draw_export_form $_ex_cur
                                else
                                _draw_export_form 3 "3"
                                printf '\033[?25h' >&3
                                # Initial render: empty buffer at cursor-saved position
                                printf '\033[K' >&3
                                local _dbuf="" _dch _desc
                                while true; do
                                    IFS= read -r -s -n1 -t 60 _dch <&4
                                    [[ $? -ne 0 ]] && break
                                    case "$_dch" in
                                        '')  # Enter — validate
                                            if [[ -z "$_dbuf" ]]; then
                                                break  # keep current
                                            elif [[ -e "$_dbuf" && ! -d "$_dbuf" ]]; then
                                                printf "\n  ${_UI_WARN}%s is not a directory — enter new path:${_UI_RST}  " \
                                                    "$_dbuf" >&3
                                                printf '\033[s' >&3
                                                _dbuf=""
                                            elif [[ -d "$_dbuf" ]]; then
                                                _ex_dir="$_dbuf"
                                                break
                                            else
                                                # Path doesn't exist — save and show create prompt
                                                _ex_dir="$_dbuf"
                                                _dir_pending=1
                                                _dir_create=0
                                                break
                                            fi ;;
                                        $'\x7f'|$'\x08') [[ -n "$_dbuf" ]] && _dbuf="${_dbuf%?}" ;;
                                        $'\x1b')     IFS= read -r -s -n2 -t 0.1 _desc <&4 ;;
                                        [[:print:]]) [[ ${#_dbuf} -lt 120 ]] && _dbuf+="$_dch" ;;
                                    esac
                                    printf '\033[u' >&3
                                    printf '\033[K' >&3
                                    _render_input_colored "$_dbuf" >&3
                                done
                                printf '\033[?25l' >&3
                                _draw_export_form $_ex_cur
                                fi  # end: else (not _dir_pending)
                            fi ;;
                        4)  break ;;  # [Continue] — exit submenu
                    esac ;;
                $'\x1b')
                    IFS= read -r -s -n2 -t 0.1 _ex_esc <&4
                    case "$_ex_esc" in
                        '[A')
                            (( _ex_cur > 0 )) && (( _ex_cur-- ))
                            (( ! _ei && _ex_cur >= 1 && _ex_cur <= 3 )) && _ex_cur=0
                            (( _dir_pending )) && _ex_cur=3   # locked to row 3 while create prompt visible
                            _draw_export_form $_ex_cur ;;
                        '[B')
                            (( _ex_cur < 4 )) && (( _ex_cur++ ))
                            (( ! _ei && _ex_cur >= 1 && _ex_cur <= 3 )) && _ex_cur=4
                            (( _dir_pending )) && _ex_cur=3   # locked to row 3 while create prompt visible
                            _draw_export_form $_ex_cur ;;
                        '[D')  # Left — opt rows and create-dir confirm
                            case $_ex_cur in
                                0) (( _ei > 0 )) && (( _ei-- )); _draw_export_form $_ex_cur ;;
                                1) (( _ti > 0 )) && (( _ti-- )); _draw_export_form $_ex_cur ;;
                                3) (( _dir_pending && _dir_create > 0 )) && (( _dir_create-- )); _draw_export_form $_ex_cur ;;
                            esac ;;
                        '[C')  # Right — opt rows and create-dir confirm
                            case $_ex_cur in
                                0) (( _ei < 1 )) && (( _ei++ )); _draw_export_form $_ex_cur ;;
                                1) (( _ti < (_pdf_avail ? 2 : 1) )) && (( _ti++ )); _draw_export_form $_ex_cur ;;
                                3) (( _dir_pending && _dir_create < 1 )) && (( _dir_create++ )); _draw_export_form $_ex_cur ;;
                            esac ;;
                    esac ;;
            esac
        done

        # Write state back to outer scope
        (( _ei == 1 )) && _export_enabled="yes" || _export_enabled="no"
        case $_ti in 0) _export_type="text";; 1) _export_type="html";; 2) _export_type="pdf";; esac
        _export_name="$_ex_name"
        _export_path="$_ex_dir"
    }

    # ── Themes submenu ────────────────────────────────────────────────────────
    # TC-only: presents Dark / Light selection + [Continue].
    # Reads/writes _theme_idx from the outer scope.
    _submenu_themes() {
        local -a _TH=("${_TC_THEME_NAMES[@]}")
        local _ttc=0  # active row: 0=Theme option, 1=[Continue]

        _draw_themes_form() {
            local _ar=$1 _j _ap
            printf '\033[2J\033[H' >&3
            _draw_banner 3 yes yes
            printf "  ${_UI_DIM}Select display theme:${_UI_RST}\n" >&3
            printf "  ${_UI_DIM}←→ select  ↑↓ move  Enter navigate${_UI_RST}\n\n" >&3

            # Row 0: Theme option
            (( _ar == 0 )) && _ap="  ${_UI_SEL}▶${_UI_RST}  " || _ap="     "
            local _act=$(( _ar == 0 ))
            (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Theme:" >&3 \
                       || printf "%s%-22s" "$_ap" "Theme:" >&3
            for (( _j=0; _j<${#_TH[@]}; _j++ )); do
                (( _j == _theme_idx )) \
                    && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_TH[$_j]}" >&3 \
                    || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_TH[$_j]}" >&3
            done
            printf "\n\n" >&3

            # Row 1: [Continue]
            (( _ar == 1 )) && _ap="  ${_UI_SEL}▶${_UI_RST}  " || _ap="     "
            (( _ar == 1 )) && printf "%s\033[1m[Continue]\033[0m\n" "$_ap" >&3 \
                           || printf "%s${_UI_DIM}[Continue]${_UI_RST}\n" "$_ap" >&3
            printf "\n" >&3
        }

        _draw_themes_form $_ttc
        local _ttk _ttesc
        while true; do
            IFS= read -r -s -n1 -t 60 _ttk <&4
            case "$_ttk" in
                '')  # Enter — advance or exit on [Continue]
                    if (( _ttc == 1 )); then break
                    else (( _ttc++ )); _draw_themes_form $_ttc; fi ;;
                $'\x1b')
                    IFS= read -r -s -n2 -t 0.1 _ttesc <&4
                    case "$_ttesc" in
                        '[A')  # Up — wrap
                            if (( _ttc == 0 )); then _ttc=1; else _ttc=0; fi
                            _draw_themes_form $_ttc ;;
                        '[B')  # Down — wrap
                            if (( _ttc == 1 )); then _ttc=0; else _ttc=1; fi
                            _draw_themes_form $_ttc ;;
                        '[D')  # Left
                            (( _ttc == 0 && _theme_idx > 0 )) && (( _theme_idx-- ))
                            _draw_themes_form $_ttc ;;
                        '[C')  # Right
                            (( _ttc == 0 && _theme_idx < ${#_TH[@]} - 1 )) && (( _theme_idx++ ))
                            _draw_themes_form $_ttc ;;
                    esac ;;
            esac
        done
    }

    # ── Report Thresholds submenu ─────────────────────────────────────────────
    # Presents System Role, Network Exposure, Adversary Model, Physical Access.
    # Reads/writes _thr_role, _thr_net, _thr_adv, _thr_phys from the outer scope.
    _submenu_thresholds() {
        local -a _TR=("Desktop" "Server" "Hypervisor" "Mixed")
        local -a _TN=("LAN-Only" "VPN" "Internet-Facing")
        local -a _TA=("Low" "Moderate" "High")
        local -a _TP=("Trusted" "Semi-Trusted" "Untrusted")
        local _tc=0  # active row 0–4

        _draw_thresholds_form() {
            local _ar=$1 _i _j _ap _act
            printf '\033[2J\033[H' >&3
            _draw_banner 3 yes yes
            printf "  ${_UI_DIM}Configure threat model and trust parameters:${_UI_RST}\n" >&3
            printf "  ${_UI_DIM}←→ select  ↑↓ move  Enter navigate${_UI_RST}\n\n" >&3

            for (( _i=0; _i<5; _i++ )); do
                (( _i == _ar )) && _ap="  ${_UI_SEL}▶${_UI_RST}  " || _ap="     "
                local _act=$(( _i == _ar ))
                case $_i in
                    0)  # System Role
                        (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "System Role:" >&3 \
                                   || printf "%s%-22s" "$_ap" "System Role:" >&3
                        for (( _j=0; _j<${#_TR[@]}; _j++ )); do
                            (( _j == _thr_role )) \
                                && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_TR[$_j]}" >&3 \
                                || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_TR[$_j]}" >&3
                        done
                        printf "\n" >&3 ;;
                    1)  # Network Exposure
                        (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Network Exposure:" >&3 \
                                   || printf "%s%-22s" "$_ap" "Network Exposure:" >&3
                        for (( _j=0; _j<${#_TN[@]}; _j++ )); do
                            (( _j == _thr_net )) \
                                && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_TN[$_j]}" >&3 \
                                || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_TN[$_j]}" >&3
                        done
                        printf "\n" >&3 ;;
                    2)  # Adversary Model
                        (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Adversary Model:" >&3 \
                                   || printf "%s%-22s" "$_ap" "Adversary Model:" >&3
                        for (( _j=0; _j<${#_TA[@]}; _j++ )); do
                            (( _j == _thr_adv )) \
                                && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_TA[$_j]}" >&3 \
                                || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_TA[$_j]}" >&3
                        done
                        printf "\n" >&3 ;;
                    3)  # Physical Access
                        (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Physical Access:" >&3 \
                                   || printf "%s%-22s" "$_ap" "Physical Access:" >&3
                        for (( _j=0; _j<${#_TP[@]}; _j++ )); do
                            (( _j == _thr_phys )) \
                                && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_TP[$_j]}" >&3 \
                                || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_TP[$_j]}" >&3
                        done
                        printf "\n" >&3 ;;
                    4)  # [Continue]
                        printf "\n" >&3
                        (( _act )) && printf "%s\033[1m[Continue]\033[0m\n" "$_ap" >&3 \
                                   || printf "%s${_UI_DIM}[Continue]${_UI_RST}\n" "$_ap" >&3 ;;
                esac
            done
            printf "\n" >&3
        }

        _draw_thresholds_form $_tc
        local _tk _tesc
        while true; do
            IFS= read -r -s -n1 -t 60 _tk <&4
            case "$_tk" in
                '')  # Enter — advance or exit on [Continue]
                    if (( _tc == 4 )); then
                        break
                    else
                        (( _tc++ ))
                        _draw_thresholds_form $_tc
                    fi ;;
                $'\x1b')
                    IFS= read -r -s -n2 -t 0.1 _tesc <&4
                    case "$_tesc" in
                        '[A')  # Up — wrap
                            if (( _tc == 0 )); then _tc=4; else (( _tc-- )); fi
                            _draw_thresholds_form $_tc ;;
                        '[B')  # Down — wrap
                            if (( _tc == 4 )); then _tc=0; else (( _tc++ )); fi
                            _draw_thresholds_form $_tc ;;
                        '[D')  # Left
                            case $_tc in
                                0) (( _thr_role > 0 )) && (( _thr_role-- )) ;;
                                1) (( _thr_net  > 0 )) && (( _thr_net--  )) ;;
                                2) (( _thr_adv  > 0 )) && (( _thr_adv--  )) ;;
                                3) (( _thr_phys > 0 )) && (( _thr_phys-- )) ;;
                            esac
                            _draw_thresholds_form $_tc ;;
                        '[C')  # Right
                            case $_tc in
                                0) (( _thr_role < 3 )) && (( _thr_role++ )) ;;
                                1) (( _thr_net  < 2 )) && (( _thr_net++  )) ;;
                                2) (( _thr_adv  < 2 )) && (( _thr_adv++  )) ;;
                                3) (( _thr_phys < 2 )) && (( _thr_phys++ )) ;;
                            esac
                            _draw_thresholds_form $_tc ;;
                    esac ;;
            esac
        done
    }

    # ── Module Options submenu ────────────────────────────────────────────────
    # Presents Explanations and Banner toggles.
    # Reads/writes _exp_idx and _ban_idx from the outer scope.
    _submenu_mod_opts() {
        local -a _EX=("No" "Yes")
        local -a _BN=("Visible" "Hidden")
        local _mc=0  # active row: 0=Explanations, 1=Banner, 2=[Continue]

        _draw_mod_opts_form() {
            local _ar=$1 _j _ap _act
            printf '\033[2J\033[H' >&3
            _draw_banner 3 yes yes
            printf "  ${_UI_DIM}Configure module behaviour options:${_UI_RST}\n" >&3
            printf "  ${_UI_DIM}←→ select  ↑↓ move  Enter navigate${_UI_RST}\n\n" >&3

            for (( _i=0; _i<3; _i++ )); do
                (( _i == _ar )) && _ap="  ${_UI_SEL}▶${_UI_RST}  " || _ap="     "
                local _act=$(( _i == _ar ))
                case $_i in
                    0)  # Explanations
                        (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Explanations:" >&3 \
                                   || printf "%s%-22s" "$_ap" "Explanations:" >&3
                        for (( _j=0; _j<${#_EX[@]}; _j++ )); do
                            (( _j == _exp_idx )) \
                                && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_EX[$_j]}" >&3 \
                                || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_EX[$_j]}" >&3
                        done
                        printf "\n" >&3 ;;
                    1)  # Banner
                        (( _act )) && printf "%s\033[1m%-22s\033[0m" "$_ap" "Banner:" >&3 \
                                   || printf "%s%-22s" "$_ap" "Banner:" >&3
                        for (( _j=0; _j<${#_BN[@]}; _j++ )); do
                            (( _j == _ban_idx )) \
                                && printf "  ${_UI_SEL}[ %s ]${_UI_RST}" "${_BN[$_j]}" >&3 \
                                || printf "  ${_UI_DIMGRAY}%s${_UI_RST}"  "${_BN[$_j]}" >&3
                        done
                        printf "\n" >&3 ;;
                    2)  # [Continue]
                        printf "\n" >&3
                        (( _act )) && printf "%s\033[1m[Continue]\033[0m\n" "$_ap" >&3 \
                                   || printf "%s${_UI_DIM}[Continue]${_UI_RST}\n" "$_ap" >&3 ;;
                esac
            done
            printf "\n" >&3
        }

        _draw_mod_opts_form $_mc
        local _mk _mesc
        while true; do
            IFS= read -r -s -n1 -t 60 _mk <&4
            case "$_mk" in
                '')  # Enter — advance or exit on [Continue]
                    if (( _mc == 2 )); then
                        break
                    else
                        (( _mc++ ))
                        _draw_mod_opts_form $_mc
                    fi ;;
                $'\x1b')
                    IFS= read -r -s -n2 -t 0.1 _mesc <&4
                    case "$_mesc" in
                        '[A')  # Up — wrap
                            if (( _mc == 0 )); then _mc=2; else (( _mc-- )); fi
                            _draw_mod_opts_form $_mc ;;
                        '[B')  # Down — wrap
                            if (( _mc == 2 )); then _mc=0; else (( _mc++ )); fi
                            _draw_mod_opts_form $_mc ;;
                        '[D')  # Left
                            (( _mc == 0 && _exp_idx > 0 )) && (( _exp_idx-- ))
                            (( _mc == 1 && _ban_idx > 0 )) && (( _ban_idx-- ))
                            _draw_mod_opts_form $_mc ;;
                        '[C')  # Right
                            (( _mc == 0 && _exp_idx < 1 )) && (( _exp_idx++ ))
                            (( _mc == 1 && _ban_idx < 1 )) && (( _ban_idx++ ))
                            _draw_mod_opts_form $_mc ;;
                    esac ;;
            esac
        done
    }

    # ── Form navigation loop ──────────────────────────────────────────────────
    local _active=0 _key _esc
    printf '\033[?25l' >&3
    _draw_config_form $_active

    while true; do
        IFS= read -r -s -n1 -t 60 _key <&4
        case "$_key" in
            '')  # Enter — button exits, submenus navigate in, options advance
                if [[ -z "${_ropts[$_active]}" ]]; then
                    break  # [Generate Report]
                elif [[ "${_ropts[$_active]}" == "__sub_modules__" ]]; then
                    _submenu_modules
                    _draw_config_form $_active
                elif [[ "${_ropts[$_active]}" == "__sub_export__" ]]; then
                    _submenu_export
                    _draw_config_form $_active
                elif [[ "${_ropts[$_active]}" == "__sub_thresholds__" ]]; then
                    _submenu_thresholds
                    _draw_config_form $_active
                elif [[ "${_ropts[$_active]}" == "__sub_themes__" ]]; then
                    if [[ "$TNT_TRUECOLOR" == "yes" ]]; then
                        _submenu_themes
                        _draw_config_form $_active
                    else
                        # Compat — row is disabled; advance past it
                        (( _active < _nrows - 1 )) && { (( _active++ )); _draw_config_form $_active; }
                    fi
                elif [[ "${_ropts[$_active]}" == "__sub_mod_opts__" ]]; then
                    _submenu_mod_opts
                    _draw_config_form $_active
                elif (( _active < _nrows - 1 )); then
                    (( _active++ ))
                    _draw_config_form $_active
                fi
                ;;
            $'\x1b')
                IFS= read -r -s -n2 -t 0.1 _esc <&4
                case "$_esc" in
                    '[A')  # Up — wrap from first row to last
                        if (( _active == 0 )); then
                            _active=$(( _nrows - 1 ))
                        else
                            (( _active-- ))
                        fi
                        _draw_config_form $_active ;;
                    '[B')  # Down — wrap from last row to first
                        if (( _active == _nrows - 1 )); then
                            _active=0
                        else
                            (( _active++ ))
                        fi
                        _draw_config_form $_active ;;
                    '[D')  # Left — only on selectable option rows
                        if [[ -n "${_ropts[$_active]}" && "${_ropts[$_active]}" != "__sub_"* ]]; then
                            local _nc=${_rcursors[$_active]}
                            (( _nc > 0 )) && _rcursors[$_active]=$(( _nc - 1 ))
                            _draw_config_form $_active
                        fi ;;
                    '[C')  # Right — only on selectable option rows
                        if [[ -n "${_ropts[$_active]}" && "${_ropts[$_active]}" != "__sub_"* ]]; then
                            local -a _cur_opts
                            IFS='|' read -ra _cur_opts <<< "${_ropts[$_active]}"
                            local _nc=${_rcursors[$_active]}
                            (( _nc < ${#_cur_opts[@]} - 1 )) && _rcursors[$_active]=$(( _nc + 1 ))
                            _draw_config_form $_active
                        fi ;;
                esac ;;
        esac
    done

    printf '\033[?25h' >&3

    # ── Extract selected values from final cursor positions ───────────────────
    local _ri2=0
    local -a _row_opts

    # Theme: from submenu state (TC) or forced compat; skip __sub_themes__ row
    if [[ "$TNT_TRUECOLOR" == "yes" ]]; then
        TNT_THEME="${_TC_THEME_VALS[$_theme_idx]}"
    else
        TNT_THEME=compat
    fi
    (( _ri2++ ))  # advance past __sub_themes__ row
    # Threshold values come from submenu state; skip __sub_thresholds__ row
    local -a _role_vals=("Desktop" "Server" "Hypervisor" "Mixed")
    local -a _net_vals=("LAN-Only" "VPN" "Internet-Facing")
    local -a _adv_vals=("Low" "Moderate" "High")
    local -a _phys_vals=("Trusted" "Semi-Trusted" "Untrusted")
    TNT_ROLE="${_role_vals[$_thr_role]}"
    TNT_NETWORK="${_net_vals[$_thr_net]}"
    TNT_ADVERSARY="${_adv_vals[$_thr_adv]}"
    TNT_PHYSICAL="${_phys_vals[$_thr_phys]}"
    (( _ri2++ ))  # advance past __sub_thresholds__ row
    # Module Options: Explanations and Banner from submenu state; skip __sub_mod_opts__ row
    local -a _exp_vals=("no" "yes")
    local -a _ban_vals=("yes" "no")   # 0=Visible→yes, 1=Hidden→no
    TNT_EXPLAIN="${_exp_vals[$_exp_idx]}"
    TNT_BANNER="${_ban_vals[$_ban_idx]}"
    (( _ri2++ ))  # advance past __sub_mod_opts__ row
    # Remaining rows are __sub_modules__, __sub_export__, and [Generate Report] —
    # their state comes from _mod_selected[] and _export_* locals, not _rcursors.

    # ── Module selections → TNT_MOD_* ────────────────────────────────────────
    local _m _mvar
    for (( _m=0; _m<_n_mods; _m++ )); do
        _mvar="${_mod_keys[$(( _m * 2 ))]}"
        if (( _mod_selected[_m] == 1 )); then
            eval "TNT_MOD_${_mvar}=yes"
        else
            eval "TNT_MOD_${_mvar}=no"
        fi
    done

    # ── Full report flag — yes only when every module is enabled ─────────────
    local _all_on=1
    for (( _m=0; _m<_n_mods; _m++ )); do
        (( _mod_selected[_m] )) || { _all_on=0; break; }
    done
    (( _all_on )) && TNT_FULL_REPORT=yes || TNT_FULL_REPORT=no

    # ── Export settings from submenu state ───────────────────────────────────
    TNT_EXPORT="$_export_enabled"
    TNT_EXPORT_TYPE="$_export_type"
    TNT_EXPORT_PATH="$_export_path"
    TNT_EXPORT_NAME="$_export_name"

    exec 3>&-
    exec 4<&-

    export TNT_THEME TNT_ROLE TNT_NETWORK TNT_ADVERSARY TNT_PHYSICAL \
           TNT_EXPORT TNT_EXPORT_TYPE TNT_EXPORT_PATH TNT_EXPORT_NAME TNT_EXPLAIN TNT_BANNER TNT_FULL_REPORT
    export TNT_MOD_IDENTITY TNT_MOD_HARDWARE TNT_MOD_NETWORK TNT_MOD_SSH \
           TNT_MOD_SECURITY TNT_MOD_ATTACK_SURFACE TNT_MOD_HW_SECURITY \
           TNT_MOD_USERS TNT_MOD_FILESYSTEM TNT_MOD_PACKAGES \
           TNT_MOD_AUTH_EVENTS TNT_MOD_SCHEDULED TNT_MOD_DOCKER \
           TNT_MOD_WEBSERVER TNT_MOD_CPU_VULN TNT_MOD_KERNEL TNT_MOD_NTP \
           TNT_MOD_SUID TNT_MOD_FIM TNT_MOD_VPN TNT_MOD_SUSPICIOUS TNT_MOD_WORLD_WRITABLE
}

# ── Module selection prompt ────────────────────────────────────────────────────
# Module selection is now handled inside _prompt_config via the Full Report
# submenu. TNT_MOD_* variables are already exported when this is called.
_prompt_modules() { return; }

# ── Config file loader ────────────────────────────────────────────────────────
# Sources a user-supplied config file and exports all TNT_* variables.
# Called from _prompt_config when --config / -c is passed to posture.sh.
#
# Module selection via TNT_MODULES (set in the config file):
#   TNT_MODULES=all              — run every module
#   TNT_MODULES=full             — alias for all
#   TNT_MODULES="ssh kernel vpn" — run only the named modules (space or comma separated)
#
# Available module names (case-insensitive):
#   identity  hardware  network  ssh  security  attack_surface  hw_security
#   users  filesystem  packages  auth_events  scheduled  docker  webserver
#   cpu_vuln  kernel  ntp  suid  fim  vpn  suspicious  world_writable
_load_config_file() {
    local _cfg="$1"
    local _real_home; _real_home="$(_tnt_real_home)"

    if [[ ! -f "$_cfg" ]]; then
        printf 'posture: config file not found: %s\n' "$_cfg" >&2; exit 1
    fi
    if [[ ! -r "$_cfg" ]]; then
        printf 'posture: config file not readable: %s\n' "$_cfg" >&2; exit 1
    fi

    # Source the file — variables it sets (TNT_THEME, TNT_ROLE, TNT_MODULES …)
    # land in the global shell scope.
    # shellcheck source=/dev/null
    source "$_cfg" || { printf 'posture: error in config file: %s\n' "$_cfg" >&2; exit 1; }

    # ── Theme ─────────────────────────────────────────────────────────────────
    if [[ -z "${TNT_THEME:-}" ]]; then
        [[ "$TNT_TRUECOLOR" == "yes" ]] && TNT_THEME=dark || TNT_THEME=compat
    else
        TNT_THEME="${TNT_THEME,,}"
        # If the selected theme requires True Color but the terminal can't supply
        # it, fall back early (theme.sh would catch this too, but warn here).
        local _lcfg_dir _lcfg_tfile
        _lcfg_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
        _lcfg_tfile="${_lcfg_dir}/../themes/${TNT_THEME}.sh"
        if grep -q 'THEME_TIER="truecolor"' "$_lcfg_tfile" 2>/dev/null \
                && [[ "$TNT_TRUECOLOR" != "yes" ]]; then
            printf 'posture: terminal lacks True Color; falling back to compat theme\n' >&2
            TNT_THEME=compat
        fi
    fi

    # ── Deployment context ────────────────────────────────────────────────────
    TNT_ROLE="${TNT_ROLE:-Mixed}"
    TNT_NETWORK="${TNT_NETWORK:-Internet-Facing}"
    TNT_ADVERSARY="${TNT_ADVERSARY:-High}"
    TNT_PHYSICAL="${TNT_PHYSICAL:-Untrusted}"

    # ── Report options ────────────────────────────────────────────────────────
    TNT_EXPLAIN="${TNT_EXPLAIN:-no}"; TNT_EXPLAIN="${TNT_EXPLAIN,,}"
    TNT_BANNER="${TNT_BANNER:-yes}";  TNT_BANNER="${TNT_BANNER,,}"
    TNT_EXPORT="${TNT_EXPORT:-no}";   TNT_EXPORT="${TNT_EXPORT,,}"
    # TNT_EXPORT_TYPE may be a multi-word value (e.g. "text html pdf").  When bash
    # sources a line like  TNT_EXPORT_TYPE=text html pdf  (no quotes), it treats
    # "html pdf" as a command to execute rather than part of the assignment, so the
    # variable is never set correctly.  Re-read the raw line from the config file
    # and set the variable ourselves — this handles both quoted and unquoted forms.
    local _raw_et
    _raw_et=$(grep -m1 '^[[:space:]]*TNT_EXPORT_TYPE[[:space:]]*=' "$_cfg" \
              | sed 's/^[^=]*=//; s/[[:space:]]*#.*//')
    if [[ -n "$_raw_et" ]]; then
        _raw_et="${_raw_et#[\"\']}"; _raw_et="${_raw_et%[\"\']}"
        TNT_EXPORT_TYPE="$_raw_et"
    fi
    # Normalize export type: lowercase, treat commas/spaces as separators, validate tokens.
    # Supports multi-type values from config files, e.g. "text, html, pdf" or "text pdf".
    TNT_EXPORT_TYPE="${TNT_EXPORT_TYPE:-text}"
    TNT_EXPORT_TYPE="${TNT_EXPORT_TYPE,,}"
    TNT_EXPORT_TYPE="${TNT_EXPORT_TYPE//,/ }"
    local _valid_types="" _et
    for _et in $TNT_EXPORT_TYPE; do
        case "$_et" in text|html|pdf) _valid_types+="$_et ";; esac
    done
    TNT_EXPORT_TYPE="${_valid_types% }"
    [[ -z "$TNT_EXPORT_TYPE" ]] && TNT_EXPORT_TYPE="text"
    TNT_EXPORT_PATH="${TNT_EXPORT_PATH:-$_real_home}"
    # Strip any file extension from the name — the correct one is added at export time
    TNT_EXPORT_NAME="${TNT_EXPORT_NAME:-posture_$(date +%Y%m%d_%H%M)}"
    TNT_EXPORT_NAME="${TNT_EXPORT_NAME%.txt}"; TNT_EXPORT_NAME="${TNT_EXPORT_NAME%.html}"; TNT_EXPORT_NAME="${TNT_EXPORT_NAME%.pdf}"

    # ── Module selection ──────────────────────────────────────────────────────
    local -a _all_mod_keys=(
        IDENTITY HARDWARE NETWORK SSH SECURITY ATTACK_SURFACE
        HW_SECURITY USERS FILESYSTEM PACKAGES AUTH_EVENTS SCHEDULED
        DOCKER WEBSERVER CPU_VULN KERNEL NTP SUID FIM VPN SUSPICIOUS WORLD_WRITABLE
    )

    local _mods="${TNT_MODULES:-all}"
    _mods="${_mods,,}"          # lowercase
    _mods="${_mods//,/ }"       # commas → spaces

    if [[ "$_mods" == "all" || "$_mods" == "full" ]]; then
        TNT_FULL_REPORT=yes
        for _k in "${_all_mod_keys[@]}"; do eval "TNT_MOD_${_k}=yes"; done
    else
        TNT_FULL_REPORT=no
        # Default everything off, then enable requested modules
        for _k in "${_all_mod_keys[@]}"; do eval "TNT_MOD_${_k}=no"; done

        local _m _upper
        for _m in $_mods; do
            _upper="${_m//-/_}"     # allow hyphens as alternative separator
            _upper="${_upper^^}"    # uppercase: ssh → SSH, attack_surface → ATTACK_SURFACE
            # Validate against known list
            local _valid=0
            for _k in "${_all_mod_keys[@]}"; do
                [[ "$_k" == "$_upper" ]] && _valid=1 && break
            done
            if (( _valid )); then
                eval "TNT_MOD_${_upper}=yes"
            else
                printf 'posture: unknown module "%s" in TNT_MODULES — ignored\n' "$_m" >&2
            fi
        done

        # If every module ended up enabled, mark as full report
        local _all_on=1 _v
        for _k in "${_all_mod_keys[@]}"; do
            eval "_v=\${TNT_MOD_${_k}}"
            [[ "$_v" != "yes" ]] && _all_on=0 && break
        done
        (( _all_on )) && TNT_FULL_REPORT=yes
    fi

    export TNT_THEME TNT_ROLE TNT_NETWORK TNT_ADVERSARY TNT_PHYSICAL \
           TNT_EXPORT TNT_EXPORT_TYPE TNT_EXPORT_PATH TNT_EXPORT_NAME TNT_EXPLAIN TNT_BANNER TNT_FULL_REPORT
    export TNT_MOD_IDENTITY TNT_MOD_HARDWARE TNT_MOD_NETWORK TNT_MOD_SSH \
           TNT_MOD_SECURITY TNT_MOD_ATTACK_SURFACE TNT_MOD_HW_SECURITY \
           TNT_MOD_USERS TNT_MOD_FILESYSTEM TNT_MOD_PACKAGES \
           TNT_MOD_AUTH_EVENTS TNT_MOD_SCHEDULED TNT_MOD_DOCKER \
           TNT_MOD_WEBSERVER TNT_MOD_CPU_VULN TNT_MOD_KERNEL TNT_MOD_NTP \
           TNT_MOD_SUID TNT_MOD_FIM TNT_MOD_VPN TNT_MOD_SUSPICIOUS TNT_MOD_WORLD_WRITABLE
}

# ── Context-aware warn/bad color selector ─────────────────────────────────────
# Returns C_RED when High adversary or Internet-Facing; C_YELLOW otherwise.
# Modules use this to tighten or relax thresholds based on deployment context.
_ctx_warn() {
    if [[ "$TNT_ADVERSARY" == "High" ]] || [[ "$TNT_NETWORK" == "Internet-Facing" ]]; then
        echo -n "$C_RED"
    else
        echo -n "$C_YELLOW"
    fi
}
