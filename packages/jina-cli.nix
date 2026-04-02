{
  lib,
  fetchFromGitHub,
  nix-update-script,
  python3Packages,
  versionCheckHook,
}:

python3Packages.buildPythonApplication rec {
  pname = "jina-cli";
  version = "0.4.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Sped0n";
    repo = "jina-cli";
    tag = "v${version}";
    hash = "sha256-D6g5Cu93GXJ9fbbvTHjju87xQWPCepjVmDZqTi1f7/Q=";
  };

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
