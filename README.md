Original by [mlugg](https://mlugg.co.uk/), I just updated it to zig version 0.16.0 and changed the interface to parse demos in a `./demos/` folder instead of a single file named `demo.dem`.

## Prerequisites

[Zig Compiler](https://ziglang.org/download/) version 0.16.0

## Building

```sh
zig build
```

The resulting binary will be placed at `zig-out/bin/dem2tas`.

You can instead do
```sh
zig build --release=small
```
to achieve a much smaller binary.

You can also do
```sh
zig build --release=fast
```
if speed matters.

## Usage

Place all your demos inside a `./demos/` folder and run dem2tas in its parent folder. Then the resulting tases will be at `./tases/`

