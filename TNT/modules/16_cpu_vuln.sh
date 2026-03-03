#!/usr/bin/env bash

print_header "CPU Vulnerability Mitigations"
print_explain "Modern processors contain hardware vulnerabilities — Spectre, Meltdown, and related side-channel attacks — that allow cross-process data leakage. The kernel applies software mitigations for these flaws. This section verifies those mitigations are active and have not been disabled via boot parameters."

vuln_dir="/sys/devices/system/cpu/vulnerabilities"

if [[ ! -d "$vuln_dir" ]]; then
    printf " ${C_BOLD}%-30s${C_RESET} ${C_YELLOW}%s${C_RESET}\n" "CPU Vulnerabilities:" "Sysfs path not available (old kernel or no access)"
    return
fi

# Severity map — higher number = more critical to flag
declare -A vuln_severity=(
    [spectre_v1]=2   [spectre_v2]=3   [spectre_v2_user]=2
    [meltdown]=3     [l1tf]=3         [mds]=2
    [tsx_async_abort]=2 [srbds]=2     [mmio_stale_data]=2
    [retbleed]=3     [spec_rstack_overflow]=3
    [gather_data_sampling]=2          [reg_file_data_sampling]=2
    [rsb_ctxsw]=1
)

total=0; mitigated=0; vulnerable=0; unknown_count=0

printf " ${C_BOLD}${C_CYAN}%-32s  %s${C_RESET}\n" "Vulnerability" "Status"

for vuln_path in "$vuln_dir"/*; do
    [[ -f "$vuln_path" ]] || continue
    name=$(basename "$vuln_path")
    status=$(cat "$vuln_path" 2>/dev/null | tr -s ' ')
    ((total++))

    # Classify the status string
    if echo "$status" | grep -qiE "^Not affected$"; then
        col="$C_GREEN"; tag="Not affected"; ((mitigated++))
    elif echo "$status" | grep -qiE "Mitigation|IBPB|IBRS|STIBP|RETPOLINE|Enhanced IBRS|__schedule|VERW"; then
        col="$C_GREEN"; tag="Mitigated"; ((mitigated++))
    elif echo "$status" | grep -qiE "^Vulnerable"; then
        col="$C_RED"; tag="VULNERABLE"; ((vulnerable++))
    else
        col="$C_YELLOW"; tag="Unknown"; ((unknown_count++))
    fi

    # Truncate long status strings cleanly
    display=$(echo "$status" | cut -c1-46)
    [[ ${#status} -gt 46 ]] && display="${display}…"

    printf " ${C_BOLD}%-32s${C_RESET}  ${col}%s${C_RESET}\n" "$name" "$display"
done

# Summary line
echo ""
if [[ $vulnerable -gt 0 ]]; then sum_col="$C_RED"
elif [[ $unknown_count -gt 0 ]]; then sum_col="$C_YELLOW"
else sum_col="$C_GREEN"; fi

printf " ${C_BOLD}%-30s${C_RESET} ${sum_col}%s mitigated, %s vulnerable, %s unknown (of %s total)${C_RESET}\n" \
    "Summary:" "$mitigated" "$vulnerable" "$unknown_count" "$total"