#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Command Line Tools ships Swift Testing separately from the default plugin search path.
developer_dir="$(xcode-select -p)"
testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ "$developer_dir" == */CommandLineTools && -f "$testing_plugin" ]]; then
    swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$testing_plugin" "$@"
else
    swift test "$@"
fi
