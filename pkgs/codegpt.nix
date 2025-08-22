{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:
buildGoModule rec {
  pname = "codegpt";
  version = "1.1.1"; # <-- Update this when a new version is released

  src = fetchFromGitHub {
    owner = "appleboy";
    repo = "CodeGPT";
    rev = "v${version}";
    # Get this hash by running:
    # nix run nixpkgs#nix-prefetch-github -- appleboy CodeGPT --rev v${version}
    hash = "sha256-GEdMJgLSqzMdsd/dq7EOSErOphWQT72tF//TEaVzIug="; # <-- Update this when a new version is released
  };

  # To obtain the actual hash, set vendorHash = lib.fakeHash; and run the build
  # you will get a error message with the real vendorHash
  vendorHash = "sha256-zABhgwgJTUiPAYRNzIuj5AbPHnTa9FSNxE3Mp7ajYX4="; # <-- Update this when a new version is released

  ldflags = [
    "-s"
    "-w"
    "-X github.com/appleboy/CodeGPT/version.Version=v${version}"
    "-X github.com/appleboy/CodeGPT/version.GitCommit=${src.rev}"
  ];

  # Add git as a dependency needed during the test phase
  nativeBuildInputs = [ git ];

  meta = with lib; {
    description = "CLI to generate git commit messages or code reviews using ChatGPT AI";
    homepage = "https://github.com/appleboy/CodeGPT";
    license = licenses.mit;
    maintainers = with maintainers; [ Sped0n ];
    platforms = platforms.unix;
  };
}
