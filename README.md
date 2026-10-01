[Original](https://github.com/mlugg/dem2tas) by [mlugg](https://mlugg.co.uk/), I just updated it to zig version 0.16.0 and changed the interface.

## Prerequisites

[Zig Compiler](https://ziglang.org/download/) version 0.16.0

## Building

```sh
zig build
```

The resulting binary will be placed at `./zig-out/bin/dem2tas`.

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

The following can be used to build all three most common targets for a release:
```sh
zig build artifacts
```
which uses ReleaseSmall optimization mode. The resulting binaries will be placed in `./artifacts/`.


## Usage
There are two ways to use this:
 
Place all your demos inside a `./demos/` folder and run dem2tas in its parent folder. Then the resulting tases will be at `./tases/`.

Run the binary using a terminal and write all desired files separated by spaces (additionally this may or may not support drag and drop'ing files onto the binary on windows/linux). The resulting files are in the same directories as their `.dem` counterparts, but with a `.p2tas` extension.

