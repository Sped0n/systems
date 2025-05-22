{pkgs, ...}:
with pkgs; {
  imports = [
    ../../../home/nixos/server/packages.nix
  ];

  home.packages =
    # Main
    [
      docker-compose
      rclone
    ]
    ++
    # Others
    [
      hugo
      go
    ];
}
