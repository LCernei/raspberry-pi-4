# raspberry-pi-4

NixOS configuration for my Raspberry Pi music appliance: Music Assistant, a
Sendspin player on USB speakers, Newt (Pangolin) and Tailscale.

Design and current setup: [docs/SPEC.md](docs/SPEC.md). Open ideas:
[docs/PLANS.md](docs/PLANS.md).

## Layout

```text
flake.nix                 inputs, the rpi system, SD image, deploy-rs node, dev shell
hosts/rpi/default.nix     users, SSH, network, logging, watchdog, Nix settings
hosts/rpi/hardware.nix    Pi 4 boot chain, kernel, firmware partition, config.txt
modules/music-assistant.nix   official Music Assistant image (Docker, host network)
modules/sendspin.nix      Sendspin player (systemd)
modules/github-ssh-keys.nix   pi's SSH keys, imported from GitHub on first boot
modules/newt.nix          Newt tunnel (credentials copied to the Pi by hand)
modules/tailscale.nix     Tailscale
```

No secrets or keys are stored here, not even encrypted: the repository is
public. SSH keys come from `https://github.com/LCernei.keys`; the Newt
credentials live only on the Pi and in backups.

## Tools

The laptop builds for the Pi (aarch64) under emulation:
`boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` in its NixOS config.
`nix develop` provides `deploy` and `zstd`.

## Recreate the SD card

Use this for a fresh install, a spare card, or after a card failure. You need
the laptop (aarch64 emulation enabled), an SD card of at least 8 GB, and the
backed-up state: Music Assistant's data and `newt.env`.

1. **Build the image** from the repo root:

   ```sh
   nix build .#sd-image
   ls result/sd-image/   # nixos-image-sd-card-*.img.zst
   ```

   The image has an MBR partition table: a 256 MB FAT32 firmware partition
   (`FIRMWARE`) and an ext4 root (`NIXOS_SD`) that grows to fill the card on
   first boot.

2. **Flash it.** Find the card with `lsblk` (check the size; the wrong device
   destroys its data), unmount any of its partitions, then:

   ```sh
   zstd -dc result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```

3. **Boot the Pi** from the card, on Ethernet. On first boot it imports
   `pi`'s keys from GitHub once (internet access needed):

   ```sh
   ssh pi@rpi.local
   ```

   The new card has a new SSH host key: remove the old one from the laptop
   with `ssh-keygen -R rpi.local` first. The first boot is slow: Music
   Assistant's image (about 2 GB) is downloaded on first start, not stored in
   the SD image.

4. **Copy the Newt credentials** and start Newt:

   ```sh
   scp newt.env pi@rpi.local:/tmp/newt.env
   ssh pi@rpi.local 'sudo install -m 0600 -o root -g root /tmp/newt.env /var/lib/secrets/newt.env && rm /tmp/newt.env && sudo systemctl start newt'
   ```

   The file has `PANGOLIN_ENDPOINT=`, `NEWT_ID=` and `NEWT_SECRET=` lines.

5. **Restore Music Assistant's state**, with the service stopped. From an
   archive of the data directory (`music-assistant/data/...`):

   ```sh
   scp music-assistant.tar pi@rpi.local:/tmp/
   ssh pi@rpi.local
   sudo systemctl stop docker-music-assistant
   sudo tar -xpf /tmp/music-assistant.tar -C /tmp
   sudo rsync -a --delete /tmp/music-assistant/data/ /var/lib/music-assistant/
   sudo rm -rf /tmp/music-assistant /tmp/music-assistant.tar
   sudo systemctl start docker-music-assistant
   ```

   State restored from the old Debian setup still references MPD: remove the
   MPD player provider and set up Spotify Connect for the "Bucătărie"
   Sendspin player.

6. **Log in to Tailscale** once with `sudo tailscale up`, then disable key
   expiry for this machine in the Tailscale admin console.

7. **Check:**
   - Music Assistant opens at `http://rpi.local:8095` with the restored
     settings, and Spotify still works.
   - The "Bucătărie" Sendspin player is listed and plays on the Pebble (USB).
   - The Pangolin resource points at `http://localhost:8095` and works from
     outside the home network.
   - `ssh pi@<tailscale name>` works from another network.

## Changing the system

Edit, then from the repo root:

```sh
nix flake check
deploy .#rpi
```

deploy-rs builds on the laptop, copies to the Pi and activates. If the Pi
cannot be reached over SSH afterwards, it rolls back automatically. A
generation that fails to boot needs the U-Boot menu (micro-HDMI and a USB
keyboard). `rpi.local` only resolves on the Pi's LAN; from elsewhere, set
`hostname` in `flake.nix` to the Pi's Tailscale name.

Every switch rewrites the firmware partition (`config.txt`, U-Boot, GPU
firmware), and the U-Boot menu does not roll that back. If a change in
`hosts/rpi/hardware.nix` stops the Pi from booting, fix the `FIRMWARE`
partition from another computer. Make such changes only with physical
access.

Updates: `nix flake update` (or one input), build, deploy, verify.
Music Assistant is pinned in `modules/music-assistant.nix` (tag and digest);
update it together with Sendspin.

## Secrets

Never commit credentials or keys. To change Newt's credentials, replace
`/var/lib/secrets/newt.env` on the Pi and run `sudo systemctl restart newt`.
