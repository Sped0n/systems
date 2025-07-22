{
  modulesPath,
  # pkgs-qemu8,
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
    binfmt.emulatedSystems = ["x86_64-linux"];
  };

  # builder setup
  nix = {
    gc = {
      dates = "monthly";
      options = "--delete-older-than 30d";
    };
    settings = {
      keep-outputs = true;
      keep-derivations = true;
    };
  };
}
