{
  config,
  pkgs,
  pkgs-unstable,
  vars,
  ...
}:
{
  programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped;
    extraPackages = with pkgs; [ (if stdenv.isDarwin then llvmPackages.clang else gcc) ];
    defaultEditor = true;
    vimAlias = false;
  };

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/hm/shared/programs/neovim/config";

  home.packages =
    with pkgs-unstable;
    # tree-sitter CLI
    [ tree-sitter ]
    ++
      # language supports
      [
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
