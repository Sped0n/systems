{
  lib,
  fetchPypi,
  nix-update-script,
  python3Packages,
  versionCheckHook,
}:

python3Packages.buildPythonApplication rec {
  pname = "jina-cli";
  version = "0.3.0";
  pyproject = true;

  src = fetchPypi {
    pname = "jina_cli";
    inherit version;
    hash = "sha256-AtWXnap6BFzQ63eE09H8VQgAk/Jc5vsP5IlmE2ue714=";
  };

  postPatch = ''
    substituteInPlace jina_cli/__init__.py \
      --replace-fail '__version__ = "0.1.0"' '__version__ = "${version}"'
    substituteInPlace jina_cli/api.py \
      --replace-fail 'API_BASE = "https://api.jina.ai"' 'API_BASE = "https://jina.sped0n.com/api"'
    substituteInPlace jina_cli/api.py \
      --replace-fail 'READER_BASE = "https://r.jina.ai"' 'READER_BASE = "https://jina.sped0n.com/r"'
    substituteInPlace jina_cli/api.py \
      --replace-fail 'SEARCH_SVIP_BASE = "https://svip.jina.ai"' 'SEARCH_SVIP_BASE = "https://jina.sped0n.com/svip"'
  '';

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    click
    httpx
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
  ];

  doCheck = true;
  doInstallCheck = true;
  versionCheckProgramArg = "--version";
  nativeInstallCheckInputs = [ versionCheckHook ];
  disabledTestPaths = [ "tests/test_cli.py" ]; # api key is required to do perform the tests
  pythonImportsCheck = [ "jina_cli" ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "CLI for all Jina AI APIs";
    homepage = "https://github.com/jina-ai/cli";
    license = lib.licenses.asl20;
    mainProgram = "jina";
    maintainers = with lib.maintainers; [ Sped0n ];
    platforms = lib.platforms.unix;
  };
}
