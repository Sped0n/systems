{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  nix-cache-push = config.programs.nix-cache-push;
  signingKeyPath = config.age.secrets."nix-cache-signing-key".path;
  secretKeyPath = config.age.secrets."nix-cache-secret-access-key".path;
in
{
  options.programs.nix-cache-push.enable = lib.mkEnableOption "MinIO-backed Nix cache push helper";

  config = lib.mkIf nix-cache-push.enable {
    age.secrets = {
      "nix-cache-signing-key" = {
        file = "${secrets}/ages/nix-cache-signing-key.age";
        mode = "0400";
      };
      "nix-cache-secret-access-key" = {
        file = "${secrets}/ages/nix-cache-secret-access-key.age";
        mode = "0400";
      };
    };

    home.packages = [ pkgs.nix-cache-push ];

    xdg.configFile."nix-cache-push/config.json".text = builtins.toJSON {
      inherit signingKeyPath secretKeyPath;
      endpoint = "nix-cache.sped0n.com";
      bucket = "nix-cache";
      region = "us-east-1";
      accessKeyId = "writer";
    };
  };
}
