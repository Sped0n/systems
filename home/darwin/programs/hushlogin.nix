{ functions, vars, ... }:
{
  home.file."${vars.home}/.hushlogin" = {
    source = (functions.fromRoot "/home/darwin/config/hushlogin");
  };
}
