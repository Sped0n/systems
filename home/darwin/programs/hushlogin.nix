{ libutils, vars, ... }:
{
  home.file."${vars.home}/.hushlogin" = {
    source = (libutils.fromRoot "/home/darwin/config/hushlogin");
  };
}
