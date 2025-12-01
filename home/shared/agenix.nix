{
  agenix,
  determinate,
  pkgs,
  ...
}:
{
  imports = [
    agenix.homeManagerModules.default
  ];

  home.packages = [
    (agenix.packages."${pkgs.stdenv.hostPlatform.system}".default.override {
      nix = determinate.inputs.nix.packages."${pkgs.stdenv.system}".default;
    })
  ];

  age.identityPaths = [
    "/etc/ssh/ssh_user_ed25519_key"
  ];
}
