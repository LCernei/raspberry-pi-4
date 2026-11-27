# Raspberry Pi music appliance: Music Assistant, a Sendspin player on USB
# speakers, Newt (Pangolin) and Tailscale. Runs unattended.
{ pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/github-ssh-keys.nix
    ../../modules/music-assistant.nix
    ../../modules/music-assistant-resume.nix
    ../../modules/sendspin.nix
    ../../modules/newt.nix
    ../../modules/tailscale.nix
  ];

  networking = {
    hostName = "rpi";
    # Keep the Ethernet interface named eth0.
    usePredictableInterfaceNames = false;
    useDHCP = true; # use a DHCP reservation on the router, not a static IP
    # The LAN is trusted, as on the previous Debian host: Music Assistant
    # needs mDNS, streaming and Spotify Connect ports that change at runtime.
    firewall.trustedInterfaces = [ "eth0" ];
  };

  time.timeZone = "Europe/Chisinau";
  i18n.defaultLocale = "en_US.UTF-8";

  users.mutableUsers = false;
  # No user has a password or a key in the config: pi's keys arrive at runtime
  # from GitHub. Without this, NixOS refuses the config as a likely lockout.
  users.allowNoPasswordLogin = true;
  users.users.pi = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # No password: SSH keys only, imported from GitHub (modules/github-ssh-keys.nix).
  };
  # Needed for deploy-rs and remote administration without a password.
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # rpi.local on the LAN.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Keep logs across reboots, so a hang that ends in a watchdog reset can be
  # diagnosed. Capped and flushed every 30 s: a small, steady write load.
  services.journald = {
    storage = "persistent";
    extraConfig = ''
      SystemMaxUse=200M
      SyncIntervalSec=30s
    '';
  };
  zramSwap.enable = true;

  # Hardware watchdog: reboot if the system hangs.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "15s";
    RebootWatchdogSec = "2min";
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # deploy-rs copies closures as `pi`.
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise.automatic = true;
  };

  documentation.nixos.enable = false;

  environment.systemPackages = with pkgs; [
    alsa-utils # aplay -l, alsamixer
    htop
  ];

  system.stateVersion = "26.05";
}
