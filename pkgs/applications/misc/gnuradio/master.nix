{ stdenv, fetchFromGitHub, writeText, makeWrapper
# Dependencies documented @ https://gnuradio.org/doc/doxygen/build_guide.html
# => core dependencies
, cmake, pkgconfig, git, boost, cppunit, fftw
# => python wrappers
# May be able to upgrade to swig3
, python, swig2#, numpy, scipy, matplotlib
# => grc - the gnu radio companion
#, cheetah, pygtk
# => gr-wavelet: collection of wavelet blocks
, gsl
# => gr-qtgui: the Qt-based GUI
#, qt5, qwt#, pyqt5
# => gr-wxgui: the Wx-based GUI
#, wxPython, lxml
# => gr-audio: audio subsystems (system/OS dependent)
, alsaLib   # linux   'audio-alsa'
, CoreAudio # darwin  'audio-osx'
# => uhd: the Ettus USRP Hardware Driver Interface
, uhd
# => gr-video-sdl: PAL and NTSC display
, SDL
# Other
, libusb1, orc
, log4cpp
# GR-3.8 supports python 3, but not all plugins are guaranteed to
# May be better to default to python2 for compatibility, but who knows
#python3 in python3 branch not even building so...
#, usePython3 ? true
}:
let
  pythonEnv = python.withPackages(ps: with ps; [
    Mako
    six
    numpy
    /*
    #cheetah # for grc #no python3
    lxml
    matplotlib
    numpy
    pyopengl
    #pyqt4 #for qt4
    pyqt5 # for qt5
    scipy
    #wxPython #no python3
    #pygtk     #no python3*/
  ]);
in
# currently focus on qt5 and python3 since qt4/python2 already works
stdenv.mkDerivation rec {
  name = "gnuradio-${version}";
  version = "3.8.0-git";

  src = fetchFromGitHub {
    owner = "gnuradio";
    repo = "gnuradio";
    rev = "7199e7811261af93203a6f207fd21927ea8304a3";
    sha256 = "12033xa3mrcgxvr80zdnbfgmks17vyz4zdhj6qcklr5h31x0w8f7";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake pkgconfig git makeWrapper cppunit orc
  ];

  buildInputs = [
    boost fftw swig2
    SDL libusb1 uhd gsl
    log4cpp
  ] ++ stdenv.lib.optionals stdenv.isLinux  [ alsaLib   ]
    ++ stdenv.lib.optionals stdenv.isDarwin [ CoreAudio ];

  propagatedBuildInputs = [
    python
    pythonEnv
  ];

  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace \
        gr-fec/include/gnuradio/fec/polar_decoder_common.h \
        --replace BOOST_CONSTEXPR_OR_CONST const
  '';

  # Enables composition with nix-shell
  grcSetupHook = writeText "grcSetupHook.sh" ''
    addGRCBlocksPath() {
      addToSearchPath GRC_BLOCKS_PATH $1/share/gnuradio/grc/blocks
    }
    envHooks+=(addGRCBlocksPath)
  '';

  setupHook = [ grcSetupHook ];

  # patch wxgui and pygtk check due to python importerror in a headless environment
  preConfigure = ''
    export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -Wno-unused-variable ${stdenv.lib.optionalString (!stdenv.isDarwin) "-std=c++11"}"
    #sed -i 's/.*wx\.version.*/set(WX_FOUND TRUE)/g' gr-wxgui/CMakeLists.txt
    #sed -i 's/.*pygtk_version.*/set(PYGTK_FOUND TRUE)/g' grc/CMakeLists.txt
    find . -name "CMakeLists.txt" -exec sed -i '1iadd_compile_options($<$<COMPILE_LANGUAGE:CXX>:-std=c++11>)' "{}" ";"
  '';

  # Framework path needed for qwt6_qt4 but not qwt5
  cmakeFlags = [
    # TODO: force enable and maybe add options for gui, etc
    "-DENABLE_GNURADIO_RUNTIME=ON"
    #"-DENABLE_GR_QTGUI=ON"
  ];
  # ++ stdenv.lib.optionals stdenv.isDarwin [ "-DCMAKE_FRAMEWORK_PATH=${qwt}/lib" ];

  # - Ensure we get an interactive backend for matplotlib. If not the gr_plot_*
  #   programs will not display anything. Yes, $MATPLOTLIBRC must point to the
  #   *dirname* where matplotlibrc is located, not the file itself.
  # - GNU Radio core is C++ but the user interface (GUI and API) is Python, so
  #   we must wrap the stuff in bin/.
  # Notes:
  # - May want to use makeWrapper instead of wrapProgram
  # - may want to change interpreter path on Python examples instead of wrapping
  # - see https://github.com/NixOS/nixpkgs/issues/22688 regarding use of --prefix / python.withPackages
  # - see https://github.com/NixOS/nixpkgs/issues/24693 regarding use of DYLD_FRAMEWORK_PATH on Darwin
  postInstall = ''
    printf "backend : Qt4Agg\n" > "$out/share/gnuradio/matplotlibrc"

    for file in $(find $out/bin $out/share/gnuradio/examples -type f -executable); do
        wrapProgram "$file" \
            --prefix PYTHONPATH : $PYTHONPATH:$(toPythonPath "$out") \
            --set MATPLOTLIBRC "$out/share/gnuradio" \
            ${stdenv.lib.optionalString stdenv.isDarwin "--set DYLD_FRAMEWORK_PATH /System/Library/Frameworks"}
    done
  '';

  meta = with stdenv.lib; {
    description = "Software Defined Radio (SDR) software";
    longDescription = ''
      GNU Radio is a free & open-source software development toolkit that
      provides signal processing blocks to implement software radios. It can be
      used with readily-available low-cost external RF hardware to create
      software-defined radios, or without hardware in a simulation-like
      environment. It is widely used in hobbyist, academic and commercial
      environments to support both wireless communications research and
      real-world radio systems.
    '';
    homepage = https://www.gnuradio.org;
    license = licenses.gpl3;
    branch = "python3"; # python3 has next branch merged into it
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = with maintainers; [ bjornfor fpletz ];
  };
}
