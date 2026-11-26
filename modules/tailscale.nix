# Tailscale: a second remote path, independent of Pangolin and of Docker.
# Log in once with `sudo tailscale up`, then disable key expiry for this
# machine in the Tailscale admin console. State: /var/lib/tailscale.
{ ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # Access is controlled by the tailnet's ACLs.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
