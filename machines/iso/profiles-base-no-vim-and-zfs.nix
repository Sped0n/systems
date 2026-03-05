{
  lib,
  pkgs,
  ...
}:
{
  # Local replacement for nixpkgs profiles/base.nix without vim.
  environment.systemPackages = [
    pkgs.w3m-nographics
    pkgs.testdisk
    pkgs.ms-sys
    pkgs.efibootmgr
    pkgs.efivar
    pkgs.parted
    pkgs.gptfdisk
    pkgs.ddrescue
    pkgs.ccrypt
    pkgs.cryptsetup

    pkgs.fuse
    pkgs.fuse3
    pkgs.sshfs-fuse
    pkgs.socat
    pkgs.screen
    pkgs.tcpdump

    pkgs.sdparm
    pkgs.hdparm
    pkgs.smartmontools
    pkgs.pciutils
    pkgs.usbutils
    pkgs.nvme-cli

    pkgs.unzip
    pkgs.zip

    pkgs.jq
  ];

  boot.supportedFilesystems = lib.mkMerge [
    [
      "btrfs"
      "cifs"
      "f2fs"
      "ntfs"
      "vfat"
      "xfs"
    ]
    {
      zfs = lib.mkForce false;
    }
  ];
}
