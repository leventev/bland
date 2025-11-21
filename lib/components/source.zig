const bland = @import("../bland.zig");

const Float = bland.Float;

pub const OutputFunctionType = enum {
    dc,
    phasor,
    sin,
};

/// Output function of a source
pub const OutputFunction = union(OutputFunctionType) {
    /// Constant DC value
    dc: Float,

    // TODO: maybe replace with complex
    /// Phasor, for sinusoidal steady state
    phasor: struct {
        amplitude: Float,
        phase: Float,
    },

    /// Sinusoidal output: `amplitude`*sin(2*pi*`frequency` * time + `phase`)
    sin: struct {
        amplitude: Float,
        frequency: Float,
        phase: Float,
    },
};
