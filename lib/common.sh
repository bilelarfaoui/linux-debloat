#!/usr/bin/env bash
# Shared helpers, sourced by debloat.sh.

if [[ -t 1 ]]; then
  C_B=$'\033[1;34m'; C_G=$'\033[1;32m'; C_Y=$'\033[1;33m'; C_R=$'\033[1;31m'; C_0=$'\033[0m'
else
  C_B=''; C_G=''; C_Y=''; C_R=''; C_0=''
fi

log()  { printf '%s[*]%s %s\n' "$C_B" "$C_0" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }

# Abort unless the given command exists.
need() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# Print package names from a list file, ignoring comments and blank lines.
read_list() {
  sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | awk 'NF'
}

# Map /etc/os-release to one of: arch | debian | fedora | unknown
detect_family() {
  [[ -r /etc/os-release ]] || { echo unknown; return; }
  local ID='' ID_LIKE=''
  # shellcheck source=/dev/null
  . /etc/os-release
  local ids=" ${ID} ${ID_LIKE} "
  case "$ids" in
    *" arch "*|*" archlinux "*) echo arch ;;
    *" debian "*|*" ubuntu "*) echo debian ;;
    *" fedora "*|*" rhel "*|*" centos "*) echo fedora ;;
    *) echo unknown ;;
  esac
}

confirm() {
  if ((ASSUME_YES)); then return 0; fi
  local answer=''
  read -r -p "$1 [y/N] " answer </dev/tty || return 1
  [[ $answer =~ ^[Yy]$ ]]
}
