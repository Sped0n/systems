{vars, ...}: {
  imports = [
    ./sshd.nix
  ];

  networking = {
    # Static IP
    hostName = "suisei";
    interfaces.eth0.ipv4.addresses = [
      {
        address = vars.suisei.ipv4;
        prefixLength = 24;
      }
    ];
    defaultGateway = {
      address = vars.suisei.ipv4Gateway;
      interface = "eth0";
    };
    interfaces.eth0.ipv6.addresses = [
      {
        address = vars.suisei.ipv6;
        prefixLength = 128;
      }
    ];
    defaultGateway6 = {
      address = vars.suisei.ipv6Gateway;
      interface = "eth0";
    };
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "2606:4700:4700::1111"
      "2001:4860:4860::8888"
    ];
  };
}
