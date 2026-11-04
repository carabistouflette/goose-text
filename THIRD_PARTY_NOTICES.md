# Third-party notices

The library source is licensed under Apache-2.0; see LICENSE. No third-party
source is vendored in this repository. The strict decoder uses the standard
UTF-8 lead/continuation ranges; the ASCII scan was extracted and adapted from
the author's goose-toml implementation, also Apache-2.0.

The Goose compiler and standard library are external build/runtime dependencies,
not bundled source. Setup fetches the exact commit recorded in GOOSE_REVISION
from https://github.com/aardappel/goose. Their own license applies to them;
consult that pinned upstream checkout's LICENSE. The scalar encoder delegates
to its standard-library push_utf8 after validating the scalar.

Python, CMake, Make, C/C++ compilers and optional Clang/libFuzzer/sanitizers are
external development tools governed by their own licenses. GitHub Actions are
pinned to immutable commits in CI; they are not part of the distributed library.
