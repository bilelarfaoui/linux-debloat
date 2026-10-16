#!/usr/bin/env bash
# Backend for Debian, Ubuntu, Linux Mint, Pop!_OS, Kali and other apt based distros.
# Sourced by debloat.sh; defines the pkg_* interface.

PKG_INSTALL_CMD="apt-get install -y"

# Is the package currently installed?
pkg_installed() {
  need dpkg-query
  # shellcheck disable=SC2016  # ${db:...} is dpkg-query syntax, not shell
  [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == installed ]]
}

# Print every package apt would remove if $1 were removed (one per line).
pkg_simulate() {
  need apt-get
  apt-get -s remove "$1" 2>/dev/null | awk '/^Remv /{sub(/:.*/, "", $2); print $2}'
}

# Save enough state into directory $1 to reinstall what was removed.
pkg_backup() {
  need dpkg
  dpkg --get-selections >"$1/selections.txt"
  apt-mark showmanual >"$1/manual.txt"
}

pkg_remove() {
  DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"
}

pkg_cleanup() {
  DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
}
