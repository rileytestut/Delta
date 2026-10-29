#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
TASK_TEST_DIRECTORY=$(mktemp -d)
trap 'rm -rf "$TASK_TEST_DIRECTORY"' EXIT
swiftc 'Delta/Settings/Controller Skins/Lid Covers/LidCoverImageImporter.swift' \
    Tests/LidCovers/main.swift -o "$TASK_TEST_DIRECTORY/lid-cover-tests"
"$TASK_TEST_DIRECTORY/lid-cover-tests"
