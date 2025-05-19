{...}: {
  boot = {
    loader.grub = {
      useOSProber = true;
    };

    initrd.availableKernelModules = [
      "ata_piix"
      "mptspi"
      "uhci_hcd"
      "ehci_pci"
      "ahci"
      "xhci_pci"
      "sd_mod"
      "sr_mod"
    ];
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 6 * 1024; # 6GB
    }
  ];

  # Enable CUPS to print documents
  services.printing.enable = true;
}
