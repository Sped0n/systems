{ vars, ... }:
{
  networking = {
    hostName = "suisei";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars.suisei.ipv4;
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = vars.suisei.ipv6;
          prefixLength = 128;
        }
      ];
    };

    defaultGateway = {
      address = vars.suisei.ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars.suisei.ipv6Gateway;
      interface = "eth0";
    };
  };
}
