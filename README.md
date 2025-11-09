# bland
A circuit analyser written in [Zig](https://ziglang.org/).

Prerequisites:
- zig 0.15.2

Use:

```
git clone https://github.com/leventev/bland
cd bland
zig build run
```

To run the unit tests:
```
zig build test
```

Features:
- [X]  Ideal voltage source, ideal current source, ideal resistor
- [X]  Current controlled voltage and current source
- [ ]  Voltage controlled voltage and current source
- [X]  Capacitor and inductor
- [X]  DC analysis
- [X]  Sinusoidal steady state frequency sweep
- [ ]  Bode plots
- [ ]  Time domain analysis
- [ ]  Saving and loading circuits
- [ ]  Parse expressions for inputs and plotting
- [ ]  Console
- [ ]  Non-linear circuits