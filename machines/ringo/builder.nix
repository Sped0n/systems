{
  # pkgs,
  # pkgs-qemu8,
  ...
}:
{
  # home.programs.zsh.shellAliases = {
  #   "linux-builder-unload" = "sudo launchctl stop /Library/LaunchDaemons/org.nixos.linux-builder.plist; sudo launchctl unload /Library/LaunchDaemons/org.nixos.linux-builder.plist";
  #   "linux-builder-load" = "sudo launchctl load /Library/LaunchDaemons/org.nixos.linux-builder.plist";
  # };

  # nix.linux-builder = {
  #   enable = true;
  #   systems = ["x86_64-linux" "aarch64-linux"];
  #   ephemeral = true;
  #   maxJobs = 8;
  #   config = {
  #     virtualisation = {
  #       cores = 8;
  #       darwin-builder = {
  #         diskSize = 40 * 1024;
  #         memorySize = 8 * 1024;
  #       };
  #     };
  #     boot.binfmt.emulatedSystems = ["x86_64-linux"];
  #
  #     # see https://github.com/golang/go/issues/69255
  #     nixpkgs.overlays = [
  #       # NOTE: as for the naming, see
  #       # - https://github.com/NixOS/nixpkgs/blob/a59eb7800787c926045d51b70982ae285faa2346/pkgs/applications/virtualization/qemu/default.nix#L140C3-L147C21
  #       # - https://github.com/NixOS/nixpkgs/blob/b134951a4c9f3c995fd7be05f3243f8ecd65d798/pkgs/applications/virtualization/qemu/default.nix#L53C3-L57C45
  #       (self: super: {qemu-user = pkgs-qemu8.qemu;})
  #     ];
  #   };
  # };
}
