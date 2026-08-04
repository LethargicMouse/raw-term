const std = @import("std");

const RawTerm = @import("raw_term").RawTerm;

pub fn main(init: std.process.Init) !void {
    var term = try RawTerm.init(init.io);
    defer term.deinit();
    try term.hideCursor();
    try term.clearScreen();
    try term.flush();
    var minput: ?u8 = null;
    while (true) {
        minput = try term.readByte();
        if (minput) |input| {
            if (input == 'q') {
                break;
            }
            try term.clearScreen();
            const size = term.getSize();
            try term.setColor(.green, true);
            try term.moveTo(size.width / 2 - 7, size.height / 2);
            try term.print("size:   {f}", .{size});
            try term.resetColor();
            try term.moveTo(size.width / 2 - 7, size.height / 2 + 1);
            try term.print("input:  {any}", .{input});
            try term.flush();
        }
    }
}
