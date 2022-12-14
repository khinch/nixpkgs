{ lib
, buildPythonPackage
, fetchPypi
, hatchling
, ipykernel
}:

buildPythonPackage rec {
  pname = "metakernel";
  version = "0.29.4";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-kxrF/Msxjht7zGs0aEcL/Sf0qwcLiSoDPDUlE7Lrcmg=";
  };

  nativeBuildInputs = [
    hatchling
  ];

  propagatedBuildInputs = [ ipykernel ];

  # Tests hang, so disable
  doCheck = false;

  meta = with lib; {
    description = "Jupyter/IPython Kernel Tools";
    homepage = "https://github.com/Calysto/metakernel";
    license = licenses.bsd3;
    maintainers = with maintainers; [ thomasjm ];
  };
}
