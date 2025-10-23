{ vars, ... }:
{
  imports = [
    ./wireguard.nix
  ];

  networking = {
    hostName = "exia";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.exia.ipv4;
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.exia.ipv6;
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = {
      address = vars.exia.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.exia.ipv6Gateway;
      interface = "eth0";
    };
  };
}
