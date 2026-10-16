#!/usr/bin/env bash
# basic sanity checks, no root needed
# Needs no root and does not touch the system's packages.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
check() { # check "description" command...
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok    %s\n' "$desc"
  else
    printf 'FAIL  %s\n' "$desc"; fail=1
  fi
}

for f in debloat.sh lib/*.sh distros/*.sh tests/*.sh; do
  check "bash -n $f" bash -n "$f"
done

check "--help exits 0"    ./debloat.sh --help
check "--version exits 0" ./debloat.sh --version
check "unknown option fails" bash -c '! ./debloat.sh --nope'

for fam in debian fedora arch; do
  check "--list --family $fam" ./debloat.sh --list --family "$fam"
  check "unknown category rejected ($fam)" bash -c "! ./debloat.sh --family $fam -c nonsense"

  for cat in telemetry games extras office media; do
    check "packages/$fam/$cat.txt exists and is non-empty" test -s "packages/$fam/$cat.txt"
  done

  # No whitespace inside package names, no duplicates within one file.
  for f in packages/$fam/*.txt; do
    names="$(sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$f" | awk 'NF')"
    check "$f: single-token names" bash -c "! printf '%s\n' \"\$1\" | grep -q '[[:space:]]'" _ "$names"
    check "$f: no duplicates" bash -c "[ -z \"\$(printf '%s\n' \"\$1\" | sort | uniq -d)\" ]" _ "$names"
  done
done

exit "$fail"
