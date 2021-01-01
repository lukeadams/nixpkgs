{ stdenv, fetchFromGitHub

, cmake 

, fortranCompiler
, mpiImplementation
}:
stdenv.mkDerivation rec {
  pname = "opencoarrays";
  version = "2.9.2";

  src = fetchFromGitHub {
    owner = "sourceryinstitute";
    repo = "opencoarrays";
    rev = "${version}";
    sha256 = "1xf19nmx11z6qrqfgqsw8avngxvszwnyc5hgx4abv0kmpz5fdjvd";
  };

  nativeBuildInputs = [cmake];
  buildInputs = [fortranCompiler mpiImplementation];
#   doCheck = true;
      enableParallelBuilding = false;
  patches = [ ./notests.patch ];
  meta = with stdenv.lib; {
    description = "Fortran API to manipulate netcdf files";
    homepage = "https://www.unidata.ucar.edu/software/netcdf/";
    license = licenses.free;
    maintainers = [ maintainers.lukeadams ];
    platforms = platforms.unix;
  };
}
