{
  config,
  pkgs-unstable,
  vars,
  ...
}:
{
  programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped;
    defaultEditor = true;
    vimAlias = false;
  };

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/home/raw/neovim/";

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
