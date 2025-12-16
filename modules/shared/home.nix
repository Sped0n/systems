{
  config,
  specialArgs,
  vars,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      systemConfig = config;
    }
    // specialArgs;
    users.${vars.username}.home = {
      enableNixpkgsReleaseCheck = false;
      stateVersion = "24.11";
    };
  };
}
