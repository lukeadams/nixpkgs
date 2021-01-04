{ lib, buildPythonPackage, fetchPypi, isPy3k, pytest, mock, brotli, certifi }:

buildPythonPackage rec {
  pname = "Logentries";
  version = "0.17";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1p5039r92730v3h435ni1kqvj77q2cs27n3q6wybyr3zazvsw504";
  };

  # checkInputs = [ pytest ] ++ lib.optionals (!isPy3k) [ mock ];

  propagatedBuildInputs = [ certifi ];

  doCheck = false;

  meta = {
    homepage = "https://pythonhosted.org/Logbook/";
    description = "A logging replacement for Python";
    license = lib.licenses.bsd3;
  };
}
