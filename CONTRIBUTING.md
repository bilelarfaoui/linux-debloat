# Contributing

Mostly this means adding packages to the lists.

## Adding a package

1. Get the exact package name for the family (apt, dnf or pacman).
2. Put it in the right file under `packages/<family>/`, one per line. `#` starts a comment.
3. Pick the category:
   - `telemetry`: data collection, crash reporting, usage stats
   - `games`: bundled games
   - `extras`: harmless apps and docs hardly anyone uses
   - `office`, `media`: bigger apps people often want, so opt-in only
4. If removing it could drag in part of the desktop or base system, make sure `protected.txt` covers that.
5. Run `bash tests/smoke.sh`.

Names that aren't installed get ignored, so it's fine to list something that only exists on some releases.

## New distro family

Add `distros/<family>.sh` with `pkg_installed`, `pkg_simulate`, `pkg_backup`, `pkg_remove`, `pkg_cleanup` and `PKG_INSTALL_CMD` (copy `distros/debian.sh` as a starting point), add lists under `packages/<family>/`, and update `detect_family` in `lib/common.sh`.

## Style

Bash, `set -Eeuo pipefail`, clean under `shellcheck -x`. No dependencies beyond coreutils, sed and awk.
