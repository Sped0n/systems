{
  config,
  pkgs,
  secrets,
  ...
}:
{
  age.secrets."id-forgejo" = {
    file = "${secrets}/ages/srv-de-0-id-forgejo.age";
    owner = "git";
    group = "git";
    mode = "0400";
  };

  users.groups.git = { };
  users.users.git = {
    isSystemUser = true;
    group = "git";
    shell = "${(pkgs.writeShellScriptBin "forgejo-shell" ''
      #!/bin/sh
      shift
      ${pkgs.openssh}/bin/ssh \
        -i ${config.age.secrets."id-forgejo".path} \
        -p 12223 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        git@127.0.0.1 "SSH_ORIGINAL_COMMAND=\"$SSH_ORIGINAL_COMMAND\" $@"
    '')}/bin/forgejo-shell";
  };

  environment.etc."ssh/forgejo-authorized-keys-command" = {
    mode = "0555";
    text = ''
      #!${pkgs.bash}/bin/bash
      exec ${pkgs.openssh}/bin/ssh \
        -i ${config.age.secrets."id-forgejo".path} \
        -p 12223 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        git@127.0.0.1 \
        /usr/local/bin/gitea keys -e git -u "$1" -t "$2" -k "$3"
    '';
  };

  services.openssh.extraConfig = ''
    Match User git
      PasswordAuthentication no
      AuthorizedKeysCommandUser git
      AuthorizedKeysCommand /etc/ssh/forgejo-authorized-keys-command %u %t %k
  '';
}
