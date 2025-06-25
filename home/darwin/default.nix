{
  pkgs,
  agenix-darwin,
  ...
}: {
  imports = [
    agenix-darwin.homeManagerModules.default

    ../shared

    ./packages.nix
    ./programs
  ];

  home.packages = [
    agenix-darwin.packages."${pkgs.system}".default
  ];
}
