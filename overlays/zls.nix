final: prev: {
  # FIXME: see https://github.com/zigtools/zls/issues/2221
  zls = prev.zls.overrideAttrs (old: {
    version = "git";
    src = prev.fetchFromGitHub {
      owner = "Sped0n";
      repo = "zls";
      rev = "28c2a5a5e1f4b7b9880223136c65d2c921955c6e";
      fetchSubmodules = true;
      hash = "sha256-7+9wyaip/pbL37b3oNm7xj6ylHHpm9FZDyvh002+LcY=";
    };
  });
}
