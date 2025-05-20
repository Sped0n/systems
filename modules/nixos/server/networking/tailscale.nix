{pkgs-unstable, ...}: {
  networking.firewall.trustedInterfaces = ["tailscale0"];

  services.tailscale = {
    enable = true;
    package = pkgs-unstable.tailscale;
    interfaceName = "tailscale0";
    openFirewall = true;
  };
}
