#!/usr/bin/env bash

print_header "World-Writable & Sticky Bit Audit"
print_explain "World-writable files and directories can be modified by any user on the system, creating opportunities for privilege escalation, log tampering, or planting malicious files in trusted paths. This section categorizes world-writable paths and highlights those outside expected sandboxed locations, which carry higher risk."

# Helper: longest common directory prefix (ending in /) of two absolute paths.
# Compares character-by-character, then trims to the last '/'.
# Prints the prefix to stdout; prints nothing if result is "/" or contains no "/".
_ww_common_dir() {
    local _ww_a="$1" _ww_b="$2"
    local _ww_i=0 _ww_len_a=${#_ww_a} _ww_len_b=${#_ww_b}
    local _ww_max=$(( _ww_len_a < _ww_len_b ? _ww_len_a : _ww_len_b ))
    local _ww_common=""

    while (( _ww_i < _ww_max )); do
        if [[ "${_ww_a:$_ww_i:1}" == "${_ww_b:$_ww_i:1}" ]]; then
            _ww_common+="${_ww_a:$_ww_i:1}"
            (( _ww_i++ ))
        else
            break
        fi
    done

    # Trim to the last '/' to get a proper directory boundary
    if [[ "$_ww_common" == */* ]]; then
        _ww_common="${_ww_common%/*}/"
    else
        return   # no '/' in common prefix — nothing useful to return
    fi

    # Suppress the trivial root-only result
    [[ "$_ww_common" == "/" ]] && return

    printf '%s' "$_ww_common"
}

# Helper: smart path printer.
# Usage: _ww_print_paths COLOR ARRAY_NAME
#   COLOR      — color escape string (actual ESC bytes), e.g. "$C_RED"
#   ARRAY_NAME — name of an indexed array variable (passed by name; nameref inside)
#
# Sorts paths, then applies three display strategies:
#   GROUP (2+ consecutive paths sharing a common dir prefix >= 48 chars):
#     "     COLOR  prefix/…  RESET"
#     "        COLOR  …relative  RESET"   (one line per group member)
#   LONG SINGLETON (> WIDTH-6 chars): split at last '/' at or before WIDTH-6
#     "     COLOR  first/part/…  RESET"
#     "        COLOR  …rest  RESET"
#   SHORT SINGLETON:
#     "     COLOR  path  RESET"
_ww_print_paths() {
    local _pp_col="$1"
    local -n _pp_arr=$2
    local _pp_wrap=$(( WIDTH - 6 ))
    [[ $_pp_wrap -lt 20 ]] && _pp_wrap=20

    # Sort the paths for locality — similar paths land adjacent after sorting
    local -a _pp_sorted
    mapfile -t _pp_sorted < <(printf '%s\n' "${_pp_arr[@]}" | sort)

    local _pp_n=${#_pp_sorted[@]}
    (( _pp_n == 0 )) && return

    local _pp_i=0
    while (( _pp_i < _pp_n )); do
        local _pp_cur="${_pp_sorted[$_pp_i]}"

        # Test whether the next path forms a consolidation group with the current one
        if (( _pp_i + 1 < _pp_n )); then
            local _pp_next="${_pp_sorted[$(( _pp_i + 1 ))]}"
            local _pp_prefix
            _pp_prefix=$(_ww_common_dir "$_pp_cur" "$_pp_next")

            if [[ -n "$_pp_prefix" ]] && (( ${#_pp_prefix} >= 48 )); then
                # Collect ALL consecutive paths that share this prefix
                local -a _pp_group=()
                while (( _pp_i < _pp_n )) && [[ "${_pp_sorted[$_pp_i]}" == "$_pp_prefix"* ]]; do
                    _pp_group+=("${_pp_sorted[$_pp_i]}")
                    (( _pp_i++ ))
                done

                # Group header: shared prefix + trailing ellipsis.
                # If the prefix fills or exceeds the wrap limit, split it at an
                # earlier '/' boundary and prepend the overflow to each member's
                # relative path. Start the backward search at (len-2) to skip the
                # trailing '/' that always terminates the prefix, then clamp to
                # (wrap-1) so we never exceed the line budget.
                local _pp_disp_prefix="$_pp_prefix" _pp_extra=""
                if (( ${#_pp_prefix} >= _pp_wrap )); then
                    local _pp_trim=$(( ${#_pp_prefix} - 2 ))
                    (( _pp_trim > _pp_wrap - 1 )) && _pp_trim=$(( _pp_wrap - 1 ))
                    while (( _pp_trim > 0 )) && [[ "${_pp_prefix:$_pp_trim:1}" != "/" ]]; do
                        (( _pp_trim-- ))
                    done
                    if (( _pp_trim > 0 )); then
                        _pp_disp_prefix="${_pp_prefix:0:$(( _pp_trim + 1 ))}"
                        _pp_extra="${_pp_prefix:$(( _pp_trim + 1 ))}"
                    fi
                fi
                printf "     ${_pp_col}%s\xe2\x80\xa6${C_RESET}\n" "$_pp_disp_prefix"
                # Each member: extra indent + leading ellipsis + overflow + relative path
                for _pp_gf in "${_pp_group[@]}"; do
                    local _pp_rel="${_pp_gf#"$_pp_prefix"}"
                    printf "        ${_pp_col}\xe2\x80\xa6%s%s${C_RESET}\n" "$_pp_extra" "$_pp_rel"
                done
                continue
            fi
        fi

        # Singleton: split long paths at the last '/' at or before WIDTH-6
        if (( ${#_pp_cur} > _pp_wrap )); then
            local _pp_split=$(( _pp_wrap ))
            while (( _pp_split > 0 )) && [[ "${_pp_cur:$_pp_split:1}" != "/" ]]; do
                (( _pp_split-- ))
            done

            if (( _pp_split > 0 )); then
                local _pp_head="${_pp_cur:0:$(( _pp_split + 1 ))}"
                local _pp_tail="${_pp_cur:$(( _pp_split + 1 ))}"
                printf "     ${_pp_col}%s\xe2\x80\xa6${C_RESET}\n" "$_pp_head"
                printf "        ${_pp_col}\xe2\x80\xa6%s${C_RESET}\n" "$_pp_tail"
            else
                # No slash found before wrap (defensive — absolute paths always have one)
                printf "     ${_pp_col}%s${C_RESET}\n" "$_pp_cur"
            fi
        else
            # Short singleton — print as-is
            printf "     ${_pp_col}%s${C_RESET}\n" "$_pp_cur"
        fi

        (( _pp_i++ ))
    done
}

# Helper: categorize world-writable files into 3 risk buckets and print each
# with its own header and color.
#   System        — root:root owned in /usr, /etc, /lib*  → red
#   Sandboxed     — flatpak/snap paths or /home/*         → yellow
#   User-space    — everything else                        → yellow
_categorize_ww_files() {
    local -n _cf_arr=$1
    local -a _sys=() _sand=() _user=()

    for _f in "${_cf_arr[@]}"; do
        local _owner _group
        read -r _ _owner _group < <(stat -c "%a %U %G" "$_f" 2>/dev/null)
        if [[ "$_owner" == "root" && "$_group" == "root" ]] && \
           [[ "$_f" == /usr/* || "$_f" == /etc/* || "$_f" == /lib/* || "$_f" == /lib64/* ]]; then
            _sys+=("$_f")
        elif [[ "$_f" == */.var/* || "$_f" == */.local/share/flatpak/* || \
                "$_f" == */snap/* || "$_f" == /home/* || "$_f" == /root/* ]]; then
            _sand+=("$_f")
        else
            _user+=("$_f")
        fi
    done

    if [[ ${#_sys[@]} -gt 0 ]]; then
        printf "\n   ${C_BOLD}${C_RED}System-owned (root:root, system path) — %d file(s)${C_RESET}\n" "${#_sys[@]}"
        _ww_print_paths "$C_RED" _sys
    fi
    if [[ ${#_sand[@]} -gt 0 ]]; then
        printf "\n   ${C_BOLD}${C_YELLOW}Sandboxed App Data (flatpak/snap/home) — %d file(s)${C_RESET}\n" "${#_sand[@]}"
        _ww_print_paths "$C_YELLOW" _sand
    fi
    if [[ ${#_user[@]} -gt 0 ]]; then
        printf "\n   ${C_BOLD}${C_YELLOW}User-space — %d file(s)${C_RESET}\n" "${#_user[@]}"
        _ww_print_paths "$C_YELLOW" _user
    fi
}

# Helper: print entries grouped by owner:group + mode
# Expects an array of paths; calls stat on each, sorts, and groups.
_print_grouped() {
    local -n _entries=$1
    local _col=$2   # color code for paths

    # Build sort keys: "owner:group|mode|path" — sort by owner:group then mode then path
    mapfile -t _sorted < <(
        for f in "${_entries[@]}"; do
            read -r mode owner group < <(stat -c "%a %U %G" "$f" 2>/dev/null)
            printf '%s|%s|%s\n' "${owner}:${group}" "$mode" "$f"
        done | sort
    )

    local _prev_gk=""
    local -a _cur_paths=()
    for _entry in "${_sorted[@]}"; do
        local _og="${_entry%%|*}"
        local _rest="${_entry#*|}"
        local _mode="${_rest%%|*}"
        local _path="${_rest#*|}"
        local _gk="${_og} ${_mode}"
        if [[ "$_gk" != "$_prev_gk" ]]; then
            # Flush accumulated paths for the outgoing group before any separator
            if [[ -n "$_prev_gk" ]] && [[ ${#_cur_paths[@]} -gt 0 ]]; then
                _ww_print_paths "$_col" _cur_paths
            fi
            [[ -n "$_prev_gk" ]] && echo ""
            printf "   ${C_BOLD}${C_CYAN}%s  %s${C_RESET}\n" "$_og" "$_mode"
            _prev_gk="$_gk"
            _cur_paths=()
        fi
        _cur_paths+=("$_path")
    done
    # Flush the final group (never triggers the transition branch above)
    [[ ${#_cur_paths[@]} -gt 0 ]] && _ww_print_paths "$_col" _cur_paths
}

# --- World-writable files outside expected dirs ---
# Excludes /proc /sys /dev /run/lock (by design) and /tmp /var/tmp (sticky bit protects these)
mapfile -t ww_files < <(
    find / -xdev -type f -perm -0002 \
        ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" \
        ! -path "/tmp/*" ! -path "/var/tmp/*" ! -path "/run/lock/*" \
        2>/dev/null | sort
)

ww_count=${#ww_files[@]}

if [[ $ww_count -eq 0 ]]; then
    printf " ${C_BOLD}%-30s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "World-Writable Files:" "None found"
else
    printf " ${C_BOLD}%-30s${C_RESET} ${C_RED}%s found${C_RESET}\n" "World-Writable Files:" "$ww_count"
    _categorize_ww_files ww_files
fi

# --- World-writable directories (no sticky bit, outside /tmp) ---
echo ""
mapfile -t ww_dirs < <(
    find / -xdev -type d -perm -0002 ! -perm -1000 \
        ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" \
        ! -path "/tmp" ! -path "/var/tmp" ! -path "/run/lock" \
        2>/dev/null | sort
)
wwd_count=${#ww_dirs[@]}

if [[ $wwd_count -eq 0 ]]; then
    printf " ${C_BOLD}%-30s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "World-Writable Dirs (no sticky):" "None found"
else
    printf " ${C_BOLD}%-30s${C_RESET} ${C_RED}%s found${C_RESET}\n" "World-Writable Dirs (no sticky):" "$wwd_count"
    echo ""
    _print_grouped ww_dirs "$C_RED"
fi

# --- /tmp and /var/tmp sticky bit check ---
echo ""
printf " ${C_BOLD}${C_CYAN}%s${C_RESET}\n" "Sticky bit on shared temp directories:"
for d in /tmp /var/tmp; do
    [[ -d "$d" ]] || continue
    mode=$(stat -c "%a" "$d" 2>/dev/null)
    if [[ "$mode" == 1* ]]; then
        printf " %-14s  ${C_GREEN}%-6s${C_RESET}  ${C_GREEN}sticky bit set ✓${C_RESET}\n" "$d" "$mode"
    else
        printf " %-14s  ${C_RED}%-6s${C_RESET}  ${C_RED}sticky bit MISSING — any user can delete others' files${C_RESET}\n" "$d" "$mode"
    fi
done

# --- Summary ---
echo ""
total_issues=$(( ww_count + wwd_count ))
if [[ $total_issues -eq 0 ]]; then
    printf " ${C_BOLD}%-30s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "Summary:" "Clean — no unexpected world-writable paths"
else
    printf " ${C_BOLD}%-30s${C_RESET} ${C_RED}%s total item(s) require review${C_RESET}\n" "Summary:" "$total_issues"
fi
