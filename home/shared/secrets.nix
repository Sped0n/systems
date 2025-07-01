{
  lib,
  pkgs,
  config,
  secrets,
  home,
  ...
}: {
  age = {
    identityPaths = [
      "${home}/.config/secrets/id_agenix"
    ];

    secrets = let
      readable = {
        mode = "0500";
      };
    in {
      "github-ssh-key" =
        {
          path = "${home}/.ssh/id_github";
          file = "${secrets}/ages/github-ssh-key.age";
        }
        // readable;

      "openai-api-key" =
        {
          file = "${secrets}/ages/openai-api-key.age";
        }
        // readable;
    };
  };

  # for unknown reason, home manager session variable does not work here
  programs.zsh = {
    initContent = lib.mkMerge [
      (lib.mkOrder 1550 ''
        export OPENAI_API_KEY="$(${pkgs.coreutils}/bin/cat ${config.age.secrets."openai-api-key".path})"
      '')
    ];
  };
}
