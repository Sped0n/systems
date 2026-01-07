{ vars, ... }:
{
  networking = rec {
    hostName = "srv-sg-2";
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "172.26.11.241";
          prefixLength = 20;
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
      address = "172.26.0.1";
      interface = "eth0";
    };
    defaultGateway6 = {
      address = vars."${hostName}".ipv6Gateway;
      interface = "eth0";
    };
  };
}
