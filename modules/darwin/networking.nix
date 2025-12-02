{ ... }:
{
  # magicDNS resolver
  environment.etc."resolver/ts.net".text = ''
    nameserver 100.100.100.100
    port 53
  '';
}
