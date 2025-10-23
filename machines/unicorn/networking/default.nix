{ vars, ... }:
{
  imports = [
    ./cloudflared.nix
  ];

  networking = {
    hostName = "unicorn";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.unicorn.ipv4;
          prefixLength = 22;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.unicorn.ipv6;
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = {
      address = vars.unicorn.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.unicorn.ipv6Gateway;
      interface = "eth0";
    };
  };
}
