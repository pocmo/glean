#!/usr/bin/env bash

# This should be invoked from inside xcode, not manually
if [ "$#" -ne 2 ]
then
    echo "Usage (note: only call inside xcode!):"
    echo "Args: $*"
    echo "path/to/build-scripts/xc-universal-binary.sh <FFI_TARGET> <GLEAN_ROOT_PATH>"
    exit 1
fi

# what to pass to cargo build -p, e.g. glean_ffi
FFI_TARGET=$1
# path to app services root
GLEAN_ROOT=$2

if [ -d "$HOME/.cargo/bin" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

if ! command -v cargo-lipo 2>/dev/null >/dev/null;
then
    echo "$(basename $0) failed."
    echo "Requires cargo-lipo to build universal library."
    echo "Install it with:"
    echo
    echo "   cargo install cargo-lipo"
    exit 1
fi

set -euvx

CLANG_PATH="$(xcrun -find clang)"
export CC_x86_64_apple_ios="$CLANG_PATH"
export CC_aarch64_apple_ios="$CLANG_PATH"

cargo lipo --xcode-integ --manifest-path "$GLEAN_ROOT/Cargo.toml" --package "$FFI_TARGET"
