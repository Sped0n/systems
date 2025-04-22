{config, ...}: {
  networking = {
    wg-quick.interfaces."wg0" = {
      configFile = config.age.secrets."wg0-conf".path;
      autostart = true;
    };

    firewall = {
      allowedUDPPorts = [51820];
      checkReversePath = false;
    };
  };

  # https://rakhesh.com/linux-bsd/tailscale-wireguard-co-existing-or-i-love-policy-based-routing
  systemd.services.tailscaled.after = ["wg-quick-wg0.service"];
}
