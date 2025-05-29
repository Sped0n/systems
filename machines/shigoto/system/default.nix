{...}: {
  imports = [
    ./usb.nix
  ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "ohci_pci"
    "ehci_pci"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Display
  services.xserver.resolutions = [
    {
      x = 1920;
      y = 1080;
    }
  ];

  # Virtualbox
  virtualisation.virtualbox.guest.enable = true;
}
