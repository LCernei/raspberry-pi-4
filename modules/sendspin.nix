# Local player: the Sendspin client plays Music Assistant's stream on the USB
# speakers. It advertises itself over mDNS (_sendspin._tcp), listens on port 8928.
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Stable 26.05 ships sendspin 5.9, too old for current Music Assistant.
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  systemd.services.sendspin = {
    description = "Sendspin player for Music Assistant";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "sound.target"
    ];
    wants = [ "network-online.target" ];
    # amixer: Sendspin's hardware volume (the Pebble's `PCM` mixer) is only
    # enabled when amixer is on PATH.
    path = [ pkgs.alsa-utils ];
    serviceConfig = {
      ExecStart = lib.escapeShellArgs [
        (lib.getExe' unstable.sendspin "sendspin")
        "daemon"
        "--name"
        "Bucătărie"
        # Creative Pebble V3 over USB (48 kHz/16-bit only). Selected by name
        # prefix from `sendspin audio-devices list`, not by index.
        "--audio-device"
        "Pebble V3"
        "--settings-dir"
        "/var/lib/sendspin"
        "--disable-mpris"
      ];
      DynamicUser = true;
      SupplementaryGroups = [ "audio" ];
      StateDirectory = "sendspin";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
