{ stdenv, fetchurl, gtk2-x11, glib, pango, cairo, atk, gdk_pixbuf, libX11 }:

# Arena is free software in the sense of "free beer" but not as in "free
# speech". We can install it as we please, but we cannot re-distribute it in
# any way other than the original release tarball, so we cannot include its NAR
# into the Nixpkgs channel.

let

  inherit (stdenv.lib) makeLibraryPath;
  libDir = "lib64";

in
stdenv.mkDerivation rec {
  name = "arena-1.1";

  src = fetchurl {
    url = http://www.playwitharena.de/downloads/arenalinux_64bit_1.1.tar.gz;
    sha256 = "1sh71v5ymzwflq8ycx9j9kl0jhqllgs6z24h4h8j5z8pwdh528v6";
  };

  # stdenv.cc.cc.lib is in that list to pick up libstdc++.so. Is there a better way?
  buildInputs = [gtk2-x11 glib pango cairo atk gdk_pixbuf libX11 stdenv.cc.cc.lib];

  unpackPhase = ''
    # This is is a tar bomb, i.e. it extract a dozen files and directories to
    # the top-level, so we must create a sub-directory first.
    mkdir -p $out/lib/${name}
    tar -C $out/lib/${name} -xf ${src}

    # Remove executable bits from data files. This matters for the find command
    # we'll use below to find all bundled engines.
    chmod -x $out/lib/${name}/Engines/*/*.{txt,bin,bmp}
  '';

  buildPhase = ''
    # Arena has (at least) two executables plus a couple of bundled chess
    # engines that we need to patch.
    exes=( $(find $out -name '*x86_64_linux')
           $(find $out/lib/${name}/Engines -type f -perm /u+x)
         )
    for i in "''${exes[@]}"; do
      # Arminius is statically linked.
      if [[ $i =~ "Arminius_2017-01-01" ]]; then echo yo $i; continue; fi
      echo Fixing interpreter and rpath paths in $i ...
      patchelf                                                                                   \
        --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"                                \
        --set-rpath ${makeLibraryPath buildInputs}:$(cat $NIX_CC/nix-support/orig-cc)/${libDir}  \
        $i
    done
  '';

  installPhase = ''
    mkdir -p $out/bin
    ln -s $out/lib/${name}/Arena_x86_64_linux $out/bin/arena
  '';

  dontStrip = true;

  meta = {
    synopsis = "Chess GUI for analyzing with and playing against various engines";
    description = ''
      A free Graphical User Interface (GUI) for chess. Arena assists you in
      analyzing and playing games as well as in testing chess engines. It runs
      on Linux or Windows. Arena is compatible to Winboard protocol I, II and
      UCI protocol I, II. Furthermore, compatible to Chess960, DGT electronic
      chess board & DGT clocks and much more.
    '';
    license = stdenv.lib.licenses.unfree;
    platforms = ["x86_64-linux"];
    hydraPlatforms = stdenv.lib.platforms.none;
  };

}
