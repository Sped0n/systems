{ lib, pkgs, ... }:
let
  webSearches = {
    amazon = false;
    applemaps = false;
    ask = false;
    bing = false;
    drive = false;
    drivesearch = false;
    duckduckgo = false;
    ebay = false;
    facebook = false;
    flickr = false;
    gmail = false;
    gmailsearch = false;
    google = true;
    gtranslate = false;
    images = false;
    imdb = false;
    linkedin = false;
    lucky = false;
    maps = false;
    pinterest = false;
    rottentomatoes = false;
    twitter = false;
    twittersearch = false;
    twitteruser = false;
    weather = true;
    wiki = true;
    wolfram = false;
    yahoo = false;
    youtube = false;
    yubnub = false;
  };

  settings = pkgs.writeText "alfred-settings.json" (
    builtins.toJSON {
      # Install from the Gallery only if missing. Alfred owns updates thereafter.
      gallery = {
        "com.zeitlings.colorpicker" = "https://alfred.app/workflows/zeitlings/color-picker/download/";
        "com.alfredapp.vitor.currencyconverter" =
          "https://alfred.app/workflows/alfredapp/currency-converter/download/";
        "com.alfredapp.vitor.texttransformer" =
          "https://alfred.app/workflows/alfredapp/text-transformer/download/";
      };

      sharedPreferences =
        lib.mapAttrs' (
          site: enabled:
          lib.nameValuePair "features/websearch/${site}" {
            disabled = !enabled;
          }
        ) webSearches
        // {
          # Fallbacks are independent of keyword searches.
          "features/defaultresults".fallbacks = [
            "features.websearch.google.fallback"
            "features.websearch.wiki.fallback"
          ];
          "features/clipboard" = {
            persistForFiles = 1; # 7 days
            persistForImages = 1;
          };
          "features/filesearch".quicksearch = false;
          "features/filesearch/in".enabled = false;
          "features/filesearch/tag".enabled = false;
          "features/system".ejectallKeywordEnabled = true;
        };

      localPreferences."features/clipboard" = {
        enabled = true;
        enabledFiles = true;
        enabledImages = true;
      };
    }
  );
in
{
  home.activation.syncAlfred = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.python3} ${./sync_alfred.py} ${settings}
  '';
}
