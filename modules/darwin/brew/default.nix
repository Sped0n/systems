{ vars, ... }:
{
  imports = [
    ./casks.nix
    ./mas.nix
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "${vars.username}";
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };
  };
}
