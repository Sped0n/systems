{ ... }:
final: prev: {
  # cargo-setup-hook requires onig_sys to use the system oniguruma library.
  neocmakelsp = prev.neocmakelsp.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.oniguruma ];
  });
}
