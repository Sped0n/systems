{ vars, ... }:
{
  services.my-ladder = {
    singbox = {
      enable = true;
      variant = "as-rly";
      firewall.tcpPorts = with vars.ladderPorts; [ at ];
    };
    snell = {
      enable = true;
      firewall = with vars.ladderPorts; {
        tcpPorts = [ sn ];
        udpPorts = [ sn ];
      };
    };
  };
}
