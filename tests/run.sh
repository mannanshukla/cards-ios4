#!/bin/zsh
# Every Mac-side check: the Markdown parser, the C scheduler against the Python one, the app's store against
# tools/cards, and (when the fsrs package is importable) the Python scheduler against the reference py-fsrs.
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
clang -O2 -o "$T/fsrs_check" tests/fsrs_check.c src/CDFSRS.c
clang -fno-objc-arc -Wno-deprecated-declarations -framework Foundation -o "$T/store_check" tests/store_check.m src/CDFSRS.c
python3 tests/parse_test.py
python3 tests/crosscheck.py "$T/fsrs_check" 2000
python3 tests/store_check.py "$T/store_check"
for py in ${FSRS_PYTHON:-python3}; do if $py -c 'import fsrs' 2>/dev/null; then $py tests/vs_pyfsrs.py; else echo "vs_pyfsrs: skipped (pip install 'fsrs>=5,<6', or point FSRS_PYTHON at a python that has it)"; fi; done
