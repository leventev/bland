# Bland

**Bland** is circuit analyser written in [Zig](https://ziglang.org/). The project is composed of two parts:

- libbland: contains the actual circuit analysis logic, it has no dependencies and can be built and used as a standalone library
- bland: a frontend for libbland, uses [dvui](https://github.com/david-vanderson/dvui) for the UI

![Bland](/screenshot.png)

## Building

Prerequisites:

- [Zig](https://ziglang.org/) 0.15.X

First get the source:

```sh
$ git clone https://github.com/leventev/bland
$ cd bland
```

To build both the application and library:

```sh
$ zig build
```

To only build the library:

```sh
$ zig build -Dlib-only
```

### Running

Either build the application then execute

```sh
$ zig-out/bin/bland
```

or run the application directly with:

```sh
$ zig build run
```

### Tests

To run the unit tests for the library:

```sh
$ zig build lib-test
```

### Documentation

To generate the documentation for the library:

```sh
$ zig build lib-docs
```

The documentation can be viewed through a web server, for example:

```sh
$ python -m http.server -d zig-out/docs
```

## Usage

The program uses a fix-sized snap grid where elements (components, wires and pins) are placed. Wires always start and end on grid points, the same applies to the terminals of components and pins. Elements can be placed by selecting them in the toolbar or by using keybinds, which is highly recommended.

The default keybinds are:

| Function                | Keybind |
| ----------------------- | ------- |
| Place Register          | R       |
| Place Voltage Source    | V       |
| Place Current Source    | I       |
| Place Ground            | G       |
| Place Capacitor         | C       |
| Place Inductor          | L       |
| Place Diode             | D       |
| Place Pin               | P       |
| Rotate Element          | T       |
| Wire                    | W       |
| Open DVUI Debug Window  | O       |
| Delete Element          | Delete  |

## Features/TODO

- [X]  Ideal voltage source, ideal current source, ideal resistor
- [X]  Current controlled voltage and current source
- [ ]  Voltage controlled voltage and current source
- [X]  Capacitor and inductor
- [X]  DC analysis
- [X]  Sinusoidal steady state frequency sweep
- [X]  Bode plots
- [X]  Time domain analysis
- [ ]  Saving and loading circuits
- [ ]  Keybind editor
- [ ]  Theme selector
- [ ]  Parse expressions for inputs and plotting
- [X]  Console
- [ ]  Non-linear circuits