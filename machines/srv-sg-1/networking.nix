{ vars, ... }:
{
  networking = rec {
    hostName = "srv-sg-1";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "10.0.0.93";
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = vars."${hostName}".ipv6;
          prefixLength = 128;
        }
      ];
    };

    defaultGateway = {
      address = "10.0.0.1";
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars."${hostName}".ipv6Gateway;
      interface = "eth0";
    };
  };
}
