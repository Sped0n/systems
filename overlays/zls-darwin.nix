final: prev: {
  # FIXME: see https://github.com/zigtools/zls/issues/2221
  zls-darwin = prev.zls.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ./zls-darwin.patch
      ];
  });
}
