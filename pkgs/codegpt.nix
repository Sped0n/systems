{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:
buildGoModule rec {
  pname = "codegpt";
  version = "1.0.0"; # <-- Update this when a new version is released

  src = fetchFromGitHub {
    owner = "appleboy";
    repo = "CodeGPT";
    rev = "v${version}";
    # Get this hash by running:
    # nix run nixpkgs#nix-prefetch-github -- appleboy CodeGPT --rev v${version}
    hash = "sha256-tMAjRjImovjjZqpZrW9saZVgvLmuHDRB1TsQiPhOMG4="; # <-- Update this when a new version is released
  };

  # To obtain the actual hash, set vendorHash = lib.fakeHash; and run the build
  # you will get a error message with the real vendorHash
  vendorHash = "sha256-NR4qSLzS5ipOO9qUzfEwS8HW4c9rN8b8EuhX0hNW0bw="; # <-- Update this when a new version is released

  ldflags = [
    "-s"
    "-w"
    "-X github.com/appleboy/CodeGPT/cmd.Version=v${version}"
    "-X github.com/appleboy/CodeGPT/cmd.Commit=v${version}"
  ];

  # Add git as a dependency needed during the test phase
  nativeBuildInputs = [git];

  meta = with lib; {
    description = "CLI to generate git commit messages or code reviews using ChatGPT AI";
    homepage = "https://github.com/appleboy/CodeGPT";
    license = licenses.mit;
    maintainers = with maintainers; [Sped0n];
    platforms = platforms.unix;
  };
}
