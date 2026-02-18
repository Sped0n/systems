{ vars, ... }:
{
  networking = rec {
    hostName = "srv-hk-0";
    interfaces.eth0.ipv4.addresses = [
      {
        address = vars."${hostName}".ipv4;
        prefixLength = 24;
      }
    ];

    defaultGateway = {
      address = vars."${hostName}".ipv4Gateway;
      interface = "eth0";
    };
  };
}
