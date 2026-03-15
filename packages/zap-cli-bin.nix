{
  fetchzip,
  lib,
  makeWrapper,
  nodePackages,
  nodejs_20,
  stdenvNoCC,
}:
let
  inherit (stdenvNoCC.hostPlatform) isDarwin isLinux;

  sources = {
    x86_64-linux = {
      url = "https://github.com/project-chip/zap/releases/download/v2026.02.26/zap-linux-x64.zip";
      hash = "sha256-lpcPddY3p4FhZzEzNgI29k4Ol4XchzKpoEoDNHIt6xw=";
    };
    aarch64-linux = {
      url = "https://github.com/project-chip/zap/releases/download/v2026.02.26/zap-linux-arm64.zip";
      hash = "sha256-aFDr5avCHdB7NVdsUdcLLA1FGd+Fdj1TjrKfL65zy1U=";
    };
    x86_64-darwin = {
      url = "https://github.com/project-chip/zap/releases/download/v2026.02.26/zap-mac-x64.zip";
      hash = "sha256-AUlQ28CDX5eCQwbOOsWFTVuPYTmDcszTAlcdUVZKzmk=";
    };
    aarch64-darwin = {
      url = "https://github.com/project-chip/zap/releases/download/v2026.02.26/zap-mac-arm64.zip";
      hash = "sha256-lkEb3zmBkMkwPaYAaDG5j7j3lfnDb+DgE01AMNHichk=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "zap-cli-bin is unsupported on ${stdenvNoCC.hostPlatform.system}");

  linuxMainProcess = "${placeholder "out"}/libexec/zap-cli-app/dist/src-electron/main-process/main.js";
in
stdenvNoCC.mkDerivation {
  pname = "zap-cli-bin";
  version = "2026.02.26";

  src = fetchzip {
    inherit (source) url hash;
    stripRoot = false;
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = lib.optionals isLinux [
    makeWrapper
    nodePackages.asar
  ];

  doInstallCheck = true;

  installPhase = ''
    runHook preInstall

    install -d "$out/bin" "$out/libexec/zap-cli-bin"
    cp -R ./. "$out/libexec/zap-cli-bin"

    ${lib.optionalString isLinux ''
      asar extract "$out/libexec/zap-cli-bin/resources/app.asar" "$out/libexec/zap-cli-app"

      makeWrapper ${lib.getExe nodejs_20} "$out/bin/zap-cli" \
        --argv0 zap-cli \
        --add-flags ${lib.escapeShellArg linuxMainProcess}

      makeWrapper ${lib.getExe nodejs_20} "$out/bin/zap" \
        --argv0 zap \
        --add-flags ${lib.escapeShellArg linuxMainProcess}
    ''}

    ${lib.optionalString isDarwin ''
      ln -s "$out/libexec/zap-cli-bin/zap-cli" "$out/bin/zap-cli"

      if [ -x "$out/libexec/zap-cli-bin/zap.app/Contents/MacOS/zap" ]; then
        ln -s "$out/libexec/zap-cli-bin/zap.app/Contents/MacOS/zap" "$out/bin/zap"
      fi
    ''}

    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    if ! "$out/bin/zap-cli" --version; then
      "$out/bin/zap-cli" -v
    fi

    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Prebuilt ZAP release assets packaged for Project CHIP";
    homepage = "https://github.com/project-chip/zap";
    license = licenses.asl20;
    mainProgram = "zap-cli";
    platforms = platforms.unix;
  };
}
