{ pkgs }:
{
  privateKey = pkgs.writeText "darwin-builder_ed25519" ''
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
    QyNTUxOQAAACAqnTaad/3LngXKzmLb+97cmzv39AxizxOrF4PbG15NrAAAAJBqc7rzanO6
    8wAAAAtzc2gtZWQyNTUxOQAAACAqnTaad/3LngXKzmLb+97cmzv39AxizxOrF4PbG15NrA
    AAAEB3nhRz8AEb1NHuums1ZzaaH6JqYr+ZYV69yu8iC/ja6yqdNpp3/cueBcrOYtv73tyb
    O/f0DGLPE6sXg9sbXk2sAAAAC25peC1idWlsZGVyAQI=
    -----END OPENSSH PRIVATE KEY-----
  '';

  publicKey = pkgs.writeText "darwin-builder_ed25519.pub" ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICqdNpp3/cueBcrOYtv73tybO/f0DGLPE6sXg9sbXk2s darwin-builder
  '';
}
