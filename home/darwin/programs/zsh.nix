{...}: {
  programs.zsh.shellAliases = {
    "linux-builder-unload" = "sudo launchctl stop /Library/LaunchDaemons/org.nixos.linux-builder.plist; sudo launchctl unload /Library/LaunchDaemons/org.nixos.linux-builder.plist";
    "linux-builder-load" = "sudo launchctl load /Library/LaunchDaemons/org.nixos.linux-builder.plist";
  };
}
