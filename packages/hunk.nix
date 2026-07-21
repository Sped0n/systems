{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchzip,
  gnused,
  nix,
  versionCheckHook,
  writeShellApplication,
  writableTmpDirAsHomeHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "hunk";
  version = "0.17.3";

  src = fetchzip (
    builtins.getAttr stdenv.hostPlatform.system {
      aarch64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-arm64.tar.gz";
        hash = "sha256-Q4UZHlSXAkuMuZvW8/uMBLMnKErhOA0zzwCbUpnWfug=";
      };
      x86_64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-x64.tar.gz";
        hash = "sha256-BxGQ6RdekO0oZSfiCeLfpYxFlBVTvYIUvofUW8O4+98=";
      };
      aarch64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-arm64.tar.gz";
        hash = "sha256-f83eGf5tGRwKAq7gZxTabIeSdxjc0OMYankfv+8y4Fw=";
      };
      x86_64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-x64.tar.gz";
        hash = "sha256-VHnB3+RBlDcdd0ix8of0hdbRAHTRsc0v9ATd5vkKTrc=";
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

  # nix run -f packages hunk.passthru.updateScriptPackage -- $VERSION
  passthru = {
    updateScript = [ (lib.getExe finalAttrs.passthru.updateScriptPackage) ];
    updateScriptPackage = writeShellApplication {
      name = "update-hunk";
      runtimeInputs = [
        gnused
        nix
      ];
      text = ''
        version="''${1:-${finalAttrs.version}}"
        package_file="packages/hunk.nix"

        if [ ! -f "$package_file" ]; then
          printf 'error: run from repository root so %s exists\n' "$package_file" >&2
          exit 1
        fi

        for archive in \
          hunkdiff-darwin-arm64 \
          hunkdiff-darwin-x64 \
          hunkdiff-linux-arm64 \
          hunkdiff-linux-x64
        do
          url="https://github.com/modem-dev/hunk/releases/download/v$version/$archive.tar.gz"
          printf '%s\n' "$archive"
          hash="$(nix store prefetch-file --json --unpack "$url" | sed -n 's/.*"hash":"\([^"]*\)".*/\1/p')"
          sed -i "/$archive.tar.gz/{n;s#hash = \".*\";#hash = \"$hash\";#}" "$package_file"
        done

        sed -i "0,/  version = \".*\";/s//  version = \"$version\";/" "$package_file"
      '';
    };
  };

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
