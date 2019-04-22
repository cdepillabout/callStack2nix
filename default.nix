{ pkgs ? <nixpkgs>
}:

with (import pkgs {});

let
  stack2nixSrc = builtins.fetchTarball {
    # my fork of stack2nix that has the required patches for running in nix-build
    url = "https://github.com/cdepillabout/stack2nix/archive/f5e7da91cfa70b8f20324f52b2d9efa22e801a53.tar.gz";
    sha256 = "1wnbklxjqcsryn6cwm82f2rcmgrhdw1853ym2ck12jkn2ggpwmpx";
  };

  stack2nix = import stack2nixSrc {};

  callStack2nix =
    { src
    , sha256
    # A time stamp specifying a Hackage snapshot version.  In order to
    # make the output of stack2nix reproducible, stack2nix must always
    # look at the same state of Hackage.  This is needed because the
    # packages on Hackage are not actually immutable.
    #
    # example: "2019-04-16T00:00:00Z"
    #
    # TODO: It should be possible to use stack2nix to figure out what
    # resolver a package is using (like lts-13.7), then automatically
    # take the release date of the resolver as the
    # hackageSnapshotTimestamp.
    , hackageSnapshotTimestamp
    # Which GHC to use for stack2nix.  This needs to the GHC version
    # used the resolver in the stack.yaml file.
    #
    # example: haskell.compiler.ghc864
    #
    # TODO: It should be possible to use stack2nix to automatically
    # figure out the GHC version used by the project without the user
    # needing to specify it.
    , ghc
    , name ? null
    , stack2nix ? stack2nix
    , cabal-install ? pkgs.cabal-install
    , lib ? pkgs.lib
    , stdenv ? pkgs.stdenv
    , cacert ? pkgs.cacert
    , git ? pkgs.git
    , iana-etc ? pkgs.iana-etc
    , libredirect ? pkgs.libredirect
    , doCheck ? true
    , doHaddock ? true
    , doBenchmark ? false
    }:
    assert builtins.isString hackageSnapshotTimestamp;
    assert (isNull name || builtins.isString name);
    stdenv.mkDerivation {
      name = "stack2nix${if isNull name then "" else "-for-" + name}.nix";

      nativeBuildInputs = [
        cabal-install
        cacert
        ghc
        git
        iana-etc
        libredirect
        stack2nix
      ];

      phases = ["installPhase"];

      LANG = "en_US.UTF-8";

      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = sha256;

      # Certificates need to be overridden for git and Haskell packages.
      GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
      NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
      SYSTEM_CERTIFICATE_PATH = "${cacert}/etc/ssl/certs";

      installPhase = ''
        # Make sure /etc/protocols is available because the libraries stack
        # depends on use it.
        export NIX_REDIRECTS=/etc/protocols=${iana-etc}/etc/protocols
        export LD_PRELOAD=${libredirect}/lib/libredirect.so

        # Set $HOME because stack needs it.
        export HOME="$TMP"

        # Make a temporary directory.  stack2nix uses stack internally.
        # stack creates a .stack-work/ directory inside the source code
        # directory it is trying to build.  Since the source code directory
        # we are using is in /nix/store and not writable, we copy the
        # source code to a temporary directory so that stack is able to
        # create a .stack-work/ directory inside of it.
        #
        # Below, the temporary source directory is replaced with the path
        # to the actual source directory from /nix/store. The name of the
        # temporary source directory needs to be long enough so it is
        # reliably unique.
        temp_src_dir=$(mktemp -d stack2nix-temp.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)
        cp --no-target-directory -r ${src} $temp_src_dir
        chmod -R ugo+rwx $temp_src_dir

        # Make sure .stack-work doesn't already exist in the source directory.
        rm -rf $temp_src_dir/.stack-work

        stack2nix \
          ${lib.optionalString doCheck "--test"} \
          ${lib.optionalString doHaddock "--haddock"} \
          ${lib.optionalString doBenchmark "--bench"} \
          -o $out \
          --hackage-snapshot ${hackageSnapshotTimestamp} \
          --verbose \
          --no-ensure-executables \
          $temp_src_dir

        # stack2nix creates the output nix file with a reference to the
        # temporary source directory from above.  We need to replace this
        # with the actual source directory from /nix/store.
        substituteInPlace $out --replace "$temp_src_dir" "${src}"
      '';
    };

  callStack2nixPkgSet =
    { pkgs ? pkgs
    , ...
    }@args:
    import (callStack2nix (builtins.removeAttrs args ["pkgs"])) { inherit pkgs; };

in { inherit callStack2nix callStack2nixPkgSet; }
