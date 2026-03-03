{ lib, ... }:
{
  boot.loader = {
    timeout = lib.mkDefault 7;
    grub.configurationLimit = lib.mkDefault 10;
  };
}
