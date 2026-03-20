{ secrets, ... }:
{
  age.secrets."nix-gh-rate-limit-bypass" = {
    owner = "root";
    mode = "0400";
    file = "${secrets}/ages/nix-gh-rate-limit-bypass.age";
    path = "/etc/nix/nix-gh-rate-limit-bypass.conf";
  };

  nix.extraOptions = ''
    !include nix-gh-rate-limit-bypass.conf
  '';
}
