{
  specialArgs,
  vars,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
    users.${vars.username}.home = {
      enableNixpkgsReleaseCheck = false;
      stateVersion = "24.11";
    };
  };
}
