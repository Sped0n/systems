{ functions, vars, ... }:
{
  home.file."${vars.home}/.hushlogin" = {
    source = (functions.fromRoot "/hm/darwin/config/hushlogin");
  };
}
