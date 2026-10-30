{ lib, fetchurl }:

# Upgrade:
# 1. Check https://github.com/moby/profiles/commits/main/seccomp/default.json.
# 2. Review the latest profile changes and pin the full commit SHA in url.
# 3. Update hash: nix store prefetch-file --json '<url>' | jq -r .hash
fetchurl {
  name = "docker-seccomp-default.json";
  url = "https://raw.githubusercontent.com/moby/profiles/4b8214fc4971e06172938a1f1554ccff6647ee80/seccomp/default.json";
  hash = "sha256-ZBa0d3B4WkGsWQc83HfZ/phRffJ5ncg+8gfmIt4wU/Y=";

  meta = {
    description = "Docker default seccomp profile";
    homepage = "https://github.com/moby/profiles";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
