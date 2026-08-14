const std = @import("std");

pub const RawTerm = @import("RawTerm.zig");

pub fn runApp(handler: anytype) !void {
    while (handler.running) {
        if (handler.app.dirty) {
            try handler.app.term.clearScreen();
            try handler.draw();
            try handler.app.term.flush();
            handler.app.dirty = false;
        }
        const minput = try handler.app.term.readByte();
        if (minput) |input| {
            handler.app.dirty = true;
            try handler.handleInput(input);
        }
        if (std.meta.hasMethod(@TypeOf(handler), "update")) {
            try handler.update();
        }
        if (try handler.app.term.sizeChanged()) {
            handler.app.dirty = true;
        }
    }
}
