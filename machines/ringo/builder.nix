{
  # pkgs,
  ...
}: {
  # home.programs.zsh.shellAliases = {
  #   "linux-builder-unload" = "sudo launchctl stop /Library/LaunchDaemons/org.nixos.linux-builder.plist; sudo launchctl unload /Library/LaunchDaemons/org.nixos.linux-builder.plist";
  #   "linux-builder-load" = "sudo launchctl load /Library/LaunchDaemons/org.nixos.linux-builder.plist";
  # };

  # nix.linux-builder = {
  #   enable = true;
  #   systems = ["x86_64-linux" "aarch64-linux"];
  #   package = pkgs.darwin.linux-builder-x86_64;
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
  #     # We have to emulate aarch64 on x86 qemu, see https://github.com/golang/go/issues/69255
  #     boot.binfmt.emulatedSystems = ["aarch64-linux"];
  #   };
  # };

  nix-rosetta-builder = {
    enable = true;
    cores = 8;
    memory = "8GiB";
    diskSize = "40GiB";
    onDemand = true;
    onDemandLingerMinutes = 60;
  };
}
