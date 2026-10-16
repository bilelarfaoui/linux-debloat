#!/usr/bin/env bash
# End-to-end test of the --apply path using stub apt tools, so nothing real is removed.
# Verifies: installed-only filtering, the protected-package safety check, backup
# files and the exact removal command. Must run as root (--apply re-execs via sudo otherwise).
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ((EUID != 0)); then
  echo "SKIP  test_apply_stub.sh needs root"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/backups"
LOG="$TMP/apt.log"
: >"$LOG"

# Pretend these are installed.
cat >"$TMP/bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
pkg="${*: -1}"
case " popularity-contest aisleriot gnome-mines cheese " in
  *" $pkg "*) printf 'installed' ;;
  *) exit 1 ;;
esac
EOF

# `apt-get -s remove cheese` also wants to remove gnome-shell (a protected package).
cat >"$TMP/bin/apt-get" <<EOF
#!/usr/bin/env bash
if [[ \$1 == -s ]]; then
  echo "Remv \$3 [1.0]"
  [[ \$3 == cheese ]] && echo "Remv gnome-shell [1.0]"
  exit 0
fi
echo "apt-get \$*" >>"$LOG"
EOF

printf '#!/usr/bin/env bash\necho gnome-shell\n' >"$TMP/bin/apt-mark"
printf '#!/usr/bin/env bash\necho "popularity-contest install"\n' >"$TMP/bin/dpkg"
chmod +x "$TMP"/bin/*

out="$(PATH="$TMP/bin:$PATH" DEBLOAT_BACKUP_ROOT="$TMP/backups" \
  "$ROOT/debloat.sh" --family debian -c telemetry,games,media --apply --yes 2>&1)"

fail=0
expect() {
  if grep -Fq -- "$1" <<<"$2"; then
    echo "ok    $3"
  else
    echo "FAIL  $3"; fail=1
  fi
}

expect "remove -y popularity-contest aisleriot gnome-mines" "$(cat "$LOG")" "removes only installed, safe packages"
if grep -Fq cheese "$LOG"; then echo "FAIL  protected-package guard let cheese through"; fail=1; else echo "ok    cheese skipped by safety check"; fi
expect "Skipping cheese" "$out" "safety check warns about cheese"
expect "autoremove -y" "$(cat "$LOG")" "autoremove runs afterwards"

backup="$(find "$TMP/backups" -name removed.txt | head -n1)"
if [[ -n $backup ]] && grep -Fxq aisleriot "$backup" && [[ -s "$(dirname "$backup")/selections.txt" ]]; then
  echo "ok    backup written"
else
  echo "FAIL  backup missing"; fail=1
fi

exit "$fail"
