# Newt: tunnel to the Pangolin server. Runs on the host, so Pangolin resources
# target local services directly (Music Assistant: http://localhost:8095).
#
# Credentials are not in this repository. Copy them to the Pi once (they are
# part of the backed-up state), as root-only:
#   /var/lib/secrets/newt.env  with  PANGOLIN_ENDPOINT=, NEWT_ID=, NEWT_SECRET=
_:

let
  envFile = "/var/lib/secrets/newt.env";
in
{
  services.newt = {
    enable = true;
    environmentFile = envFile;
  };

  # Wait for the credentials instead of failing in a loop; start with
  # `systemctl start newt` after copying the file.
  systemd.services.newt.unitConfig.ConditionPathExists = envFile;

  systemd.tmpfiles.rules = [ "d /var/lib/secrets 0700 root root -" ];
}
