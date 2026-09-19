{ vars, ... }:
{
  imports = [
    ./casks.nix
    ./mas.nix
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
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
