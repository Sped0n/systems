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
    extraPackages =
      (with pkgs; [
        (if stdenv.isDarwin then llvmPackages.clang else gcc)
        tree-sitter
      ])
      ++ (with pkgs-unstable; [
        nixd
        nixfmt

        lua-language-server
        stylua
        selene

        basedpyright
        ruff
        python313Packages.debugpy

        bash-language-server
        shellcheck
        shfmt

        taplo
        yaml-language-server
        vscode-langservers-extracted
        marksman
        prettierd
      ]);
    defaultEditor = true;
    vimAlias = false;
  };

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${vars.home}/.config/systems/hm/shared/programs/neovim/config";
}
