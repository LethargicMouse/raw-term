const std = @import("std");

pub const Size = struct {
    width: u16,
    height: u16,
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
    termios.oflag.OPOST = false;
    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, termios);

    res.reader = std.Io.File.stdin().reader(io, &res.read_buf);
    res.writer = std.Io.File.stdout().writer(io, &res.write_buf);

    res.size = try querySize();

    return res;
}

pub fn readByte(term: *RawTerm) !u8 {
    return term.reader.interface.takeByte();
}

pub fn deinit(term: *RawTerm) void {
    std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, term.termios_before) catch {
        std.log.err("failed to disable terminal raw mode", .{});
    };
    term.* = undefined;
}

pub fn clearScreen(term: *RawTerm) !void {
    try term.writeAll("\x1b[2J\x1b[H");
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

pub fn getSize(term: RawTerm) Size {
    return term.size;
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
