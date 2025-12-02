{ ... }:
{
  networking = {
    knownNetworkServices = [
      "USB 10/100/1G/2.5G LAN"
      "USB 10/100/1000 LAN"
      "Thunderbolt Bridge"
      "Wi-Fi"
      "iPhone USB"
    ];

    dns = [
      "8.8.8.8"
      "1.1.1.1"
      "2001:4860:4860::8888"
      "2606:4700:4700::1111"
    ];
  };

  # tailscale magicDNS resolver
  environment.etc."resolver/ts.net".text = ''
    nameserver 100.100.100.100
    port 53
  '';
}
