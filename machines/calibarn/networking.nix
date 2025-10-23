{ vars, ... }:
{
  networking = {
    hostName = "calibarn";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.calibarn.ipv4;
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.calibarn.ipv6;
          prefixLength = 128;
        }
      ];
    };

    defaultGateway = {
      address = vars.calibarn.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.calibarn.ipv6Gateway;
      interface = "eth0";
    };
  };
}
