#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_bin=$(mktemp /tmp/lab2-allocator.XXXXXX)
trap 'rm -f "$test_bin"' EXIT HUP INT TERM
cc -std=gnu99 -O2 -g -Wall -Werror -Wno-unused -fno-builtin \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    -Ilibs -Ikern/mm -Ikern/debug tests/best_fit_host.c -o "$test_bin"
"$test_bin"
