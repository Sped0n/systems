{ lib }:
let
  go =
    lhs: rhs:
    if lib.isAttrs lhs && lib.isAttrs rhs then
      lib.zipAttrsWith
        (
          _name: values:
          if builtins.length values == 1 then
            builtins.head values
          else
            go (builtins.elemAt values 0) (builtins.elemAt values 1)
        )
        [
          lhs
          rhs
        ]

    # Concatenate TOML array-of-tables (lists of attrsets)
    else if
      builtins.isList lhs
      && builtins.isList rhs
      && builtins.all lib.isAttrs lhs
      && builtins.all lib.isAttrs rhs
    then
      lhs ++ rhs

    # Default: RHS overrides
    else
      rhs;
in
go
