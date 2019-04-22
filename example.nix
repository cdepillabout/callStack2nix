
let
  src = builtins.fetchTarball {
    # nixpkgs-19.03 as of 2019/03/23.
    url = "https://github.com/NixOS/nixpkgs/archive/f5e7da91cfa70b8f20324f52b2d9efa22e801a53.tar.gz";
    sha256 = "1wnbklxjqcsryn6cwm82f2rcmgrhdw1853ym2ck12jkn2ggpwmpx";
  };

  pkgs = import src {};

  # Bring the callStack2nixPkgSet function into scope.
  inherit (import ./default.nix { inherit pkgs; }) callStack2nixPkgSet;

  # Create a Haskell package set using stack2nix based on the stack.yaml file
  # from the purty repository.
  purtyPkgSet = callStack2nixPkgSet {
    # The Haskell package set that is created gets some packages from this
    # global pkgs.
    inherit pkgs;

    name = "purty";

    # This is the Haskell source repository that contains the stack.yaml file
    # used to define the Haskell package set.
    src = pkgs.fetchFromGitLab {
      owner = "joneshf";
      repo = "purty";
      rev = "b84a5095"; # v3.0.7
      sha256 = "0q03hx4qj6hnnmkhqz3gb64cacg5d0s56fr1vk4r8ihgc1pi9lcr";
    };

    # This is the hash of the stack2nix.nix file that is output.  This can't be
    # known until you run this function for a given input source repo.  In
    # general, you should first run callStack2nixPkgSet with an incorrect
    # sha256 hash.  nix-build will complain and tell you the hash is incorrect.
    # You can then copy in the correct hash.  Once you have the correct hash,
    # it should always be the same.
    sha256 = "02nhsk18s5cqf1nz8cpfiajdsrqv9i2f6431dxps2g13ky15ahzh";

    # A timestamp for use when accessing access the Hackage package database.
    # This must be a timestamp corresponding to a date after the release of the
    # stackage resolver (in this case LTS-11.7).
    #
    # See the documentation on callStack2nix for why this is required.
    hackageSnapshotTimestamp = "2019-04-16T00:00:00Z";

    # An input Haskell package set containing a compiler compatible with the
    # resolver used by the source repository.
    #
    # In this example, purty uses LTS-11.7, which uses GHC-8.2.2, so this needs
    # to be pkgs.haskell.package.ghc822.
    haskellPackagesCompiler = pkgs.haskell.packages.ghc822;
  };

in

purtyPkgSet.purty

# callStack2nixStuff.stack2nix
