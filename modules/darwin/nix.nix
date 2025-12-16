{ config, ... }:
{
  nix.enable = false;
  determinate-nix.customSettings = config.nix.settings // {
    builders-use-substitutes = true;
  };
  services.my-determinate.config.builder.state = "enabled";
}
