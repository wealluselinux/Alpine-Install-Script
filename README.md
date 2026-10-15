# Alpine-Install-Script

A guided, early-stage Bash wrapper for Alpine Linux's official `setup-alpine` installer. It adds a few pre-installation choices and an optional second terminal/pane that displays a simple progress bar, while leaving detailed installer prompts and output in the main terminal.

> **Status: experimental prototype (v0.1.0).** This script has not been verified on real hardware. Test it in a virtual machine first and review the script before running it.

## Features

- Lists detected disks and lets you choose the target disk.
- Requires typing `ERASE /dev/...` for the selected disk before continuing.
- Prompts for a hostname, keyboard layout, timezone, regular username, swap size, and time synchronization option.
- Calls Alpine's official `setup-alpine` using a temporary answer file, then lets the official installer handle remaining prompts.
- Can open a separate progress dashboard in `xterm`, `xfce4-terminal`, or a tmux pane when a supported terminal environment is available.
- Keeps detailed prompts and command output in the main terminal.

The dashboard shows **coarse stage estimates**, not a measured percentage of all installation work or an estimate of time remaining.

## Requirements

- Alpine Linux installation media, booted into its live environment.
- An `x86_64` system (the script currently checks for this architecture).
- Root privileges.
- `bash`, `setup-alpine`, `lsblk`, and `blockdev`.
- Network access configured before installation.
- For a separate graphical dashboard: a graphical session and either `xterm` or `xfce4-terminal`. Alternatively, run inside tmux to use a split pane. If none is available, the installer can continue without a separate dashboard.

Make sure you have a reliable backup and know which disk is the intended target before starting.

## Installation and usage

Boot the Alpine installation environment and configure networking first. Obtain this repository using a Git client if one is available, or download the script from the repository's branch page.

Repository: https://github.com/wealluselinux/Alpine-Install-Script

Current development branch: `alpine-installer-port`

From the directory containing the script, run:

```sh
bash alpine-install.sh --help
bash alpine-install.sh --version
bash alpine-install.sh
```

To skip opening a separate progress dashboard:

```sh
bash alpine-install.sh --no-dashboard
```

Run the installer as root from the Alpine live installation environment. The script checks for root privileges and required commands. If you have saved the script to a location that is not writable by the live environment, place it somewhere writable before running it.

## Installation flow

1. Checks the environment and required commands.
2. Displays detected disks and asks you to select a target.
3. Collects the supported configuration choices.
4. Shows the chosen disk and settings, then requires a disk-specific confirmation.
5. Creates a temporary answer file and launches `setup-alpine`.
6. Displays a final status message and asks whether to reboot.

The official installer may still ask additional questions. Read its prompts carefully and confirm that its selected settings and target disk are correct.

## Data-loss and safety warnings

**The selected target disk will be erased.** Choosing the wrong disk can permanently destroy data. Do not proceed unless you understand the target disk and have backed up anything important.

- Test in a disposable virtual machine before considering physical hardware.
- Read the script before running it; do not run scripts from the internet blindly.
- Keep the computer connected to reliable power and make sure networking is configured.
- Do not assume the dashboard percentage means that exact percentage of the installation is complete.
- Do not reboot until you have reviewed the installer output and confirmed that it finished without errors.

The confirmation prompt is an additional safeguard, not a guarantee against data loss or installer bugs.

## Current limitations

- **Experimental and not yet hardware-tested.** Installation behavior can vary by Alpine release and environment.
- **Desktop selection is a placeholder.** The menu currently offers None, XFCE, and Sway, but this prototype does not automatically install or configure a desktop environment.
- The progress display reports broad script stages only; it does not track detailed `setup-alpine` progress.
- The script currently checks for `x86_64` only.
- The wrapper preconfigures some answers, but `setup-alpine` remains responsible for the rest of the installation.

## Troubleshooting

- **`setup-alpine` not found:** boot from Alpine installation media; this script is not intended to be run as a generic installer from an already-installed operating system.
- **Missing command:** confirm that the required utilities are available in your live environment.
- **No separate dashboard opens:** use a graphical session with `xterm` or `xfce4-terminal`, run inside tmux, or pass `--no-dashboard`.
- **Installation reports an error:** follow the message shown by `setup-alpine`; do not reboot until you have reviewed the result.

## Contributing

Bug reports, testing notes, and improvements are welcome. Please include your Alpine version, architecture, how you ran the script, and the relevant error output. Do not include passwords, private keys, or other secrets in an issue.

## License

No license is specified in this repository yet. Until a license is added, do not assume that the project grants permission to redistribute or modify its contents.
