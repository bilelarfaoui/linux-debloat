#!/usr/bin/env bash
# linux-debloat: remove preinstalled bloat on Debian/Ubuntu, Fedora/RHEL and Arch based distros.
# Dry-run by default. Nothing is removed unless you pass --apply.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

VERSION="0.1.0"
ORIG_ARGS=("$@")
APPLY=0
ASSUME_YES=0
AUTOREMOVE=1
LIST_ONLY=0
CATEGORIES="telemetry,games,extras"
FAMILY_OVERRIDE=""

usage() {
  cat <<EOF
linux-debloat $VERSION

Usage: ./debloat.sh [options]

Options:
  -a, --apply              Actually remove packages (default is a dry run)
  -y, --yes                Do not ask for confirmation (use with --apply)
  -c, --categories LIST    Comma separated categories, or "all"
                           (default: telemetry,games,extras)
  -l, --list               Show detected distro family and available categories
      --family NAME        Force family: debian | fedora | arch
      --no-autoremove      Skip removal of orphaned dependencies afterwards
  -h, --help               Show this help
  -v, --version            Show version

Examples:
  ./debloat.sh                          # preview what would be removed
  ./debloat.sh --apply                  # remove default categories
  ./debloat.sh -c all --apply           # remove everything in every category
  ./debloat.sh -c telemetry,office -a   # only telemetry and office suites
EOF
}

while (($#)); do
  case "$1" in
    -a|--apply) APPLY=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -c|--categories) CATEGORIES="${2:?--categories needs a value}"; shift ;;
    -l|--list) LIST_ONLY=1 ;;
    --family) FAMILY_OVERRIDE="${2:?--family needs a value}"; shift ;;
    --no-autoremove) AUTOREMOVE=0 ;;
    -h|--help) usage; exit 0 ;;
    -v|--version) echo "$VERSION"; exit 0 ;;
    *) usage >&2; die "Unknown option: $1" ;;
  esac
  shift
done

FAMILY="${FAMILY_OVERRIDE:-$(detect_family)}"
case "$FAMILY" in
  debian|fedora|arch) ;;
  *) die "Unsupported distro. Force one with --family debian|fedora|arch" ;;
esac

PKG_DIR="$ROOT/packages/$FAMILY"
# shellcheck source=/dev/null
source "$ROOT/distros/$FAMILY.sh"

if ((LIST_ONLY)); then
  log "Detected family: $FAMILY"
  for f in "$PKG_DIR"/*.txt; do
    printf '  %-12s %s packages\n' "$(basename "$f" .txt)" "$(read_list "$f" | wc -l)"
  done
  exit 0
fi

if ((APPLY)) && ((EUID != 0)); then
  log "Root is required to remove packages, re-running with sudo..."
  exec sudo -E bash "$0" "${ORIG_ARGS[@]}"
fi

if [[ $CATEGORIES == all ]]; then
  CATEGORIES="$(cd "$PKG_DIR" && printf '%s,' *.txt | sed 's/\.txt//g; s/,$//')"
fi

# Collect installed candidates
IFS=',' read -ra CATS <<<"$CATEGORIES"
declare -A SEEN=()
CANDIDATES=()
for category in "${CATS[@]}"; do
  file="$PKG_DIR/$category.txt"
  [[ -f $file ]] || die "Unknown category '$category' for $FAMILY (see --list)"
  while IFS= read -r pkg; do
    [[ -n ${SEEN[$pkg]:-} ]] && continue
    SEEN[$pkg]=1
    if pkg_installed "$pkg"; then
      CANDIDATES+=("$pkg")
    fi
  done < <(read_list "$file")
done

if ((${#CANDIDATES[@]} == 0)); then
  ok "Nothing to remove for categories: $CATEGORIES"
  exit 0
fi

log "Family: $FAMILY | categories: $CATEGORIES"
log "Installed packages matching the lists (${#CANDIDATES[@]}):"
printf '    %s\n' "${CANDIDATES[@]}"

if ((!APPLY)); then
  warn "Dry run only. Re-run with --apply to remove them (safety checks run at that point)."
  exit 0
fi

# Safety: skip anything whose removal would drag in a protected package
PROT="$(mktemp)"
trap 'rm -f "$PROT"' EXIT
read_list "$ROOT/protected.txt" >"$PROT"

SAFE=()
for pkg in "${CANDIDATES[@]}"; do
  blocked="$(pkg_simulate "$pkg" | grep -Fxf "$PROT" | paste -sd, - || true)"
  if [[ -n $blocked ]]; then
    warn "Skipping $pkg: removing it would also remove protected package(s): $blocked"
  else
    SAFE+=("$pkg")
  fi
done

if ((${#SAFE[@]} == 0)); then
  warn "Every candidate was blocked by the safety check. Nothing removed."
  exit 0
fi

# Backup, confirm, remove
BACKUP_DIR="${DEBLOAT_BACKUP_ROOT:-/var/backups/linux-debloat}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
pkg_backup "$BACKUP_DIR"
printf '%s\n' "${SAFE[@]}" >"$BACKUP_DIR/removed.txt"
ok "Package list backup saved to $BACKUP_DIR"

confirm "Remove ${#SAFE[@]} package(s) now?" || die "Aborted by user."

pkg_remove "${SAFE[@]}"
if ((AUTOREMOVE)); then
  pkg_cleanup
fi

ok "Done. To undo: $PKG_INSTALL_CMD \$(cat $BACKUP_DIR/removed.txt)"
