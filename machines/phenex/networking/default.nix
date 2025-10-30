{ vars, ... }:
{
  imports = [
    ./cloudflared.nix
  ];

  networking = {
    hostName = "phenex";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.phenex.ipv4;
          prefixLength = 22;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.phenex.ipv6;
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = {
      address = vars.phenex.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.phenex.ipv6Gateway;
      interface = "eth0";
    };
  };
}
