{ lib, ... }:
{
  boot.loader = {
    timeout = lib.mkDefault 3;
    grub.configurationLimit = lib.mkDefault 5;
  };
}
