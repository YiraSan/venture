# venture

You will need `zig 0.14.0-dev.2502+d12c0bf90` to build venture.

In order to build the static/shared libraries:
> `zig build static_lib` / `zig build shared_lib`

You can add `-Doptimize=ReleaseFast` for production ready build. (not recommended to use it as a debug/development library will probably makes things harder to debug)
