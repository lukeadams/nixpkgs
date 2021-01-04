{ lib, buildPythonPackage, fetchPypi, isPy3k, pytest, mock, brotli, certifi }:

buildPythonPackage rec {
  pname = "smbus2";
  version = "0.4.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "19l3iagkwy0d67qb6xhgl5rgqnm7zdyi8f0hwhwspvz12l3njp0v";
  };

  # checkInputs = [ pytest ] ++ lib.optionals (!isPy3k) [ mock ];

  # propagatedBuildInputs = [ certifi ];

  doCheck = false;

  meta = {
    homepage = "https://github.com/kplindegaard/smbus2";
    description = "A drop-in replacement for smbus-cffi/smbus-python in pure Python";
    license = lib.licenses.mit;
  };
}
