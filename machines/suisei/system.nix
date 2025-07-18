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

  # # see https://github.com/golang/go/issues/69255
  # nixpkgs.overlays = [
  #   # NOTE: as for the naming, see
  #   # - https://github.com/NixOS/nixpkgs/blob/a59eb7800787c926045d51b70982ae285faa2346/pkgs/applications/virtualization/qemu/default.nix#L140C3-L147C21
  #   # - https://github.com/NixOS/nixpkgs/blob/b134951a4c9f3c995fd7be05f3243f8ecd65d798/pkgs/applications/virtualization/qemu/default.nix#L53C3-L57C45
  #   (self: super: {qemu-user = pkgs-qemu8.qemu;})
  # ];

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
