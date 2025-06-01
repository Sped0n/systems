{
  pkgs-qemu8,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "virtio_scsi"
      "usbhid"
      "sd_mod"
      "virtio_pci"
    ];
    binfmt.emulatedSystems = [
      "x86_64-linux"
    ];
  };

  nixpkgs.overlays = [
    (self: super: {qemu-user = pkgs-qemu8.qemu;})
  ];
}
