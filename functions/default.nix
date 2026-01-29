{ lib, ... }@ctx:
let
  dir = builtins.readDir ./.;
  names = builtins.attrNames dir;

  isNixFile =
    name: dir.${name} == "regular" && lib.strings.hasSuffix ".nix" name && name != "default.nix";

  isDirWithDefault =
    name: dir.${name} == "directory" && builtins.pathExists (./. + "/${name}/default.nix");

  selected = builtins.filter (n: isNixFile n || isDirWithDefault n) names;

  loadOne =
    entry:
    let
      path = if isNixFile entry then ./. + "/${entry}" else ./. + "/${entry}";

      raw = import path;

      # If raw is a function with arguments, try to apply it with ctx if possible
      value =
        if builtins.isFunction raw && builtins.functionArgs raw != { } then
          let
            fargs = builtins.functionArgs raw;

            # In functionArgs, value == true means "has default", false means "required"
            requiredNames = builtins.filter (n: fargs.${n} == false) (builtins.attrNames fargs);

            canApply = builtins.all (n: builtins.hasAttr n ctx) requiredNames;

            providedArgs = builtins.intersectAttrs fargs ctx;
          in
          if canApply then raw providedArgs else raw
        else
          raw;

      name = if isNixFile entry then lib.strings.removeSuffix ".nix" entry else entry;
    in
    {
      inherit name value;
    };
in
builtins.listToAttrs (map loadOne selected)
