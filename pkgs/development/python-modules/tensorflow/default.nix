{ stdenv, buildBazelPackage, lib, fetchFromGitHub, fetchpatch, symlinkJoin
, buildPythonPackage, isPy3k, pythonOlder, pythonAtLeast
, which, swig, binutils, glibcLocales
, python, jemalloc, openmpi
, numpy, six, protobuf, tensorflow-tensorboard, backports_weakref, mock, enum34, absl-py
, cudaSupport ? false, nvidia_x11 ? null, cudatoolkit ? null, cudnn ? null
# XLA without CUDA is broken
, xlaSupport ? cudaSupport
# Default from ./configure script
, cudaCapabilities ? [ "3.5" "5.2" ]
, sse42Support ? false
, avx2Support ? false
, fmaSupport ? false

, Accelerate, IOKit, Security
}:

assert cudaSupport -> nvidia_x11 != null
                   && cudatoolkit != null
                   && cudnn != null;

# unsupported combination
assert ! (stdenv.isDarwin && cudaSupport);

let

  withTensorboard = pythonOlder "3.6";

  cudatoolkit_joined = symlinkJoin {
    name = "${cudatoolkit.name}-unsplit";
    paths = [ cudatoolkit.out cudatoolkit.lib ];
  };

  tfFeature = x: if x then "1" else "0";

  version = "1.5.0";

  pkg = buildBazelPackage rec {
    name = "tensorflow-build-${version}";

    src = fetchFromGitHub {
      owner = "tensorflow";
      repo = "tensorflow";
      rev = "v${version}";
      sha256 = "1c4djsaip901nasm7a6dsimr02bsv70a7b1g0kysb4n39qpdh22q";
    };

    patches = [
      # Fix build with Bazel >= 0.10
      (fetchpatch {
        url = "https://github.com/tensorflow/tensorflow/commit/6fcfab770c2672e2250e0f5686b9545d99eb7b2b.patch";
        sha256 = "0p61za1mx3a7gj1s5lsps16fcw18iwnvq2b46v1kyqfgq77a12vb";
      })
      (fetchpatch {
        url = "https://github.com/tensorflow/tensorflow/commit/3f57956725b553d196974c9ad31badeb3eabf8bb.patch";
        sha256 = "11dja5gqy0qw27sc9b6yw9r0lfk8dznb32vrqqfcnypk2qmv26va";
      })
    ];

    nativeBuildInputs = [ swig which ];

    buildInputs = [ python jemalloc openmpi glibcLocales numpy ]
      ++ lib.optionals cudaSupport [ cudatoolkit cudnn nvidia_x11 ]
      ++ lib.optionals stdenv.isDarwin [ Accelerate IOKit Security ];

    preConfigure = ''
      patchShebangs configure

      export PYTHON_BIN_PATH="${python.interpreter}"
      export PYTHON_LIB_PATH="$NIX_BUILD_TOP/site-packages"
      export TF_NEED_GCP=1
      export TF_NEED_HDFS=1
      export TF_ENABLE_XLA=${tfFeature xlaSupport}
      export CC_OPT_FLAGS=" "
      # https://github.com/tensorflow/tensorflow/issues/14454
      export TF_NEED_MPI=${tfFeature cudaSupport}
      export TF_NEED_CUDA=${tfFeature cudaSupport}
      ${lib.optionalString cudaSupport ''
        export CUDA_TOOLKIT_PATH=${cudatoolkit_joined}
        export TF_CUDA_VERSION=${cudatoolkit.majorVersion}
        export CUDNN_INSTALL_PATH=${cudnn}
        export TF_CUDNN_VERSION=${cudnn.majorVersion}
        export GCC_HOST_COMPILER_PATH=${cudatoolkit.cc}/bin/gcc
        export TF_CUDA_COMPUTE_CAPABILITIES=${lib.concatStringsSep "," cudaCapabilities}
      ''}

      mkdir -p "$PYTHON_LIB_PATH"
    '';

    NIX_LDFLAGS = lib.optionals cudaSupport [ "-lcublas" "-lcudnn" "-lcuda" "-lcudart" ];

    hardeningDisable = [ "all" ];

    # monolithic config generates a single tensorflow .so, which resolves linking issues on Darwin
    # See https://github.com/tensorflow/tensorflow/blob/37aa430d84ced579342a4044c89c236664be7f68/configure.py#L1228
    bazelFlags = [ "--config=opt" ]
                 ++ lib.optional stdenv.isDarwin "--config=monolithic"
                 ++ lib.optional sse42Support "--copt=-msse4.2"
                 ++ lib.optional avx2Support "--copt=-mavx2"
                 ++ lib.optional fmaSupport "--copt=-mfma"
                 ++ lib.optional cudaSupport "--config=cuda";

    bazelTarget = "//tensorflow/tools/pip_package:build_pip_package";

    fetchAttrs = {
      preInstall = ''
        rm -rf $bazelOut/external/{bazel_tools,\@bazel_tools.marker,local_*,\@local_*}
      '';

      sha256 = "1nc98aqrp14q7llypcwaa0kdn9xi7r0p1mnd3vmmn1m299py33ca";
    };

    buildAttrs = {
      # Here we use `declare` to solidify the environment (NIX_CFLAGS_COMPILE, etc) for when cc/cxx/ld is called
      # It's gross but it works!
      # We also set CC to `CC || CXX` since Bazel invokes CC for C++ files occasionally
      preBuild = ''
        patchShebangs .
        find -type f -name CROSSTOOL\* -exec sed -i \
          -e 's,/usr/bin/ar,${binutils.bintools}/bin/ar,g' \
          {} \;
      '' + lib.optionalString stdenv.isDarwin ''
        export CC="$(pwd)/cc.sh"
        export CXX="$(pwd)/cxx.sh"
        export LD="$(pwd)/ld.sh"

        echo "#!/usr/bin/env bash" >> test.sh
        chmod +x test.sh
        declare -px >> test.sh
        cp test.sh cc.sh
        cp test.sh cxx.sh
        cp test.sh ld.sh

        echo "(clang \"\$@\" ) || (clang++ \"\$@\" )" >> cc.sh
        echo "export isCpp=1; export cppInclude=1" >> cxx.sh
        echo "(clang++ \"\$@\") " >> cxx.sh
        echo "(ld \"\$@\") " >> ld.sh
      '';

      installPhase = ''
        sed -i 's,.*bdist_wheel.*,cp -rL . "$out"; exit 0,' bazel-bin/tensorflow/tools/pip_package/build_pip_package 
        bazel-bin/tensorflow/tools/pip_package/build_pip_package $PWD/dist
      '';
    };

    dontFixup = true;
  };

in buildPythonPackage rec {
  pname = "tensorflow";
  inherit version;
  name = "${pname}-${version}";

  src = pkg;

  installFlags = lib.optional (!withTensorboard) "--no-dependencies";

  postPatch = lib.optionalString (pythonAtLeast "3.4") ''
    sed -i '/enum34/d' setup.py
  '';

  propagatedBuildInputs = [ numpy six protobuf absl-py ]
                 ++ lib.optional (!isPy3k) mock
                 ++ lib.optionals (pythonOlder "3.4") [ backports_weakref enum34 ]
                 ++ lib.optional withTensorboard tensorflow-tensorboard;

  # Actual tests are slow and impure.
  checkPhase = ''
    ${python.interpreter} -c "import tensorflow"
  '';

  meta = with stdenv.lib; {
    description = "Computation using data flow graphs for scalable machine learning";
    homepage = http://tensorflow.org;
    license = licenses.asl20;
    maintainers = with maintainers; [ jyp abbradar ];
    platforms = with platforms; if cudaSupport then linux else linux ++ darwin;
    broken = !(xlaSupport -> cudaSupport) || (stdenv.isDarwin && cudaSupport);
  };
}
