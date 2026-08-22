const std = @import("std");

const RawTerm = @import("raw_term").RawTerm;
const runApp = @import("raw_term").runApp;

const App = struct {
    term: RawTerm,
    dirty: bool = true,
};

const Echoer = struct {
    app: *App,
    input: u8 = 0,
    running: bool = true,

    pub fn draw(echoer: Echoer) !void {
        const size = try echoer.app.term.getSize();
        const x = size.width / 2 - 6;
        const y = size.height / 2;
        try echoer.app.term.goto(x, y - 1);
        try echoer.app.term.setColor(.green, true);
        try echoer.app.term.print("size: {f}", .{size});
        try echoer.app.term.goto(x, y);
        try echoer.app.term.setColor(.default, true);
        try echoer.app.term.print("input: {d}", .{echoer.input});
    }

    pub fn handleInput(echoer: *Echoer, input: u8) !void {
        switch (input) {
            'q', 27 => echoer.running = false,
            else => echoer.input = input,
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const term = try RawTerm.init(init.io);
    var app = App{ .term = term };
    defer app.term.deinit();
    try app.term.hideCursor();
    var echoer = Echoer{ .app = &app };
    try runApp(&echoer);
}
