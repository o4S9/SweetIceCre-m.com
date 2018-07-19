#!/bin/bash

readonly SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$SCRIPTS_DIR/.."

function is_expected_failure() {
  # A test target was specified with the 'build' command.
  grep --quiet "is not configured for Running" "$1"
}

clone_flutter_codelabs="git clone https://github.com/material-components/material-components-flutter-codelabs.git"
checkout_shrine_complete="git checkout 104-complete"
log_file="build_log_for_104_complete.txt"
build_command="flutter build bundle"

# Attempt to build 104-complete Shrine app from the Flutter codelabs
echo "$clone_flutter_codelabs"
$clone_flutter_codelabs

cd material-components-flutter-codelabs/mdc_100_series/

echo "$checkout_shrine_complete"
$checkout_shrine_complete

all_builds_ok=1
echo "$build_command"
$build_command 2>&1 | tee "$log_file"

if [ ${PIPESTATUS[0]} -eq 0 ] || is_expected_failure "$log_file"; then
    rm "$log_file"
else
    all_builds_ok=0
    echo
    echo "Log left in $log_file."
    echo
fi

# If any build failed, exit with a failure exit status so continuous integration
# tools can react appropriately.
if [ "$all_builds_ok" -eq 1 ]; then
    exit 0
else
    exit 1
fi
