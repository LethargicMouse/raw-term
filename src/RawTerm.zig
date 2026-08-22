const std = @import("std");

pub const Dir = enum {
    right,
    left,
    up,
    down,

    fn code(dir: Dir) u8 {
        switch (dir) {
            .right => return 'C',
            .left => return 'D',
            .up => return 'A',
            .down => return 'B',
        }
    }
};

pub const Size = struct {
    width: u16,
    height: u16,

    pub fn format(size: Size, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{}x{}", .{ size.width, size.height });
    }
};

pub const Color = enum {
    black,
    red,
    green,
    yellow,
    blue,
    purple,
    cyan,
    white,
    default,

    fn code(color: Color) u8 {
        switch (color) {
            .black => return 0,
            .red => return 1,
            .green => return 2,
            .yellow => return 3,
            .blue => return 4,
            .purple => return 5,
            .cyan => return 6,
            .white => return 7,
            .default => return 9,
        }
    }
};

const RawTerm = @This();

termios_before: std.posix.termios,
read_buf: [2048]u8,
reader: std.Io.File.Reader,
write_buf: [2048]u8,
writer: std.Io.File.Writer,
size: Size,

pub fn init(io: std.Io) !RawTerm {
    var res: RawTerm = undefined;

    var termios = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
    res.termios_before = termios;

    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;
    termios.lflag.ISIG = false;
    termios.oflag.OPOST = false;
    termios.cc[@intFromEnum(std.posix.V.TIME)] = 1;
    termios.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, termios);

    res.reader = std.Io.File.stdin().reader(io, &res.read_buf);
    res.writer = std.Io.File.stdout().writer(io, &res.write_buf);

    res.size = try querySize();

    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleWinch },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(.WINCH, &act, null);

    return res;
}

pub fn readByte(term: *RawTerm) !?u8 {
    return term.reader.interface.takeByte() catch |err| switch (err) {
        error.EndOfStream => return null,
        else => return err,
    };
}

fn restore(term: *RawTerm) !void {
    // \r's cuz terminal raw mode fails to get attr
    try term.clearScreen();
    try term.goto(1, 1);
    try term.writer.flush();
    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, term.termios_before);
}

pub fn deinit(term: *RawTerm) void {
    term.restore() catch {
        std.log.err("failed to restore terminal", .{});
    };
    term.* = undefined;
}

pub fn clearScreen(term: *RawTerm) !void {
    try term.writeAll("\x1b[2J");
}

pub fn flush(term: *RawTerm) !void {
    try term.writer.flush();
}

pub fn writeAll(term: *RawTerm, bytes: []const u8) !void {
    try term.writer.interface.writeAll(bytes);
}

pub fn print(term: *RawTerm, comptime fmt: []const u8, args: anytype) !void {
    try term.writer.interface.print(fmt, args);
}

pub fn hideCursor(term: *RawTerm) !void {
    try term.writeAll("\x1b[?25l");
}

pub fn showCursor(term: *RawTerm) !void {
    try term.writeAll("\x1b[?25h");
}

pub fn getSize(term: *RawTerm) !Size {
    if (size_changed.swap(false, .monotonic)) {
        term.size = try querySize();
    }
    return term.size;
}

pub fn sizeChanged(term: *RawTerm) !bool {
    if (size_changed.swap(false, .monotonic)) {
        term.size = try querySize();
        return true;
    }
    return false;
}

fn querySize() !Size {
    var winsize: std.posix.winsize = undefined;
    const res = std.posix.system.ioctl(std.posix.STDOUT_FILENO, std.posix.T.IOCGWINSZ, @intFromPtr(&winsize));
    if (std.posix.errno(res) != .SUCCESS) {
        return error.IoctlFailed;
    }
    return .{
        .width = winsize.col,
        .height = winsize.row,
    };
}

pub fn setColor(term: *RawTerm, color: Color, bold: bool) !void {
    const bold_num = @intFromBool(bold);
    try term.print("\x1b[{d};3{d}m", .{ bold_num, color.code() });
}

pub fn goto(term: *RawTerm, x: usize, y: usize) !void {
    try term.print("\x1b[{};{}H", .{ y, x });
}

pub fn writeByte(term: *RawTerm, byte: u8) !void {
    try term.writer.interface.writeByte(byte);
}

var size_changed = std.atomic.Value(bool).init(false);

fn handleWinch(_: std.posix.SIG) callconv(.c) void {
    size_changed.store(true, .monotonic);
}

pub fn go(term: *RawTerm, dir: Dir, n: usize) !void {
    try term.print("\x1b[{d}{c}", .{ n, dir.code() });
}
