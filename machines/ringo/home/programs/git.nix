{vars, ...}: {
  programs.git = {
    includes = [
      {
        contents = {
          user = {
            name = vars.workUsername;
            email = vars.workEmail;
            signingKey = "C7BF73736F30C087C629A12F674DD956AB0F0EE7";
          };
        };
        condition = "gitdir:~/work/";
      }
    ];
  };
}
