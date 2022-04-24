{ lib
, buildPythonPackage
, coverage
, django
, factory_boy
, fetchFromGitHub
, isPy3k
, pylint-plugin-utils
, pytestCheckHook
}:

buildPythonPackage rec {
  pname = "pylint-django";
  version = "2.5.2";
  disabled = !isPy3k;

  src = fetchFromGitHub {
    owner = "PyCQA";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-VgGdV1T154LauclGo6jpLPUrYn5vTOWwvO4IXQ9se7c=";
  };

  propagatedBuildInputs = [
    django
    pylint-plugin-utils
  ];

  checkInputs = [
    coverage
    factory_boy
    pytestCheckHook
  ];

  disabledTests = [
    # Skip outdated tests and the one with a missing dependency (django_tables2)
    "external_django_tables2_noerror_meta_class"
    "external_factory_boy_noerror"
    "func_noerror_foreign_key_attributes"
    "func_noerror_foreign_key_key_cls_unbound"
  ];

  pythonImportsCheck = [
    "pylint_django"
  ];

  meta = with lib; {
    description = "Pylint plugin to analyze Django applications";
    homepage = "https://github.com/PyCQA/pylint-django";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ kamadorueda ];
  };
}
