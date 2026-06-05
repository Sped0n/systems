{ ... }:
final: prev:
let
  ccacheDir = "/nix/var/cache/ccache";
in
{
  ccacheWrapper = prev.ccacheWrapper.override {
    extraConfig = ''
      export CCACHE_COMPRESS=1
      export CCACHE_SLOPPINESS=random_seed
      export CCACHE_UMASK=007
      export CCACHE_COMPILERCHECK=content
      export CCACHE_NOHASHDIR=1
      export CCACHE_DIR="${ccacheDir}"

      if [ ! -d "${ccacheDir}" ]; then
        echo "====="
        echo "Directory ${ccacheDir} does not exist"
        echo "Please create it with:"
        echo "  sudo install -d -m 0755 -o root -g nixbld ${dirOf ccacheDir}"
        echo "  sudo install -d -m 0770 -o root -g nixbld ${ccacheDir}"
        echo "====="
        exit 1
      fi

      if [ ! -w "${ccacheDir}" ]; then
        echo "====="
        echo "Directory ${ccacheDir} is not accessible for user $(whoami)"
        echo "Please verify its access permissions"
        echo "====="
        exit 1
      fi
    '';
  };
}
