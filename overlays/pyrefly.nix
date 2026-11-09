{ ... }:
final: prev: {
  # TODO: remove when https://github.com/NixOS/nixpkgs/pull/584733 get into nixos-unstable
  pyrefly = prev.pyrefly.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.zstd ];
  });
}
