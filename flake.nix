{
  description = "A C/C++ compilation cache using recursive Nix";

  edition = 201909;

  outputs = { self, nixpkgs }: {

    overlay = final: prev: {

      nix-ccache = final.runCommand "nix-ccache"
        { next = final.stdenv.cc.cc;
          binutils = final.binutils;
          nix = final.nix;
          requiredSystemFeatures = [ "recursive-nix" ];
        }
        ''
          mkdir -p $out/bin

          for i in gcc g++; do
            substitute ${./cc-wrapper.sh} $out/bin/$i \
              --subst-var-by next $next \
              --subst-var-by program $i \
              --subst-var shell \
              --subst-var nix \
              --subst-var system \
              --subst-var out \
              --subst-var binutils
            chmod +x $out/bin/$i
          done

          ln -s $next/bin/cpp $out/bin/cpp
        '';

      nix-ccacheStdenv = final.overrideCC final.stdenv
        (final.wrapCC final.nix-ccache);

    };

    testPkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays =
        [ self.overlay
          (final: prev: {

            geeqie = prev.geeqie.overrideDerivation (attrs: {
              stdenv = final.nix-ccacheStdenv;
              requiredSystemFeatures = [ "recursive-nix" ];
            });

            nixUnstable = prev.nixUnstable.overrideDerivation (attrs: {
              stdenv = final.nix-ccacheStdenv;
              requiredSystemFeatures = [ "recursive-nix" ];
              doInstallCheck = false;
            });

            hello = prev.hello.overrideDerivation (attrs: {
              stdenv = final.nix-ccacheStdenv;
              requiredSystemFeatures = [ "recursive-nix" ];
            });

            patchelf-new = prev.patchelf.overrideDerivation (attrs: {
              stdenv = final.nix-ccacheStdenv;
              requiredSystemFeatures = [ "recursive-nix" ];
            });

            trivial = final.nix-ccacheStdenv.mkDerivation {
              name = "trivial";
              requiredSystemFeatures = [ "recursive-nix" ];
              buildCommand = ''
                mkdir -p $out/bin
                g++ -o hello.o -c ${./hello.cc} -DWHO='"World"' -std=c++11
                g++ -o $out/bin/hello hello.o
                $out/bin/hello
              '';
            };

          })
        ];
    };

    checks.x86_64-linux.geeqie = self.testPkgs.geeqie;
    checks.x86_64-linux.hello = self.testPkgs.hello;
    checks.x86_64-linux.patchelf = self.testPkgs.patchelf-new;
    checks.x86_64-linux.trivial = self.testPkgs.trivial;
    checks.x86_64-linux.nixUnstable = self.testPkgs.nixUnstable;

    defaultPackage.x86_64-linux = self.testPkgs.nix-ccache;

  };
}
