{ ... }:
{
  boot.loader = {
    timeout = 8;
    grub = {
      configurationLimit = 10;

      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };
}
