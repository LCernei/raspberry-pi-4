# Operational lessons

This file records verified, reusable findings. Keep entries concise, include
the context that could make them stale, and update or remove them when they
no longer apply.

## 2026-11-26: Raspberry Pi vendor kernel is not in the binary cache

The nixos-hardware Raspberry Pi 4 profile builds the Raspberry Pi vendor
kernel from source, and nixpkgs' `linuxPackages_rpi4` is not cached either
(checked for 26.05 and unstable). On an x86_64 laptop that means compiling a
kernel under QEMU emulation. The mainline LTS kernel (`pkgs.linuxPackages`)
is cached for aarch64 and includes `snd-bcm2835` for the 3.5 mm jack.

## 2026-11-26: sendspin on stable NixOS is too old

`nixos-26.05` ships sendspin 5.9.0 while `nixos-unstable` has 9.1.0. The
Sendspin protocol is young; take the client from unstable and keep it
compatible with the pinned Music Assistant image.

## 2026-11-26: Music Assistant has no built-in local sound output

Music Assistant always plays through a player. Its built-in Local Audio Out
provider is retired upstream; the Local Audio app is a containerized
`sendspin` client. Upstream supports only the Home Assistant app and the
standalone Docker image as install methods.

## 2026-11-26: Onboard audio needs the kernel's device tree on mainline

With `hardware.raspberry-pi.audio.enable` (firmware device tree), the vchiq
node is `brcm,bcm2711-vchiq`, which the mainline 6.18 `vchiq` driver does
not match (it matches `brcm,bcm2835-vchiq`/`bcm2836-vchiq`, as in the
kernel's own `bcm2711-rpi-4-b.dtb`). `snd_bcm2835` loads but no sound card
appears. USB audio is unaffected.

## 2026-11-26: Sendspin selects devices by its own list

`sendspin --audio-device` takes an index, a name prefix from
`sendspin audio-devices list`, or an ALSA plugin name; `plughw:CARD=...`
was reported as not found. Use the name prefix (here `Pebble V3`).

## 2026-11-26: Pangolin health checks have their own target

Changing a Pangolin resource's target updates Newt's proxy, but the health
check keeps its own host and port and must be changed separately.

## 2026-11-26: EEPROM tools need the vendor kernel

`rpi-eeprom-update` and `rpi-eeprom-config` read the bootloader through
`vcgencmd` and `/dev/vcio`, which the mainline kernel does not provide
("Unable to get bootloader config"). Change EEPROM settings from a Raspberry
Pi OS card. Also, the stable nixpkgs `raspberrypi-eeprom` ships an older Pi 4
bootloader (2026-01-09) than the one installed; `--apply` with its default
image would downgrade.

## 2026-11-27: Music Assistant does not resume after a restart

Music Assistant 2.10.13 restores queue items and position from its cache
when a player registers, but recalculates the playback state from the player
(idle) and never resumes. Unattended recovery needs an external call to
`player_queues/resume` (here `modules/music-assistant-resume.nix`). The HTTP
API (`POST /api`) requires a bearer token; long-lived tokens expire after
365 days in the server code, although the UI text says 10 years.

## 2026-11-27: Switching journald to persistent storage needs a flush

After deploying `services.journald.storage = "persistent"`, journald was
restarted but kept writing to `/run/log/journal`; `/var/log/journal` appeared
only after `journalctl --flush`. Later boots flush automatically.

## 2026-11-27: Sendspin keeps a removed USB device open

When the Pebble left and re-joined USB, `sendspin` 9.1.0 kept its handle to
the removed PCM device (`/dev/snd/pcmC0D0p (deleted)`), logged nothing and
played nothing until restarted. Music Assistant 2.10.13 then registered the
returning player but did not resume its stream. Hence Sendspin is bound to
the Pebble's device unit and the resume helper also runs when Sendspin
starts.

## 2026-11-27: The Pebble needs its knob after a power loss

The Pebble V3 takes power and audio over one USB cable. `uhubctl` (2.6.0)
can cut the Pi 4's ganged USB power (hubs `1-1` and `2` both off), and the
Pebble then re-enumerates about 9 s after power returns, LED on, but stays
silent while audio streams to it. Turning the knob off and on restores sound.
After the watchdog reset on 2026-11-27 it did not even re-enumerate until the
knob was turned. A software USB power cycle therefore does not recover it.

## Retired setup: Debian, Docker Compose and Arcane (until 2026-11)

The findings below apply to the previous setup on the old SD card.

### 2026-10-30: Keep the Git checkout outside Arcane's projects directory

Arcane scans its configured projects directory for Compose projects. A Git
checkout nested inside that directory was discovered as a project itself.
Keep any source checkout outside Arcane's projects directory
(`$HOME/containers/arcane/projects`).
That directory is now a managed workspace, not a checkout.

### 2026-10-30: Keep project workspaces separate from application data

Arcane 2.17.1 refused to create a Git Pull project named `mpd` because its
projects root already contained an `mpd` data directory. Use
`$HOME/containers/arcane/projects` for Arcane-managed Compose files, with
Arcane's own data in the sibling `data` directory. Keep other application
data under `$HOME/containers/<application>`. Never delete application data to resolve a
project-name collision.

### 2026-10-30: Arcane Compose deployments may not have `HOME`

Arcane 2.17.1 logged that `HOME` was unset while discovering Compose projects
whose bind mounts use `${HOME}`. Configure shared values through
**Customization -> Variables**, scoped to the appropriate environment.
For example, set `HOME=/home/example`; Arcane writes it to `.env.global`
and uses it for Compose substitution across projects. A project's local
`.env` overrides the global value. Prefer the Variables UI over manually
editing the managed `.env.global` file.

With `HOME` unset, `${HOME}/containers/mpd/music` resolved to
`/containers/mpd/music`, and Docker created a bind directory at the host's
filesystem root instead of using existing application data. Validate resolved
mount paths before deploying. After correcting the variable, recreate the
container; restarting it does not change its mounts. Keep incorrectly created
directories until the corrected deployment and intended data are verified.

### 2026-10-30: Preserve cross-project Docker networks

MPD's Compose project creates `mpd_default`; myMPD joins it to reach MPD.
myMPD creates `mympd_default`; Newt joins it to reach myMPD. External networks
must exist before dependent projects start, so deploy MPD, then myMPD, then
Newt.

### 2026-10-30: Compose path changes require data migration

The application data was copied from `$HOME/docker` to `$HOME/containers`
before switching each service to the new mounts. A successful Compose config
check does not migrate data; copy and verify persistent data before switching
a service, and retain the old copy until the new deployment is verified.
After migration, MPD's protocol greeting, myMPD's HTTP response and MPD
connection, and Music Assistant's HTTP response were checked. Newt was
confirmed running on `mympd_default`. The user subsequently verified all
applications and their data, completing the migration. Retained rollback
copies are not ongoing backups and should not replace a backup policy.
