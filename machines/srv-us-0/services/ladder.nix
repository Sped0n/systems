{ ... }:
{
  services.my-ladder = {
    singbox = {
      enable = true;
      variant = "default";
      firewall.tcpPorts = [ 443 ];
    };
    snell = {
      enable = true;
      firewall = {
        tcpPorts = [ 8989 ];
        udpPorts = [ 8989 ];
      };
    };
  };
}
