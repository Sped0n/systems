{
  config,
  pkgs,
  pkgs-unstable,
  secrets,
  vars,
  ...
}:
{
  age.secrets = {
    "codestral-api-key" = {
      file = "${secrets}/ages/codestral-api-key.age";
      mode = "0400";
    };
  };

  programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped;
    defaultEditor = true;
    vimAlias = false;
    extraWrapperArgs = [
      "--run"
      ''
        secret_file="${config.age.secrets."codestral-api-key".path}"

        if [ -r "$secret_file" ]; then
          CODESTRAL_API_KEY="$(${pkgs.coreutils}/bin/cat "$secret_file")"
          export CODESTRAL_API_KEY
        fi
      ''
    ];
  };

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/shared/config/nvim/";

  # language supports
  home.packages = with pkgs-unstable; [
    # nix
    nixd
    nixfmt

    # toml
    taplo

    # yaml
    yaml-language-server
    prettierd

    # json
    vscode-langservers-extracted

    # bash
    bash-language-server
    shellcheck
    shfmt

    # python
    ruff
    basedpyright
    python313Packages.debugpy

    # lua
    lua-language-server
    stylua
    selene

    # golang
    gopls
    delve
    gofumpt

    # markdown
    marksman
  ];
}
