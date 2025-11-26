# bland
A circuit analyser written in [Zig](https://ziglang.org/). The project is composed of two parts:
- libbland: contains the actual logic of the circuit analysis, it has no dependencies and can be built and used as a standalone library
- bland: a frontend for libbland, uses [dvui](https://github.com/david-vanderson/dvui) for the UI

## Building

Prerequisites:
- [Zig](https://ziglang.org/) 0.15.X

First get the source:

```
git clone https://github.com/leventev/bland
cd bland
```

To build both the application and library:
```
zig build
```

To only build the library:
```
zig build -Dlib-only
```

### Running

Either build the application then execute
```
zig-out/bin/bland
```

or run the application directly with:
```
zig build run
```


### Tests

To run the unit tests for the library:
```
zig build lib-test
```

### Documentation

To generate the documentation for the library:
```
zig build lib-docs
```

The documentation can be viewed through a web server, for example:
```
python -m http.server -d zig-out/docs
```

## Features

- [X]  Ideal voltage source, ideal current source, ideal resistor
- [X]  Current controlled voltage and current source
- [ ]  Voltage controlled voltage and current source
- [X]  Capacitor and inductor
- [X]  DC analysis
- [X]  Sinusoidal steady state frequency sweep
- [X]  Bode plots
- [X]  Time domain analysis
- [ ]  Saving and loading circuits
- [ ]  Parse expressions for inputs and plotting
- [X]  Console
- [ ]  Non-linear circuits