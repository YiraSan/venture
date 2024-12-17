# venture

You will need clang/cmake to build. I'm using the latest version of both.

In order to build the static/shared libraries:
> `zig build static_lib` / `zig build shared_lib`

You can add `-Doptimize=ReleaseFast` for production ready build. (not recommended to use it as a debug/development library will probably makes things harder to debug)
