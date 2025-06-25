{
  pkgs,
  agenix,
  ...
}: {
  imports = [
    agenix.homeManagerModules.default

    ../../shared
  ];

  home.packages = [
    agenix.packages."${pkgs.system}".default
  ];
}
