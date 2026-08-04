const std = @import("std");

const RawTerm = @import("raw_term").RawTerm;

pub fn main(init: std.process.Init) !void {
    var term = try RawTerm.init(init.io);
    defer term.deinit();
    try term.hideCursor();
    try term.clearScreen();
    try term.flush();
    while (true) {
        const input = try term.readByte();
        if (input == 'q') {
            break;
        }
        try term.clearScreen();
        const size = term.getSize();
        try term.setColor(.green, true);
        try term.print("size: {}x{}", .{ size.width, size.height });
        try term.resetColor();
        try term.print("\r\ninput: {}", .{input});
        try term.flush();
    }
}
