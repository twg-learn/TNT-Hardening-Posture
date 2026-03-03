#!/usr/bin/env bash

print_header "Hardware Security"
print_explain "Hardware-level security features provide protections that software alone cannot replicate. Secure Boot prevents unsigned bootloader and kernel execution; IOMMU blocks DMA attacks from peripheral devices; TPM enables measured boot and hardware-bound credential sealing. This section verifies these features are enabled and active."

# --- Secure Boot ---
if [[ -d /sys/firmware/efi ]]; then
    if command -v mokutil &>/dev/null; then
        sb_out=$(mokutil --sb-state 2>/dev/null)
        [[ "$sb_out" == *"enabled"* ]] && sb_state="Enabled" || sb_state="Disabled"
    else
        sb_state="EFI (mokutil missing)"
    fi
else
    sb_state="N/A (BIOS/Legacy boot)"
fi

# --- IOMMU ---
iommu_state="Disabled"
if grep -qE "intel_iommu=on|amd_iommu=on" /proc/cmdline 2>/dev/null; then
    iommu_state="Enabled (cmdline)"
elif dmesg 2>/dev/null | grep -qi "DMAR.*IOMMU enabled\|AMD-Vi.*enabled" 2>/dev/null; then
    iommu_state="Enabled"
fi

# --- Kernel module lockdown ---
modules_locked=$(cat /proc/sys/kernel/modules_disabled 2>/dev/null)
[[ "$modules_locked" == "1" ]] && mod_disp="Locked (no new loads)" || mod_disp="Open (loadable)"

# --- Bluetooth ---
bt_status=$(systemctl is-active bluetooth 2>/dev/null)
if [[ -z "$bt_status" || "$bt_status" == "inactive" ]]; then
    bt_disp="Inactive"
elif [[ "$bt_status" == "active" ]]; then
    bt_disp="Active"
else
    bt_disp="Not installed"
fi

# --- USB Guard ---
if command -v usbguard &>/dev/null; then
    ug_status=$(systemctl is-active usbguard 2>/dev/null)
    [[ "$ug_status" == "active" ]] && ug_disp="Active" || ug_disp="Installed (Inactive)"
else
    ug_disp="Not installed"
fi

# Context-aware Secure Boot: Untrusted physical → Disabled = red; Trusted → Disabled = yellow
if [[ "${TNT_PHYSICAL:-Untrusted}" == "Untrusted" ]]; then
    _sb_warn="EFI|N/A"           # Disabled falls through to red
else
    _sb_warn="EFI|N/A|Disabled"  # Disabled is yellow (not ideal but tolerated)
fi

# Context-aware Bluetooth: Desktop (non-Internet-Facing) → Active = yellow; Server or Internet-Facing = red
if [[ "${TNT_ROLE:-Mixed}" == "Desktop" || "${TNT_ROLE:-Mixed}" == "Mixed" ]] && \
   [[ "${TNT_NETWORK:-Internet-Facing}" != "Internet-Facing" ]]; then
    _bt_warn="Active"  # Active on desktop is just a warning
else
    _bt_warn="n/a"     # Active on server/internet-facing = red
fi

printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Secure Boot:"    "$(color_val "$sb_state"    "Enabled"          "$_sb_warn")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "IOMMU:"          "$(color_val "$iommu_state" "Enabled"          "n/a")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Kernel Modules:" "$(color_val "$mod_disp"    "Locked"           "n/a")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "Bluetooth:"      "$(color_val "$bt_disp"     "Inactive|Not ins" "$_bt_warn")"
printf " ${C_BOLD}%-22s${C_RESET} %b\n" "USB Guard:"      "$(color_val "$ug_disp"     "Active"           "Installed")"
