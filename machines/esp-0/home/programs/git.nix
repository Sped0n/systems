{ vars, ... }:
{
  programs.git.includes = [
    {
      condition = "gitdir:~/work/";
      contents = {
        user = with vars; {
          name = workUsername;
          email = workEmail;
          signingKey = "C7BF73736F30C087C629A12F674DD956AB0F0EE7";
        };
        core.excludesFile = "~/.config/git/ignore-work";
      };
    }
  ];

  xdg.configFile."git/ignore-work".text = ''
    .envrc
    .clangd
  '';
}
