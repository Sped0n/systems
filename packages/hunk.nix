{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchzip,
  nix,
  versionCheckHook,
  writeShellApplication,
  writableTmpDirAsHomeHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "hunk";
  version = "0.15.3";

  src = fetchzip (
    builtins.getAttr stdenv.hostPlatform.system {
      aarch64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-arm64.tar.gz";
        hash = "sha256-RlhDqefYcVoYyTWraJzcnLO6MIRuxMJe6usv7dK0MiQ=";
      };
      x86_64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-x64.tar.gz";
        hash = "sha256-xtEPzHODi2hlVe1tv0S3QZ7Xf6IxrRDx78fiIVTvRfY=";
      };
      aarch64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-arm64.tar.gz";
        hash = "sha256-QwRXFNYGuDwZbM2zsReGCngIpcz52EqMzbzLYrTiO+k=";
      };
      x86_64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-x64.tar.gz";
        hash = "sha256-exsPtSk7WWYty5TsNGSbBt9XrI/BDSCh1pYvXYto0Z4=";
      };
    }
  );

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.libc ];

  installPhase = ''
    runHook preInstall

    install -Dm755 ${finalAttrs.src}/hunk $out/bin/hunk
    cp -R ${finalAttrs.src}/skills $out/skills

    runHook postInstall
  '';

  # Bun standalone executables keep application payload in ELF sections that strip breaks.
  dontStrip = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckProgramArg = "--version";

  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/hunk --version | grep -F ${finalAttrs.version}
    test -f "$($out/bin/hunk skill path)"

    runHook postInstallCheck
  '';

  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "update-hunk";
    runtimeInputs = [ nix ];
    text = ''
      version="''${1:-${finalAttrs.version}}"

      for archive in \
        hunkdiff-darwin-arm64 \
        hunkdiff-darwin-x64 \
        hunkdiff-linux-arm64 \
        hunkdiff-linux-x64
      do
        url="https://github.com/modem-dev/hunk/releases/download/v$version/$archive.tar.gz"
        printf '%s\n' "$archive"
        nix store prefetch-file --unpack "$url"
      done
    '';
  });

  meta = {
    description = "Terminal diff viewer for agentic changesets";
    homepage = "https://github.com/modem-dev/hunk";
    changelog = "https://github.com/modem-dev/hunk/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = lib.platforms.unix;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
