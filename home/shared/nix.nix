{ config, secrets, ... }:
{
  age.secrets."nix-gh-rate-limit-bypass" = {
    mode = "0400";
    file = "${secrets}/ages/nix-gh-rate-limit-bypass.age";
  };

  nix.extraOptions = ''
    !include ${config.age.secrets."nix-gh-rate-limit-bypass".path}
  '';
}
