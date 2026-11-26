# Raspberry Pi 4B: boot chain, kernel, firmware partition and config.txt.
{
  config,
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    # SD image builder; also defines the NIXOS_SD and FIRMWARE file systems.
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  # Mainline LTS kernel: prebuilt in cache.nixos.org and includes snd-bcm2835
  # (3.5 mm jack). The nixos-hardware default (vendor kernel) is not cached, so
  # it would compile for hours under emulation on the laptop.
  boot.kernelPackages = pkgs.linuxPackages;

  boot.loader.generic-extlinux-compatible.configurationLimit = 10;

  hardware.raspberry-pi = {
    # Rewrite the firmware partition (GPU firmware, config.txt, U-Boot) on every
    # switch, so config.txt is declared here rather than edited by hand.
    firmware = {
      enable = true;
      # U-Boot reads extlinux.conf; its boot menu lists older generations.
      uboot.enable = true;
    };
    # Onboard 3.5 mm output (dtparam=audio=on, snd_bcm2835). Currently produces
    # no sound card with the mainline kernel (docs/LESSONS.md); USB audio is used.
    audio.enable = true;

    configtxt = {
      settings.all = {
        # Headless: no camera or display.
        camera_auto_detect = false;
        display_auto_detect = false;
      };
      # Replaces the default vc4-kms-v3d (no display). Ethernet only, no Bluetooth.
      # To re-enable Wi-Fi or Bluetooth, remove the overlay and switch.
      deviceTreeOverlays.all = [
        { disable-wifi = { }; }
        { disable-bt = { }; }
      ];
    };
  };

  sdImage = {
    # Room for firmware, device trees and overlays (the default 30 MB is tight).
    firmwareSize = 256;
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };

  # sd-image.nix mounts the firmware partition only on demand; the firmware
  # activation script needs it mounted.
  fileSystems."/boot/firmware".options = lib.mkForce [ "nofail" ];
}
