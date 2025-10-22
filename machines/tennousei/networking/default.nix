{ vars, ... }:
{
  imports = [
    ./cloudflared.nix
  ];

  networking = {
    hostName = "tennousei";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.tennousei.ipv4;
          prefixLength = 22;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.tennousei.ipv6;
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = {
      address = vars.tennousei.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.tennousei.ipv6Gateway;
      interface = "eth0";
    };
  };
}
