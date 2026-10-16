# linux-debloat

A bash script that strips the junk most distros ship with (telemetry, games, apps nobody opens). Works on Debian/Ubuntu, Fedora/RHEL and Arch based systems.

It does nothing unless you pass `--apply`, so run it bare first and see what it finds.

## Supported

| Family | Package manager | Covers |
|---|---|---|
| Debian based | apt | Debian, Ubuntu, Mint, Pop!_OS, Kali |
| Fedora / RHEL based | dnf | Fedora, RHEL, Rocky, Alma, CentOS Stream |
| Arch based | pacman | Arch, Manjaro, EndeavourOS, Garuda |

The family is picked from `ID` / `ID_LIKE` in `/etc/os-release`. If your distro isn't recognised, pass `--family`.

## Use

```bash
git clone https://github.com/<you>/linux-debloat.git
cd linux-debloat

./debloat.sh            # preview only
./debloat.sh --apply    # actually remove (asks first)
```

Options:

```
-a, --apply             remove for real
-y, --yes               skip the confirmation prompt
-c, --categories LIST   comma separated, or "all" (default: telemetry,games,extras)
-l, --list              show detected family and categories
    --family NAME       debian | fedora | arch
    --no-autoremove     don't clean up orphaned deps afterwards
-h, --help
-v, --version
```

```bash
./debloat.sh -c telemetry -a          # just telemetry / crash reporters
./debloat.sh -c telemetry,office -a   # plus office suite and mail client
./debloat.sh -c all -a -y             # everything, no prompts
```

## Categories

- `telemetry`: popularity-contest, apport, whoopsie, abrt, insights-client, pkgstats...
- `games`: the GNOME and KDE game packs
- `extras`: weather, maps, help viewer and similar small stuff
- `office`: LibreOffice, Thunderbird (off by default)
- `media`: Rhythmbox, Totem, Shotwell, Cheese (off by default)

The lists are just text files in `packages/<family>/`. Read them, edit them.

## What it does when you apply

1. Keeps only the listed packages that are actually installed.
2. Simulates removing each one. If that would also remove something in `protected.txt` (kernel, desktop, bootloader, package manager...), it skips that package.
3. Saves your package lists to `/var/backups/linux-debloat/<timestamp>/`.
4. Asks, removes, then cleans orphans.

To undo, it prints a reinstall command at the end, something like:

```bash
sudo apt-get install -y $(cat /var/backups/linux-debloat/20261015-153900/removed.txt)
```

Config files deleted along with a package (especially with `pacman -Rns`) don't come back.

## Heads up

- The cleanup at the end (`autoremove` / orphan removal) hits every orphan on the system, not just ones from this script. Use `--no-autoremove` to avoid that.
- Lists are made for default desktop installs. On minimal or server installs most entries just aren't there and get ignored.
- Arch: if something else still needs a listed package, pacman refuses and the script reports it as skipped.
- No snap, flatpak or AUR handling yet.
- Look at the dry run before applying. Your system, your call.

## Tests

```bash
bash tests/smoke.sh
sudo bash tests/test_apply_stub.sh
```

CI runs shellcheck, those tests, and a dry run in Debian, Ubuntu, Fedora and Arch containers. Adding packages or a new distro: see [CONTRIBUTING.md](CONTRIBUTING.md).
