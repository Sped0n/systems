{ vars, ... }:
{
  networking = rec {
    hostName = "srv-jp-0";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "10.1.227.26";
          prefixLength = 16;
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
      address = "10.1.255.253";
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars."${hostName}".ipv6Gateway;
      interface = "eth0";
    };
  };
}
