{ secrets, vars, ... }:
{
  age.secrets."nix-gh-rate-limit-bypass" = {
    mode = "0400";
    file = "${secrets}/ages/nix-gh-rate-limit-bypass.age";
    path = "${vars.home}/.config/nix/nix-gh-rate-limit-bypass.conf";
  };

  nix.extraOptions = ''
    !include nix-gh-rate-limit-bypass.conf
  '';
}
