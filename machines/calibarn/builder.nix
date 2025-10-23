{
  pkgs-qemu8,
  secrets,
  vars,
  ...
}:
{
  # TODO: already fixed by https://github.com/golang/go/commit/2a7f1d47b0650c92b47f0cd5bc3536d438e4bbbe
  #       remove this after the all go related package port to go 1.26
  nixpkgs.overlays = [
    # NOTE: as for the naming, see
    # - https://github.com/NixOS/nixpkgs/blob/a59eb7800787c926045d51b70982ae285faa2346/pkgs/applications/virtualization/qemu/default.nix#L140C3-L147C21
    # - https://github.com/NixOS/nixpkgs/blob/b134951a4c9f3c995fd7be05f3243f8ecd65d798/pkgs/applications/virtualization/qemu/default.nix#L53C3-L57C45
    (self: super: { qemu-user = pkgs-qemu8.qemu; })
  ];

  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

  nix = {
    gc = {
      dates = "*-01/2-01 00:00";
      options = "--delete-older-than 60d";
    };
    settings = {
      keep-outputs = true;
      keep-derivations = true;
    };
  };

  age.secrets = {
    "server-ssh-key" = {
      path = "/root/.ssh/id_server";
      file = "${secrets}/ages/server-ssh-key.age";
      owner = "root";
      mode = "0400";
    };
  };

  home-manager = {
    users.root =
      { ... }:
      {
        home = {
          enableNixpkgsReleaseCheck = false;
          stateVersion = "24.11";
        };
        programs.ssh =
          let
            serverTmpl = {
              port = 12222;
              user = "root";
              identityFile = [ "/root/.ssh/id_server" ];
              extraOptions = {
                "TCPKeepAlive" = "yes";
                "AddKeysToAgent" = "yes";
              };
            };
          in
          {
            enable = true;
            matchBlocks = {
              "unicorn" = {
                hostname = vars.unicorn.ipv4;
              }
              // serverTmpl;
              "_unicorn" = {
                match = ''
                  host unicorn exec "tailscale status"
                '';
                hostname = "unicorn";
              };

              "exia" = {
                hostname = vars.exia.ipv4;
              }
              // serverTmpl;
              "_exia" = {
                match = ''
                  host exia exec "tailscale status"
                '';
                hostname = "exia";
              };

              "banshee" = {
                hostname = vars.banshee.ipv4;
              }
              // serverTmpl;
            };
          };
      };
  };
}
