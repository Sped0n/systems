{
  config,
  vars,
  ...
}: {
  programs.ssh = {
    matchBlocks = {
      "espressif-builder" = {
        hostname = vars.espressif-builder.ipv4;
        port = 12222;
        user = "espressif";
        identityFile = [
          config.age.secrets."espressif-ssh-key".path
        ];
        extraOptions = {
          "TCPKeepAlive" = "yes";
          "AddKeysToAgent" = "yes";
        };
      };
    };
  };
}
