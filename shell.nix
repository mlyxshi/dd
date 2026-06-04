# nix develop -f ./shell.nix
# For kernel/busybox:  make menuconfig
{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    gcc
    gnumake
    pkg-config

    flex
    bison

    bc
  ];

  buildInputs = with pkgs; [
    ncurses
  ];
}
