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

  swapDevices = [
    {
      device = "/swapfile";
      size = 2 * 1024; # 2GB
    }
  ];
}
