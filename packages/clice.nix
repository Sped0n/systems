{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  releases = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-ndGBqsnIHK52slXpU9ohyeYD/FtAZEfrJsler2ftlpo=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-t+ts5lr7nNxSKdrfGxpWFIXc2ykqBtaIV81gl3FvCLo=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-KKlB2tZAzyS219dkd+4Xg1PmeoSQ7HuHv+W2EumZ7OI=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-lBrNbsTHRkRKVABkUiCc0O+Y9aNO7lCJUgAWxApB+Cw=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "clice";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/clice-io/clice/releases/download/v${finalAttrs.version}/clice-${finalAttrs.version}.${release.target}.tar.gz";
    inherit (release) hash;
  };

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/clice "$out/bin/clice"
    # clice locates Clang's builtin headers relative to its executable.
    cp -r lib "$out/lib"
    install -Dm644 LICENSE "$out/share/licenses/clice/LICENSE"
    install -Dm644 clice.toml "$out/share/doc/clice/clice.toml"

    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/clice" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "C and C++ language server and development toolkit";
    homepage = "https://github.com/clice-io/clice";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames releases;
    mainProgram = "clice";
  };
})
