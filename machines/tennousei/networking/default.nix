{vars, ...}: {
  imports = [
    ./sshd.nix
    ./cloudflared.nix
  ];

  networking = {
    # Static IP
    hostName = "tennousei";
    interfaces.eth0.ipv4.addresses = [
      {
        address = vars.tennousei.ipv4;
        prefixLength = 22;
      }
    ];
    defaultGateway = {
      address = vars.tennousei.ipv4Gateway;
      interface = "eth0";
    };
    interfaces.eth0.ipv6.addresses = [
      {
        address = vars.tennousei.ipv6;
        prefixLength = 64;
      }
    ];
    defaultGateway6 = {
      address = vars.tennousei.ipv6Gateway;
      interface = "eth0";
    };
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "2606:4700:4700::1111"
      "2001:4860:4860::8888"
    ];

    # Firewall
    firewall = {
      extraCommands = ''
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
      '';
      trustedInterfaces = ["docker0"];
    };
  };
}
