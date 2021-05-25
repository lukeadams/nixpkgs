{ lib, stdenv, CoreServices, cmake, fetchFromGitHub, pkgconfig, sparsehash, zlib }:

stdenv.mkDerivation rec {
  pname = "afsctool";
  version = "1.7.0";

  src = fetchFromGitHub {
    owner  = "RJVB";
    repo   = pname;
    rev    = "v${version}";
    sha256 = "0fhgm8ayzkw5pgh2ybd9f4k9imwyk1x303y1w1jaiqs71bp1m9xf";
  };

  buildInputs = [ CoreServices sparsehash zlib ];
  nativeBuildInputs = [ cmake pkgconfig ];

  meta = with lib; {
    homepage    = "https://github.com/RJVB/afsctool";
    description = "HFS+/APFS transparent compression";
    license     = licenses.gpl3Only;
    maintainers = with maintainers; [ lukeadams ];
    platforms   = platforms.darwin;
  };
}
