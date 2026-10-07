#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Madeira Converter Exception: see LICENSE-EXCEPTION.md
# Assemble the clean-runner inputs documented in docs/BUILDING.md and
# build/dxmt-ios/README.md, then call the project's native build scripts.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$(brew --prefix bison)/bin:$PATH"
mkdir -p research wine/build-macos
if [ ! -d research/freetype ]; then
    git clone --depth 1 --branch VER-2-13-3 https://github.com/freetype/freetype.git research/freetype
fi
bash build/freetype-ios/build.sh
(cd build/gnutls-ios/src && shasum -a 256 -c SHA256SUMS)
bash build/gnutls-ios/build.sh
bash build/ffmpeg/build.sh
# Host configure supplies the Wine generated headers consumed by the iOS
# scripts. No host Wine executable is packaged.
(cd wine/build-macos && ../configure --enable-archs=none --without-x --without-mingw --without-vulkan --disable-tests)
make -C wine/build-macos -j3 include/all
bash build/ntdll-unix/build.sh
bash build/wineserver/build.sh
bash build/win32u-unix/build.sh
rustup target add aarch64-apple-ios
bash build/rppairing-ios/build.sh
