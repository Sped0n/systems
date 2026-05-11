{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "hunk";
  version = "0.11.1";

  src = fetchzip {
    url = "https://github.com/modem-dev/hunk/releases/download/v${finalAttrs.version}/staged-prebuilt-npm-release.tar.gz";
    hash = "sha256-77ybEnz5ikYXZXXUmqGLIKDbm0mHxiyTxoVQsZJw2hs=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ${
      finalAttrs.passthru.platformPackages.${stdenv.hostPlatform.system}
    }/bin/hunk $out/bin/hunk
    cp -R hunkdiff/skills $out/skills

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/hunk --version | grep -F ${finalAttrs.version}
    test -f "$($out/bin/hunk skill path)"

    runHook postInstallCheck
  '';

  passthru = {
    platformPackages = {
      x86_64-linux = "hunkdiff-linux-x64";
      aarch64-linux = "hunkdiff-linux-arm64";
      x86_64-darwin = "hunkdiff-darwin-x64";
      aarch64-darwin = "hunkdiff-darwin-arm64";
    };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Terminal diff viewer for agentic changesets";
    homepage = "https://github.com/modem-dev/hunk";
    changelog = "https://github.com/modem-dev/hunk/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = builtins.attrNames finalAttrs.passthru.platformPackages;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
