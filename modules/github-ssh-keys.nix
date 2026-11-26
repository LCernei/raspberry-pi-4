# SSH keys for `pi` come from GitHub once, on first boot, so no key is stored in
# this repository. ssh-import-id adds them to ~pi/.ssh/authorized_keys; this runs
# only while that file does not exist.
{ pkgs, ... }:

{
  systemd.services.github-ssh-keys = {
    description = "Import SSH keys for pi from GitHub (first boot)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/home/pi/.ssh/authorized_keys";
    path = [ pkgs.openssh ]; # ssh-keygen, used to check the keys
    serviceConfig = {
      Type = "oneshot";
      User = "pi";
      ExecStart = "${pkgs.ssh-import-id}/bin/ssh-import-id gh:LCernei";
      # Retry until the network is up.
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
