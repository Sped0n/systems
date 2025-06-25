{pkgs, ...}:
with pkgs; {
  home.packages = [
    rclone

    hugo
    go
  ];
}
