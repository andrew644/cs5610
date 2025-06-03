{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    glfw
    pkg-config   # For resolving library paths
	cglm #math lib

	# asset import lib
	assimp

    # Required system libraries
    libGL
    xorg.libX11
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXi
    xorg.libXxf86vm
    xorg.libXcursor

    # Standard Linux libs (usually provided by glibc)
    glibc
  ];
}

