{ ... }:
{
  services.my-ladder.singbox = {
    enable = true;
    variant = "as-xit";
    firewall = {
      tcpPorts = [
        443
        6767
      ];
      udpPorts = [ 6767 ];
    };
  };
}
