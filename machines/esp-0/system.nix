{ ... }:
{
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "ohci_pci"
    "ehci_pci"
    "xhci_pci"
    "ahci"
    "sd_mod"
    "sr_mod"
  ];

  virtualisation.virtualbox.guest.enable = true;
}
