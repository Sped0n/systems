{modulesPath, ...}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "uhci_hcd"
      "virtio_blk"
      "ahci"
      "ata_piix"
      "virtio_pci"
      "xen_blkfront"
      "vmw_pvscsi"
    ];
    kernelModules = ["kvm-amd"];
  };

  zramSwap = {
    enable = true;
    priority = 100;
    algorithm = "lz4";
    memoryPercent = 50;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 1 * 1024;
      priority = 10;
    }
  ];
}
