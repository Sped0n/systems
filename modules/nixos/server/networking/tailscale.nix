{...}: {
  networking.firewall.trustedInterfaces = ["tailscale0"];

  services.tailscale = {
    enable = true;
    interfaceName = "tailscale0";
    openFirewall = true;
  };
}
