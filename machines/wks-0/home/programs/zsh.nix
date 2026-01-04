{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
{
  age.secrets = {
    "openai-api-key" = {
      file = "${secrets}/ages/openai-api-key.age";
      mode = "0400";
    };
  };

  programs.zsh.initContent = lib.mkOrder 1500 ''
    export OPENAI_API_KEY=$(${pkgs.coreutils}/bin/cat ${config.age.secrets."openai-api-key".path})
  '';
}
