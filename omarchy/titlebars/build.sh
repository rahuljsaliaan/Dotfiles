#!/usr/bin/env bash
#
# Build Omarchy's titlebar plugin with the button-rest-opacity patch and install
# it where hypr/looknfeel.lua looks for it. Re-run after every Hyprland update:
# a plugin built against older Hyprland headers fails to load.
#
#   omarchy/titlebars/build.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HOME/.local/src/omarchy-hyprland-titlebars"
TAG="v0.2.2"   # the release the patch was written against
DEST="$HOME/.local/lib/omarchy-hyprland-titlebars/titlebars.so"

if [[ ! -d $SRC/.git ]]; then
  git clone https://github.com/omacom/omarchy-hyprland-titlebars.git "$SRC"
fi

cd "$SRC"
git fetch --tags --quiet
git checkout --quiet --force "$TAG"
git apply "$HERE/button-rest-opacity.patch"

mkdir -p build
g++ -shared -fPIC -O2 -std=c++23 -fno-gnu-unique \
  $(pkg-config --cflags hyprland libdrm libinput libudev pixman-1 wayland-server xkbcommon) \
  main.cpp barDeco.cpp BarPassElement.cpp appName.cpp -o build/titlebars.so \
  $(pkg-config --libs libdrm libinput libudev pixman-1 wayland-server xkbcommon) -lrt

install -Dm755 build/titlebars.so "$DEST"
pacman -Q hyprland >"$(dirname "$DEST")/built-for"   # read by looknfeel.lua and omarchy-custom-check
git checkout --quiet -- .
echo "Installed $DEST. Log out and back in to load it."
