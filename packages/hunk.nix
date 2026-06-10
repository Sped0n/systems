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
  version = "0.15.0";

  src = fetchzip (
    builtins.getAttr stdenv.hostPlatform.system {
      aarch64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-arm64.tar.gz";
        hash = "sha256-3fb/fPpWkSUd9269ecpYsLd2rIN2EV0bd0ajA4oChQ4=";
      };
      x86_64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-x64.tar.gz";
        hash = "sha256-yPE8CXw7KmsT7Ylvufn01OhkRmpgPm0z7wgzOc1sAFg=";
      };
      aarch64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-arm64.tar.gz";
        hash = "sha256-bw8jfq8lD9sWiGfRRzCmBdbRXfvIhxhXXPIjDrpnhUM=";
      };
      x86_64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-x64.tar.gz";
        hash = "sha256-hnP1IAgIB5+hmQFCSGLEK2MbkpAYhiv0yKe8dmMhw/Y=";
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
