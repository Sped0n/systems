{ vars, ... }:
{
  imports = [
    ./cloudflared.nix
  ];

  networking = {
    hostName = "kinsei";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.kinsei.ipv4;
          prefixLength = 32;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.kinsei.ipv6;
          prefixLength = 128;
        }
      ];
    };

    defaultGateway = {
      address = vars.kinsei.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.kinsei.ipv6Gateway;
      interface = "eth0";
    };
  };
}
