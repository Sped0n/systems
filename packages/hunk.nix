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
  version = "0.17.1";

  src = fetchzip (
    builtins.getAttr stdenv.hostPlatform.system {
      aarch64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-arm64.tar.gz";
        hash = "sha256-v/NhLy8EX9xRntkwLuqEt7/OlTLjJpgxG7cksKqJVHY=";
      };
      x86_64-darwin = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-darwin-x64.tar.gz";
        hash = "sha256-sCaZR2cuRdbae+F1UUiejftlD+mcmwKioks7S9qR7r0=";
      };
      aarch64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-arm64.tar.gz";
        hash = "sha256-62MnqUDAyJsmsSnUFgvunFEQaUjpAitPXIhl7KmpoQU=";
      };
      x86_64-linux = {
        url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/hunkdiff-linux-x64.tar.gz";
        hash = "sha256-IdezOc+tXmtg8RXx/9vk3oaSuoSSsWVWHJrY/iP/h9w=";
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
