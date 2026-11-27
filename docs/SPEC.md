# Deployment specification

## Purpose and scope

The Raspberry Pi is a small, unattended music appliance that is rarely
physically accessible. Its whole system is declared in this repository as a NixOS
flake, so a fresh install is: build the SD image, flash it, restore
application state. Persistent application state and plaintext credentials
are not stored in Git.

## Host

- Raspberry Pi 4B 4 GB, booting from SD card (MBR: FAT32 firmware partition,
  ext4 root that grows on first boot), Ethernet only (Wi-Fi and
  Bluetooth disabled with device tree overlays).
- NixOS stable (`nixos-26.05`), pinned by `flake.lock`. Updates are
  deliberate: update the lock, build, deploy, verify.
- Mainline LTS kernel (`pkgs.linuxPackages`), which is in the binary cache.
  Boot chain: GPU firmware, then U-Boot, then `extlinux.conf`. `config.txt`
  and the firmware partition are generated from Nix and rewritten on every
  switch (`hardware.raspberry-pi.firmware.enable`).
- Login user `pi`, SSH keys only (from GitHub), passwordless `sudo` for
  deployment.
- Hostname `rpi`, reachable as `rpi.local` (avahi). DHCP, with a reservation
  on the router rather than a static IP.
- Persistent journal on the SD card (capped at 200 MB, synced every 30 s)
  so logs survive a watchdog reset; zram swap, hardware watchdog, weekly
  Nix garbage collection.

## Services

- **Music Assistant**: the official image
  `ghcr.io/music-assistant/server`, pinned by tag and digest, run with Docker
  (`virtualisation.oci-containers`) and host networking. This is an install
  method upstream supports. Web UI on port 8095. State in
  `/var/lib/music-assistant` (mounted as `/data`).
- **Sendspin player**: the `sendspin` client in daemon mode as a native
  systemd service, named "Bucătărie", playing to the Creative Pebble V3
  speakers over USB (selected by the name prefix `Pebble V3`; 48 kHz/16-bit,
  hardware volume on its `PCM` mixer via `amixer`). The onboard 3.5 mm
  jack does not work with the mainline kernel and the firmware device tree
  (see `docs/LESSONS.md`). Package from `nixos-unstable` (stable is too
  old). State in `/var/lib/sendspin`. Keep its version compatible with
  the Music Assistant image; update them together. The service is bound
  to the Pebble's device unit (`/dev/snd/by-id/usb-ACTIONS_Pebble_V3-00`):
  it starts when the Pebble appears on USB and stops when it disappears.
- The Pebble takes power and audio over one USB cable. After a power loss
  it usually plays again by itself, but it has twice needed its knob turned
  off and on (see `docs/LESSONS.md`).
- **Resume after restart** (`music-assistant-resume`): Music Assistant keeps
  its queues across restarts but does not resume them. A timer saves which
  queues are playing every minute (a queue whose player is unavailable keeps
  its entry); each time Music Assistant or Sendspin starts, those
  queues are resumed once their players are available (for up to 30
  minutes). Stopped queues stay stopped. Uses a long-lived Music Assistant
  token in `/var/lib/secrets/music-assistant.token`; without it, the helper
  does not run.
- **Newt**: native `services.newt`, tunnel to the user's Pangolin server.
  Pangolin resources target local services (Music Assistant:
  `http://localhost:8095`).
- **Tailscale**: second, independent remote path. Logged in once
  interactively; key expiry disabled for this machine. State in
  `/var/lib/tailscale`.
- Not used: MPD, myMPD, Arcane, Squeezelite.

## Network

- The LAN interface `eth0` and `tailscale0` are trusted by the firewall.
  Music Assistant needs mDNS, streaming and Spotify Connect ports that are
  chosen at runtime.

## Secrets and access

- The repository is public: no credentials, no SSH keys and no encrypted
  secrets in Git.
- `pi`'s SSH keys are imported once, on first boot, from
  `ssh-import-id gh:LCernei` into `~pi/.ssh/authorized_keys` (only
  while that file does not exist).
- Newt credentials (`PANGOLIN_ENDPOINT`, `NEWT_ID`, `NEWT_SECRET`) are copied
  to `/var/lib/secrets/newt.env` (root, mode 0600) by hand. Newt starts only
  once that file exists.
- A long-lived Music Assistant token for the resume helper is copied to
  `/var/lib/secrets/music-assistant.token` (root, mode 0600) by hand. It
  expires after a year.

## Application state (back up; not in Git)

- `/var/lib/music-assistant`: settings, library, provider credentials
  (Spotify).
- `/var/lib/sendspin`: client identity and pairing.
- `/var/lib/tailscale`: node identity (optional; re-login also works).
- `/var/lib/secrets/newt.env`: Newt credentials.
- `/var/lib/secrets/music-assistant.token`: the resume helper's token.
- Copy SQLite databases only with Music Assistant stopped, preserving
  ownership and the `-wal`/`-shm` files.

## Change acceptance checks

1. Compare changes with this spec and `docs/LESSONS.md`.
2. `nix flake check` and build the system (`nix build
   .#nixosConfigurations.rpi.config.system.build.toplevel`).
3. Deploy with `deploy .#rpi` from the dev shell (automatic rollback if SSH
   is lost).
4. Verify: SSH and Tailscale reachable, Music Assistant on port 8095, the
   Sendspin player present in Music Assistant and audible, the Newt tunnel
   works remotely.

## Current state

Installed on a new SD card on 2026-11-26 and running. Verified: boot,
Ethernet, SSH as `pi` with the key imported from GitHub, watchdog, deploy
with deploy-rs, Sendspin on the Pebble registered in Music Assistant,
Music Assistant restored from the Debian data (2.10.13), Newt tunnel
connected. The old Debian card is kept intact as a fallback (containers
stopped).
