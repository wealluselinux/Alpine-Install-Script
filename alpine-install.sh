#!/usr/bin/env bash
# Alpine Install Script v0.1.0
# Run as root from Alpine installation media. The chosen disk will be erased.
# Test in a VM first. setup-alpine retains its own confirmation prompts.
set -Eeuo pipefail
VERSION=0.1.0
DASHBOARD=yes
PROGRESS_DIR=""
PROGRESS_FILE=""
ANSWER_FILE=""
if [[ -t 1 ]]; then C=$'\033[36m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'; else C=""; G=""; Y=""; R=""; N=""; fi
info(){ printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok(){ printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn(){ printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die(){ printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
progress(){
  [[ -n ${PROGRESS_FILE:-} && -e $PROGRESS_FILE ]] || return 0
  local p=${1:-0} m=${2:-}
  [[ $p =~ ^[0-9]+$ ]] || p=0
  ((p>100)) && p=100
  m=${m//$'\n'/ }; m=${m//|/\/}
  printf '%s|%s\n' "$p" "$m" > "$PROGRESS_FILE"
}
usage(){ printf 'Alpine Install Script v%s\nUsage: bash %s [--help|--version|--no-dashboard]\n' "$VERSION" "$(basename "$0")"; }
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -v|--version) echo "$VERSION"; exit 0 ;;
  --no-dashboard) DASHBOARD=no ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac
ask(){
  local var=$1 prompt=$2 default=${3:-} answer=""
  if [[ -n $default ]]; then
    read -r -p "$prompt [$default]: " answer || true
    answer=${answer:-$default}
  else
    while :; do read -r -p "$prompt: " answer || true; [[ -n $answer ]] && break; done
  fi
  printf -v "$var" '%s' "$answer"
}
menu(){
  local var=$1 prompt=$2; shift 2
  local options=("$@") i answer
  echo "$prompt"
  for i in "${!options[@]}"; do printf '  %d) %s\n' "$((i+1))" "${options[$i]}"; done
  while :; do
    read -r -p 'Choice [1]: ' answer || true; answer=${answer:-1}
    if [[ $answer =~ ^[0-9]+$ ]] && ((answer>=1 && answer<=${#options[@]})); then
      printf -v "$var" '%s' "${options[answer-1]}"; return
    fi
    warn 'Choose one of the listed numbers.'
  done
}
start_dashboard(){
  [[ $DASHBOARD == yes ]] || return 0
  PROGRESS_DIR=$(mktemp -d /tmp/alpine-installer.XXXXXX)
  PROGRESS_FILE="$PROGRESS_DIR/status"
  local dash="$PROGRESS_DIR/dashboard.sh"
  printf '0|Preparing installer\n' > "$PROGRESS_FILE"
  cat > "$dash" <<'DASH'
#!/usr/bin/env bash
file=${1:?status file required}
trap 'printf "\033[?25h\033[0m\n"' EXIT
printf '\033[?25l'
while :; do
  p=0; m='Waiting for installer'
  if [[ -r $file ]]; then IFS='|' read -r p m < "$file" || true; fi
  [[ $p =~ ^[0-9]+$ ]] || p=0
  printf '\033[H\033[2J  ALPINE INSTALLER PROGRESS\n  ==========================\n\n  ['
  width=32; full=$((p*width/100))
  for ((i=0;i<full;i++)); do printf '#'; done
  for ((i=full;i<width;i++)); do printf ' '; done
  printf '] %3d%%\n\n  Current task:\n  %s\n\n  Detailed prompts and command output stay in the main terminal.\n' "$p" "$m"
  if ((p>=100)); then read -r -p 'Press Enter to close: ' _ || true; break; fi
  sleep 0.5
done
DASH
  chmod 700 "$dash"
  if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
    if command -v xterm >/dev/null 2>&1; then xterm -T 'Alpine Installer Progress' -e bash "$dash" "$PROGRESS_FILE" >/dev/null 2>&1 &
    elif command -v xfce4-terminal >/dev/null 2>&1; then xfce4-terminal --title='Alpine Installer Progress' --command="bash '$dash' '$PROGRESS_FILE'" >/dev/null 2>&1 &
    else warn 'Install xterm or xfce4-terminal to use the separate dashboard.'; fi
  elif [[ -n ${TMUX:-} ]] && command -v tmux >/dev/null 2>&1; then
    tmux split-window -d -h "bash '$dash' '$PROGRESS_FILE'" || warn 'Could not open dashboard pane.'
  else warn 'No graphical terminal or tmux found; progress stays in this terminal.'; fi
}
cleanup(){ [[ -n ${ANSWER_FILE:-} ]] && rm -f "$ANSWER_FILE"; [[ -n ${PROGRESS_DIR:-} ]] && rm -rf "$PROGRESS_DIR"; }
trap cleanup EXIT
preflight(){
  [[ $EUID -eq 0 ]] || die 'Run this script as root.'
  [[ $(uname -m) == x86_64 ]] || die 'Currently supports x86_64 only.'
  command -v setup-alpine >/dev/null 2>&1 || die 'Boot Alpine installation media first; setup-alpine was not found.'
  command -v lsblk >/dev/null 2>&1 || die 'lsblk is required.'
  [[ -t 0 ]] || exec </dev/tty
  info 'Check network access and configure networking before installing.'
}
select_disk(){
  echo; info 'Available disks:'
  lsblk -dpno NAME,SIZE,TYPE,MODEL
  local items=() name size type model
  while read -r name size type model; do
    [[ $type == disk && -b $name ]] && items+=("$name  $size  ${model:-unknown}")
  done < <(lsblk -dpno NAME,SIZE,TYPE,MODEL)
  ((${#items[@]}>0)) || die 'No disks found.'
  menu DISK_CHOICE 'Select the disk that will be ERASED:' "${items[@]}"
  DISK=${DISK_CHOICE%% *}
  bytes=$(blockdev --getsize64 "$DISK" 2>/dev/null || echo 0)
  ((bytes>=8*1024**3)) || die 'Selected disk must be at least 8 GiB.'
}
configure(){
  select_disk
  menu DESKTOP 'Desktop environment:' 'None (server/terminal)' 'XFCE' 'Sway'
  ask KEYMAP 'Keyboard layout' 'us'
  ask HOSTNAME 'Hostname' 'alpine'
  [[ $HOSTNAME =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || die 'Invalid hostname.'
  ask TIMEZONE 'Timezone' 'UTC'
  ask USERNAME 'Regular username' 'user'
  [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die 'Invalid username.'
  ask SWAP_GB 'Swap size in GiB (0 disables swap)' '4'
  [[ $SWAP_GB =~ ^[0-9]+$ ]] || die 'Swap size must be a whole number.'
  ((SWAP_GB<=1024)) || die 'Swap size is too large.'
  SWAP_MB=$((SWAP_GB*1024))
  menu NTP 'Time synchronization' 'chrony' 'busybox' 'none'
  case "$NTP" in chrony) NTP_ARGS='-c chrony' ;; busybox) NTP_ARGS='-c busybox' ;; *) NTP_ARGS=none ;; esac
}
confirm(){
  echo; printf 'Disk: %s (%s)\nHostname: %s\nUser: %s\nKeyboard: %s\nTimezone: %s\nDesktop: %s\nSwap: %s GiB\n' "$DISK" "$(lsblk -dno SIZE "$DISK")" "$HOSTNAME" "$USERNAME" "$KEYMAP" "$TIMEZONE" "$DESKTOP" "$SWAP_GB"
  lsblk "$DISK"
  warn "ALL DATA ON $DISK WILL BE ERASED."
  local answer; read -r -p "Type ERASE $DISK to continue: " answer || true
  [[ $answer == "ERASE $DISK" ]] || die 'Cancelled. No disk changes were started.'
}
write_answerfile(){
  ANSWER_FILE=$(mktemp /tmp/alpine-installer-answer.XXXXXX)
  cat > "$ANSWER_FILE" <<EOF
KEYMAPOPTS="$KEYMAP $KEYMAP"
HOSTNAMEOPTS="-n $HOSTNAME"
TIMEZONEOPTS="$TIMEZONE"
PROXYOPTS=none
APKREPOSOPTS="-1 -c"
USEROPTS="-a -g audio,input,video,netdev $USERNAME"
SSHDOPTS="-c openssh"
NTPOPTS="$NTP_ARGS"
DISKOPTS="-m sys -s $SWAP_MB $DISK"
LBUOPTS=none
APKCACHEOPTS=none
EOF
  chmod 600 "$ANSWER_FILE"
}
main(){
  printf '\n%sAlpine Install Script v%s%s\n' "$C" "$VERSION" "$N"
  preflight; configure; confirm; start_dashboard
  progress 3 'Preparing setup answer file'; write_answerfile
  progress 8 'Launching Alpine setup-alpine'
  info 'The official Alpine installer will ask for remaining settings, including the root password.'
  info 'The percentage shown is a stage estimate, not an exact time-remaining measurement.'
  setup-alpine -f "$ANSWER_FILE"
  progress 90 'Installer finished; cleaning up'
  rm -f "$ANSWER_FILE"; ANSWER_FILE=""
  sync
  progress 100 'Finished. Review output before rebooting.'
  ok 'Installation command finished. Verify setup-alpine reported no errors.'
  local answer; read -r -p 'Reboot now? [y/N]: ' answer || true
  [[ $answer =~ ^[Yy]$ ]] && reboot
}
main
