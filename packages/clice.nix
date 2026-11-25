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
      hash = "sha256-f5faPepym06xWgoXCOlBz9CU/vRN6dsdtLf9vKIxeS8=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-SjphSfREYj3ck4pDu+RXHld496ITDjM9DTqMO3jsZXc=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-pYMehcfViZtzZHSq9cLxWy+GVEOk1IWDXut2JfGomGc=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-KoiUULw2w83b7NvQHIsYKK9JYG6dY6i39aKUxItZMRA=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "clice";
  version = "1.1.2026112412";

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
