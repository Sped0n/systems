{
  modulesPath,
  # pkgs-qemu8,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_scsi"
    "usbhid"
    "sd_mod"
    "virtio_pci"
  ];
}
