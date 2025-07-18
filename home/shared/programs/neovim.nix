{
  config,
  home,
  pkgs-unstable,
  ...
}: {
  home = {
    packages = with pkgs-unstable;
      [
        neovim
      ]
      ++
      # Language supports
      [
        # nix
        nixd
        alejandra

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
    sessionVariables.EDITOR = "nvim";
  };

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink
    "${home}/.config/systems/home/shared/config/nvim/";
}
