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
