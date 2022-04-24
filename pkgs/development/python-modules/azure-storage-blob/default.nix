{ lib
, buildPythonPackage
, fetchPypi
, azure-common
, azure-core
, azure-storage-common
, msrest
, isPy3k
, futures ? null
}:

buildPythonPackage rec {
  pname = "azure-storage-blob";
  version = "12.11.0";

  src = fetchPypi {
    inherit pname version;
    extension = "zip";
    sha256 = "sha256-SVNbMZC7adDZ/3o4MkaxTaTSsb3/YMrl+Rc5IMZ8p+4=";
  };

  propagatedBuildInputs = [
    azure-common
    azure-core
    azure-storage-common
    msrest
  ] ++ lib.optional (!isPy3k) futures;

  # has no tests
  doCheck = false;

  meta = with lib; {
    description = "Client library for Microsoft Azure Storage services containing the blob service APIs";
    homepage = "https://github.com/Azure/azure-sdk-for-python";
    license = licenses.mit;
    maintainers = with maintainers; [ cmcdragonkai maxwilson ];
  };
}
