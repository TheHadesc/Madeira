#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Madeira Converter Exception: see LICENSE-EXCEPTION.md
# LLVM/DXMT two-stage recipe from docs/BUILDING.md and build/dxmt-ios/README.md.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p toolchains
if [ ! -d toolchains/llvm-project ]; then
    git init toolchains/llvm-project
    git -C toolchains/llvm-project remote add origin https://github.com/llvm/llvm-project.git
    git -C toolchains/llvm-project fetch --depth 1 origin 8dfdcc7b7bf66834a761bd8de445840ef68e4d1a
    git -C toolchains/llvm-project checkout --detach FETCH_HEAD
    # The documented Apple linker fix, applied only to the downloaded LLVM.
    python3 - <<'PY'
from pathlib import Path
p = Path('toolchains/llvm-project/llvm/cmake/modules/AddLLVM.cmake')
p.write_text(p.read_text().replace('MATCHES "Darwin"', 'MATCHES "Darwin|iOS"'))
PY
fi
cmake -G Ninja -S toolchains/llvm-project/llvm -B toolchains/llvm-host-build \
    -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD= -DLLVM_INCLUDE_TESTS=OFF
cmake --build toolchains/llvm-host-build --target llvm-tblgen --parallel 3
cmake -G Ninja -S toolchains/llvm-project/llvm -B toolchains/llvm-ios-build \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_HOST_TRIPLE=arm64-apple-ios17.0 -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-ios17.0 \
    -DLLVM_TARGET_ARCH=host -DLLVM_TARGETS_TO_BUILD= -DLLVM_ENABLE_PROJECTS= \
    -DLLVM_BUILD_TOOLS=OFF -DLLVM_INCLUDE_TOOLS=OFF \
    -DLLVM_BUILD_UTILS=OFF -DLLVM_INCLUDE_UTILS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_TABLEGEN="$PWD/toolchains/llvm-host-build/bin/llvm-tblgen"
cmake --build toolchains/llvm-ios-build --parallel 3
bash build/dxmt-ios/build.sh
xcrun -sdk iphoneos libtool -static -o build/dxmt-ios/libdxmt_combined.a \
    build/dxmt-ios/obj/*.o toolchains/llvm-ios-build/lib/*.a
cp build/dxmt-ios/libdxmt_combined.a app/Madeira/
