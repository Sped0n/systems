{
  agenix,
  pkgs,
  ...
}:
{
  imports = [
    agenix.homeManagerModules.default
  ];

  home.packages = [
    agenix.packages."${pkgs.system}".default
  ];

  age.identityPaths = [
    "/etc/ssh/ssh_user_ed25519_key"
  ];
}
