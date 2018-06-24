{ stdenv, fetchFromGitHub
, cmake

# aasdk
, libusb
, boost
, protobuf
, openssl
, gtest

# openauto
, qt5
, rtaudio
, libpulseaudio
}:
let
aasdk = stdenv.mkDerivation rec {
  version = "2.1";
  name = "aasdk-${version}";
  src = fetchFromGitHub {
    owner = "f1xpl";
    repo = "aasdk";
    rev = "v${version}";
    sha256 = "08vwwzgxs91d9wpwmp8wf7fw3gyq0jh6j9f2djxs5myhqdz0p2lf";
  };

  installPhase = ''
    mkdir -p "$out"
    cp -r ../lib $out
    cp -r ../include $out
    cp -r aasdk_proto $out/include
    ls -al $out/include
  '';
  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake ];
  propagatedBuildInputs = [ libusb boost protobuf openssl gtest ];
};
in
stdenv.mkDerivation rec {
  version = "1.1.1";
  name = "openauto-${version}";
  src = fetchFromGitHub {
    owner = "f1xpl";
    repo = "openauto";
    rev = "v${version}";
    sha256 = "0d4mr18j2n93wj9d9b0kpn2cv31bq83hp904wfdg3y33rvai9zb1";
  };
  nativeBuildInputs = [ cmake ];
  propagatedBuildInputs = [ aasdk rtaudio libpulseaudio ] ++ (with qt5; [
    qtbase
    # qtmultimedia
    full
  ]);
  enableParallelBuilding = true;
  cmakeFlags = [
    "-DAASDK_LIBRARIES=${aasdk}/lib/libaasdk.so"
    "-DAASDK_PROTO_LIBRARIES=${aasdk}/lib/libaasdk_proto.so"
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp ../bin/* $out/bin
    cp -r ../include $out/
  '';
  shellHook = ''
    export QT_QPA_PLATFORM_PLUGIN_PATH=${qt5.qtbase.bin}/lib/qt-*/plugins/platforms
  '';
  meta = with stdenv.lib; {
    description = "Creates a cute cat chasing around your mouse cursor";
    longDescription = ''
    Oneko changes your mouse cursor into a mouse
    and creates a little cute cat, which starts
    chasing around your mouse cursor.
    When the cat is done catching the mouse, it starts sleeping.
    '';
    homepage = "http://www.daidouji.com/oneko/";
    license = licenses.publicDomain;
    maintainers = [ maintainers.xaverdh ];
    platforms = platforms.unix;
  };
}

