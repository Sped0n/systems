{ ... }:
final: prev: {
  cdecl = prev.cdecl.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/pjl_config.h \
        --replace-fail '#include <attribute.h>' '#include <attribute.h>

      #ifndef unreachable
      # if defined __GNUC__ || defined __clang__
      #  define unreachable() __builtin_unreachable()
      # endif
      #endif'
    '';
  });
}
