#!/usr/bin/env bash
# Backend for Arch Linux, Manjaro, EndeavourOS, Garuda and other pacman distros.
# Sourced by debloat.sh; defines the pkg_* interface.

PKG_INSTALL_CMD="pacman -S --needed"

pkg_installed() {
  need pacman
  pacman -Qq "$1" >/dev/null 2>&1
}

# Print every package pacman would remove if $1 were removed (one per line).
# If other packages still depend on $1 pacman refuses and this prints nothing;
# pkg_remove then reports that package as skipped.
pkg_simulate() {
  need pacman
  pacman -Rsp --print-format '%n' "$1" 2>/dev/null || true
}

pkg_backup() {
  need pacman
  pacman -Qq >"$1/all.txt"
  pacman -Qqe >"$1/explicit.txt"
  pacman -Qqm >"$1/foreign.txt" || true
}

pkg_remove() {
  if pacman -Rns --noconfirm "$@"; then
    return 0
  fi
  warn "Batch removal failed (something still depends on one of the packages); retrying one by one"
  local pkg
  for pkg in "$@"; do
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
      pacman -Rns --noconfirm "$pkg" || warn "Skipped $pkg (still required by another package)"
    fi
  done
  return 0
}

pkg_cleanup() {
  local orphans=()
  mapfile -t orphans < <(pacman -Qdtq 2>/dev/null || true)
  if ((${#orphans[@]} > 0)); then
    pacman -Rns --noconfirm "${orphans[@]}"
  fi
  return 0
}
