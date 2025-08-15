{
  # pkgs-qemu8,
  secrets,
  vars,
  ...
}: {
  # see https://github.com/golang/go/issues/69255
  # nixpkgs.overlays = [
  #   # NOTE: as for the naming, see
  #   # - https://github.com/NixOS/nixpkgs/blob/a59eb7800787c926045d51b70982ae285faa2346/pkgs/applications/virtualization/qemu/default.nix#L140C3-L147C21
  #   # - https://github.com/NixOS/nixpkgs/blob/b134951a4c9f3c995fd7be05f3243f8ecd65d798/pkgs/applications/virtualization/qemu/default.nix#L53C3-L57C45
  #   (self: super: {qemu-user = pkgs-qemu8.qemu;})
  # ];

  age.secrets = {
    "server-ssh-key" = {
      path = "/root/.ssh/id_server";
      file = "${secrets}/ages/server-ssh-key.age";
      owner = "root";
      mode = "0400";
    };
  };

  home-manager = {
    users.root = {...}: {
      home = {
        enableNixpkgsReleaseCheck = false;
        stateVersion = "24.11";
      };
      programs.ssh = let
        serverTmpl = {
          port = 12222;
          user = "root";
          identityFile = ["/root/.ssh/id_server"];
          extraOptions = {
            "TCPKeepAlive" = "yes";
            "AddKeysToAgent" = "yes";
          };
        };
      in {
        enable = true;
        matchBlocks = {
          "tennousei" = {hostname = vars.tennousei.ipv4;} // serverTmpl;
          "_tennousei" = {
            match = ''
              host tennousei exec "tailscale status"
            '';
            hostname = "tennousei";
          };

          "tsuki" = {hostname = vars.tsuki.ipv4;} // serverTmpl;
          "_tsuki" = {
            match = ''
              host tsuki exec "tailscale status"
            '';
            hostname = "tsuki";
          };
        };
      };
    };
  };
}
