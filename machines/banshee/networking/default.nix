{ vars, ... }:
{
  imports = [
    ./cloudflared.nix
  ];

  networking = {
    hostName = "banshee";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.banshee.ipv4;
          prefixLength = 32;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.banshee.ipv6;
          prefixLength = 128;
        }
      ];
    };

    defaultGateway = {
      address = vars.banshee.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.banshee.ipv6Gateway;
      interface = "eth0";
    };
  };
}
