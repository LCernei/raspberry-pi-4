# Improvement plans (undecided)

Candidate changes, not current behavior; [the spec](SPEC.md) describes the
current setup. When a plan is accepted, move its durable requirements into
the spec and remove or update the entry here.

Design goal: an unattended appliance that is rarely physically accessible.
It should be boring, self-healing and fixable remotely; anything that can
leave it unbootable or unreachable is done only with physical access.

## Remote access

- Log in to Tailscale (`sudo tailscale up`) and disable key expiry for the
  machine.
- Verify SSH and `deploy` over Tailscale from another network; then set
  `hostname` in `flake.nix` to the Tailscale name (`rpi.local` only resolves
  on the LAN).
- Optional: SSH as a Pangolin TCP resource, as a third path.
- DHCP reservation for the Pi on the router.
- GitHub users for the SSH key import from the SD card instead of Git, so
  forks need no code change: after flashing, write
  `/boot/firmware/github-users` (FAT partition, editable from any computer),
  one GitHub username per line. On first boot the service runs
  `ssh-import-id gh:<user>` for each line, adding all their keys to `pi`.
  Fall back to the username in the config if the file is missing; without
  either, no key is imported and there is no SSH access. Not chosen for now:
  the username is already public in the repository URL.

## Backups

- Nightly systemd timer: stop Music Assistant, snapshot
  `/var/lib/music-assistant`, `/var/lib/sendspin`, `/var/lib/secrets` (and
  optionally `/var/lib/tailscale`) with restic or rustic, start it again.
- Off-device target (S3-compatible bucket, storage box, or a NAS over the
  VPN), with an append-only or least-privilege credential so the Pi cannot
  delete old snapshots. The backup credential lives only on the Pi, like
  `newt.env`.
- Retention, e.g. 7 daily, 4 weekly, 6 monthly; periodic `check`; test one
  restore.
- Keep a spare SD card flashed from the same image (README: "Recreate the
  SD card").

## Reliability

- Storage: high-endurance SD card or a USB SSD. Optionally a read-only root
  with only `/var/lib` writable.
- Health alert: a heartbeat to an uptime monitor or ntfy when Music
  Assistant or Sendspin stops responding.
- Updates: keep them deliberate (`flake.lock`, pinned image). Optionally
  Renovate or a scheduled job that opens update PRs for `flake.lock` and the
  Music Assistant tag.
- EEPROM: `POWER_OFF_ON_HALT=1` with `WAKE_ON_GPIO=0`, so a shutdown cuts
  power (restart with the smart plug). Apply it from a Raspberry Pi OS card
  with `rpi-eeprom-config --apply`; the tools do not work on this NixOS
  setup (see `docs/LESSONS.md`).

## Audio

- Onboard 3.5 mm jack as a fallback output (optional; USB is better). Needs
  the kernel's device tree: `useGenerationDeviceTree = true`, drop
  `hardware.raspberry-pi.audio.enable`, and disable Wi-Fi/Bluetooth on the
  kernel side (e.g. blacklist `brcmfmac`, `hci_uart`) because firmware
  overlays no longer apply. Boot-level change: only with physical access.

## Debloat

- Disable unused Music Assistant providers (AirPlay, Chromecast, DLNA,
  visualizer, recommendation and metadata extras) to cut CPU, network
  traffic and attack surface.
- Turn off the LEDs (`dtparam=act_led_trigger=none`,
  `dtparam=pwr_led_trigger=none`).
