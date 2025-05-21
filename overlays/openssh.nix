final: prev: {
  # FIXME: https://github.com/nix-community/home-manager/issues/322
  openssh = prev.openssh.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./patches/openssh.patch];
    doCheck = false;
  });
}
