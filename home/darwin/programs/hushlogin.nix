{home, ...}: {
  home.file."${home}/.hushlogin" = {
    source = ../config/hushlogin;
  };
}
