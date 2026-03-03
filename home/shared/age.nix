{ agenix, pkgs, ... }:
{
  imports = [
    agenix.homeManagerModules.default
  ];

  home.packages = with pkgs; [ agenix-cli ];

  age.identityPaths = [
    "/etc/ssh/ssh_user_ed25519_key"
  ];
}
