# Music Assistant from the official image: Docker with host networking is one of
# the two install methods upstream supports (the other is the Home Assistant app).
{ ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.music-assistant = {
      # Pinned: update the tag and digest together, deliberately. Keep the
      # Sendspin client (modules/sendspin.nix) compatible when updating.
      image = "ghcr.io/music-assistant/server:2.10.13@sha256:7510aaa7ee5fc85b34fd0de17992bd14473895b23ce3eb9b310092743f4dbb84";
      volumes = [ "/var/lib/music-assistant:/data" ];
      environment.LOG_LEVEL = "info";
      # Discovery (mDNS), streaming and Spotify Connect need the host network.
      extraOptions = [ "--network=host" ];
    };
  };

  # Settings, library and provider credentials (incl. Spotify). Back this up.
  systemd.tmpfiles.rules = [ "d /var/lib/music-assistant 0755 root root -" ];
}
