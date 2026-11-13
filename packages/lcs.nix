{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  makeWrapper,
  git,
  bash,
  zsh,
}:
buildGo126Module {
  pname = "lcs";
  version = "0-unstable-2026-11-13";

  src = fetchFromGitHub {
    owner = "Sped0n";
    repo = "lcs";
    rev = "d42fc761f952c5db2e0ac4313b4c85876dc7239a";
    hash = "sha256-oB+oxAQMwqgt0hQgsnA/oBINa5AVLUP+Smya3msjq0s=";
  };

  vendorHash = "sha256-4vLAZJXSNoTaDVx1OFLGYp2IZh8tU8lzObsW/gGTPYY=";
  subPackages = [ "cmd/lcsctl" ];

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [
    git
    bash
    zsh
  ];

  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  postInstall = ''
    wrapProgram $out/bin/lcsctl --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  meta = {
    description = "Local cache for selected public HTTPS Git repositories";
    homepage = "https://github.com/Sped0n/lcs";
    mainProgram = "lcsctl";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
