{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:
buildGoModule rec {
  pname = "diun";
  version = "4.31.0"; # <-- Update this when a new version is released

  src = fetchFromGitHub {
    owner = "crazy-max";
    repo = "diun";
    rev = "v${version}";
    # Get this hash by running:
    # nix run nixpkgs#nix-prefetch-github -- crazy-max diun --rev v${version}
    hash = "sha256-H05yZSH2rUrwM+ZR/PDCxXmrDkZ/Gd4RrpywGk5eW2A="; # <-- Update this when a new version is released
  };
  vendorHash = null;

  # upstream disable CGO in release build
  # https://github.com/crazy-max/diun/blob/76c0fe99212adc58d6a3433bbcde1ffa9fb879c4/Dockerfile#L11
  env.CGO_ENABLED = false;

  ldflags = [
    "-s"
    "-w"
    "-X"
    "main.version=${version}"
  ];

  doCheck = false; # Tests require a network connection.
  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;

  postInstall = ''
    mv $out/bin/cmd $out/bin/diun
  '';

  meta = with lib; {
    description = "CLI application to receive notifications when a Docker image is updated on a Docker registry";
    homepage = "https://github.com/crazy-max/diun";
    license = licenses.mit;
    mainProgram = "diun";
    maintainers = with maintainers; [ Sped0n ];
    platforms = platforms.unix;
  };
}
