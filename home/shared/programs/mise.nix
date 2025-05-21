{pkgs-unstable, ...}: {
  programs.mise = {
    enable = true;
    package = pkgs-unstable.mise;
    enableZshIntegration = true;
    globalConfig = {
      settings = {
        disable_hints = ["python_multi"];
        trusted_config_paths = ["~"];
      };

      tools = {
        # NOTE:
        #
        # For NixOS, mise install python in below nix-shell
        # https://nixos.wiki/wiki/FAQ/I_installed_a_library_but_my_compiler_is_not_finding_it._Why%3F
        #
        # ```
        # nix-shell -p gcc zlib readline bzip2\
        # openssl pkg-config xz sqlite ncurses5\
        # libffi mpdecimal autoconf-archive autoreconfHook\
        # nukeReferences expat libuuid tk tcl xorg.libX11\
        # xorg.xorgproto patch
        # ```
        #
        # - Also, py3.11 will have libffi and ncurses warning, so
        #   we use 3.12
        # - Last working version is 3.12.10
        # - For the needed package, check nixpkgs python source
        # python = "3.12";
      };
    };
  };
}
