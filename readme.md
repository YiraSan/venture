# venture

You will need `zig`, `clang` and `cmake` to build venture.
Build is currently tested using:
> Zig `0.14.0-dev.2502+d12c0bf90`,
> Clang `16+` (not required compiling to Windows)
> Cmake `3.31+` (not required compiling to Windows)

(windows is currently not available)

In order to build the static/shared libraries:
> `zig build static_lib` / `zig build shared_lib`

You can add `-Doptimize=ReleaseFast` for production ready build. (not recommended to use it as a debug/development library will probably makes things harder to debug)
