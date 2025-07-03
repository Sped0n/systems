{...}: {
  imports = [
    ./usb.nix
    ./waydroid.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "xhci_pci"
      "ahci"
      "sr_mod"
    ];
    kernelModules = ["kvm-intel"];
  };

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Display
  services.xserver.resolutions = [
    {
      x = 1920;
      y = 1080;
    }
  ];

  # virt-manager
  services.spice-vdagentd.enable = true;

  # nix-ld
  programs.nix-ld.enable = true;
}
