{ vars, ... }:
{
  networking = rec {
    hostName = "srv-us-0";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = vars."${hostName}".ipv4;
          prefixLength = 32;
        }
      ];
      ipv6.addresses = [
        {
          address = vars."${hostName}".ipv6;
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = {
      address = vars."${hostName}".ipv4Gateway;
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars."${hostName}".ipv6Gateway;
      interface = "eth0";
    };
  };
}
