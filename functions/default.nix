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

      # If the imported value is a function with attrset-formals (functionArgs != {}),
      # we auto-apply ctx (filtered to only keys that exist in ctx).
      value =
        if builtins.isFunction raw && builtins.functionArgs raw != { } then
          let
            argNames = builtins.attrNames (builtins.functionArgs raw);
            providedNames = builtins.filter (n: builtins.hasAttr n ctx) argNames;
            providedArgs = builtins.listToAttrs (
              map (n: {
                name = n;
                value = ctx.${n};
              }) providedNames
            );
          in
          raw providedArgs
        else
          raw;

      name = if isNixFile entry then lib.strings.removeSuffix ".nix" entry else entry;
    in
    {
      inherit name value;
    };
in
builtins.listToAttrs (map loadOne selected)
