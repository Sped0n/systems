{ ... }:
{
  boot.loader = {
    timeout = 8;
    grub = {
      configurationLimit = 7;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };
}
