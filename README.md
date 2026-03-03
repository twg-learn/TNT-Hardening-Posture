# TNT — Linux Host Security Posture Audit

A bash-based, host-level security audit tool for Linux systems. Run it, answer a few
questions (or hand it a config file), and get a clean, colour-coded report covering
over 20 security domains — from kernel hardening and SSH configuration to SUID binaries
and world-writable files.

No installation. No package manager. No Python dependencies for basic use. Clone the
repo, run the script with `sudo`, and you're done.

---

## Features

- **Modular** — 22 independent audit modules; run all of them or hand-pick a subset
- **Context-aware** — thresholds and severity ratings adjust based on your declared role
  (Desktop / Server / Hypervisor), network exposure, and adversary model
- **Themed output** — six colour themes including True Color gradients and a universal
  compat mode for terminals that don't support 24-bit colour
- **Export support** — save reports as plain text, HTML, or PDF with no extra tools
  required for text/HTML; PDF via GhostScript (`ps2pdf`)
- **Config-file driven** — skip the interactive menu entirely by passing a `.conf` file;
  useful for scheduled audits, CI pipelines, or feeding output directly to an LLM
- **Explanation mode** — optional inline commentary beneath each check result

---

## Requirements

| Requirement | Notes |
|---|---|
| `bash` 4.0+ | Present on all modern Linux systems |
| `sudo` / root | Required — most checks read privileged system state |
| Standard coreutils | `awk`, `grep`, `ss`, `stat`, `find`, etc. — already present on any Linux install |
| `ghostscript` (`ps2pdf`) | **Optional** — only needed for PDF export |

---

## Quick Start

```bash
git clone https://github.com/twg-learn/Hardening-Posture.git
cd Hardening-Posture
sudo bash posture.sh
```

The script opens an interactive configuration menu. Answer the prompts, select your
modules, and the report runs immediately.

---

## Usage

### Interactive mode

```bash
sudo bash posture.sh
```

You'll be walked through:

1. **Display** — theme selection (auto-detected based on terminal capabilities)
2. **Deployment context** — system role, network exposure, adversary model, physical access
3. **Report options** — explanations, banner, export settings
4. **Module selection** — Full Report, or a custom checklist of specific modules

### Config file mode

Pass a config file with `--config` (or `-c`) to skip all prompts:

```bash
sudo bash posture.sh --config config-files/posture.conf.example
```

This is the recommended approach for repeated audits, scheduled tasks, or piping the
report to another tool.

---

## Config Files

Config files are plain bash — every setting is optional, and any omitted value falls
back to a sensible hardened default. Comments are supported with `#`.

### Full example

See [`config-files/posture.conf.example`](config-files/posture.conf.example)
for a fully documented reference config.

### Minimal example

```bash
# Minimal server audit — run only the most critical modules, export as text
TNT_THEME=dark
TNT_ROLE=Server
TNT_NETWORK=Internet-Facing
TNT_ADVERSARY=High
TNT_PHYSICAL=Trusted

TNT_EXPLAIN=no
TNT_BANNER=yes

TNT_EXPORT=yes
TNT_EXPORT_TYPE=text
TNT_EXPORT_PATH=$(_tnt_real_home)/reports/
TNT_EXPORT_NAME="posture_$(hostname -s)_$(date +%Y%m%d_%H%M)"

TNT_MODULES="network,ssh,attack_surface,users,kernel"
```

### Deployment context variables

These drive context-sensitive severity ratings throughout the report. A check that
produces a warning on a trusted desktop may produce a hard failure on an
internet-facing server.

| Variable | Values | Description |
|---|---|---|
| `TNT_ROLE` | `Desktop` `Server` `Hypervisor` `Mixed` | Primary function of the host |
| `TNT_NETWORK` | `LAN-Only` `VPN` `Internet-Facing` | Network exposure level |
| `TNT_ADVERSARY` | `Low` `Moderate` `High` | Threat model / adversary capability |
| `TNT_PHYSICAL` | `Trusted` `Semi-Trusted` `Untrusted` | Physical access risk |

### All config variables

| Variable | Default | Description |
|---|---|---|
| `TNT_THEME` | `dark` | Colour theme (see Themes below) |
| `TNT_TRUECOLOR` | auto | Override True Color detection: `yes` or `no` |
| `TNT_EXPLAIN` | `no` | Print inline explanations beneath each check |
| `TNT_BANNER` | `yes` | Show banner at top and bottom of report |
| `TNT_EXPORT` | `no` | Write report to disk |
| `TNT_EXPORT_TYPE` | `text` | Export format: `text`, `html`, or `pdf` |
| `TNT_EXPORT_PATH` | `~/reports/` | Directory to write the export into |
| `TNT_EXPORT_NAME` | auto (timestamp) | Base filename without extension |
| `TNT_MODULES` | all | Modules to run (see Module Selection below) |

---

## Modules

Use `TNT_MODULES="all"` (or `"full"`) to run everything, or pass a comma- or
space-separated list of module names.

| Module name | What it checks |
|---|---|
| `identity` | Hostname, OS, kernel version, uptime |
| `hardware` | CPU, memory, virtualisation detection |
| `network` | Network interfaces, open ports, exposed services |
| `ssh` | SSH daemon hardening (PermitRootLogin, key auth, ciphers, etc.) |
| `security` | Logging, auditd, fail2ban, AppArmor / SELinux status |
| `attack_surface` | Open port count, unnecessary running daemons |
| `hw_security` | Secure Boot, TPM, Bluetooth |
| `users` | Local users, sudo rights, privilege escalation paths |
| `filesystem` | Mount options, permissions, encryption (LUKS) |
| `packages` | Package currency, pending security updates |
| `auth_events` | Recent login events and authentication failures |
| `scheduled` | Cron jobs and systemd timers |
| `docker` | Docker daemon configuration and container security |
| `webserver` | nginx / Apache configuration review |
| `cpu_vuln` | CPU vulnerability mitigations (Spectre, Meltdown, etc.) |
| `kernel` | Kernel hardening sysctl parameters |
| `ntp` | Time synchronisation and NTP configuration |
| `suid` | SUID / SGID binary audit |
| `fim` | File Integrity Monitoring (AIDE, Tripwire) |
| `vpn` | VPN client detection and configuration |
| `suspicious` | Suspicious process indicators |
| `world_writable` | World-writable files and sticky-bit directories |

---

## Export Formats

| Format | Flag | Requirements |
|---|---|---|
| Plain text | `TNT_EXPORT_TYPE=text` | None — ANSI codes are stripped automatically |
| HTML | `TNT_EXPORT_TYPE=html` | None — converted with pure `awk` |
| PDF | `TNT_EXPORT_TYPE=pdf` | `ghostscript` (`ps2pdf`); falls back to HTML if unavailable |

Export files are written to the path set by `TNT_EXPORT_PATH`. When run via `sudo`,
ownership is automatically transferred back to the invoking user so you can open the
file without permission issues.

---

## Themes

| Theme | Terminal requirement | Description |
|---|---|---|
| `dark` | True Color (24-bit) | Dark background with gradient accents |
| `light` | True Color (24-bit) | Light background variant |
| `vampire` | True Color (24-bit) | Deep red / dark scheme |
| `powershell` | True Color (24-bit) | Blue, inspired by PowerShell |
| `manila` | True Color (24-bit) | Warm off-white / sepia |
| `compat` | Any terminal | Standard ANSI-16 colours; works everywhere |

True Color support is auto-detected from terminal signals (`COLORTERM`, `VTE_VERSION`,
`TERM_PROGRAM`). If your terminal is detected as non-True Color, `compat` is selected
automatically. You can override detection with `TNT_TRUECOLOR=yes` or pass `-tc` on the
command line to force compat mode for testing.

---

## Examples

**Full report, dark theme, no export:**
```bash
sudo bash posture.sh
```

**Quick server check from a config file:**
```bash
sudo bash posture.sh --config config-files/posture.conf.example
```

**Three specific modules, compat mode (for a basic terminal or SSH session):**
```bash
sudo bash posture.sh -tc --config my-server.conf
# my-server.conf contains: TNT_MODULES="ssh,kernel,users"
```

**Export to PDF, unattended:**
```bash
# In your config file:
TNT_EXPORT=yes
TNT_EXPORT_TYPE=pdf
TNT_EXPORT_PATH=/var/reports/
TNT_EXPORT_NAME="posture_$(hostname -s)_$(date +%Y%m%d)"
TNT_MODULES="all"

sudo bash posture.sh --config audit.conf
```

**Pipe plain-text output to an LLM or log aggregator:**
```bash
# Set TNT_BANNER=no in your config to suppress decorative headers
sudo bash posture.sh --config headless.conf | tee /var/log/posture.log
```

---

## Notes

- The script requires `sudo` or root for most checks. Running without elevated
  privileges will succeed but produce incomplete results.
- This tool is designed for learning and provides general security insights — it is not
  a professional security audit and does not replace one.
- The modular design means adding or modifying checks is straightforward: each module
  is a self-contained bash file in `modules/`.
- Tested on Debian / Ubuntu based distributions. Most checks are portable to any
  systemd-based Linux distribution.

---

## License

Released under the [MIT License](LICENSE). Contributions and module improvements are welcome.
