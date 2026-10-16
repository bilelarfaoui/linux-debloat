#!/usr/bin/env bash
# Backend for Fedora, RHEL, Rocky, AlmaLinux, CentOS Stream and other rpm/dnf distros.
# Sourced by debloat.sh; defines the pkg_* interface. Works with dnf4 and dnf5.

DNF="$(command -v dnf 2>/dev/null || command -v yum 2>/dev/null || echo dnf)"
PKG_INSTALL_CMD="$DNF install -y"

pkg_installed() {
  need rpm
  rpm -q --quiet "$1"
}

# Print every package dnf would remove if $1 were removed (one per line).
# Parses the transaction table printed by `dnf remove --assumeno`.
pkg_simulate() {
  need "$DNF"
  "$DNF" remove --assumeno "$1" 2>/dev/null | awk '
    /^Removing/            { on = 1; next }
    /^Transaction Summary/ { on = 0 }
    on && NF >= 3 && $2 ~ /^(x86_64|aarch64|noarch|i686|armv7hl|ppc64le|s390x)$/ { print $1 }
  '
}

pkg_backup() {
  need rpm
  rpm -qa --qf '%{NAME}\n' | sort -u >"$1/installed.txt"
  "$DNF" repoquery --userinstalled -q >"$1/userinstalled.txt" 2>/dev/null || true
}

pkg_remove() {
  "$DNF" remove -y "$@"
}

pkg_cleanup() {
  "$DNF" autoremove -y
}
