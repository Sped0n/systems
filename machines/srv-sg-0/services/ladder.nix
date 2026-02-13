{ vars, ... }:
{
  services.my-ladder.singbox = {
    enable = true;
    variant = "as-xit";
    firewall = with vars.ladderPorts; {
      tcpPorts = [
        at
        s2
      ];
      udpPorts = [ s2 ];
    };
  };
}
