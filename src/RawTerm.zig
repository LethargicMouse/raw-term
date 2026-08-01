const std = @import("std");

const RawTerm = @This();

termios_before: std.posix.termios,
read_buf: [256]u8,
reader: std.Io.File.Reader,
write_buf: [256]u8,
writer: std.Io.File.Writer,

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

    return res;
}

pub fn readByte(term: *RawTerm) !u8 {
    return term.reader.interface.takeByte();
}

pub fn deinit(term: RawTerm) void {
    std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, term.termios_before) catch {
        std.log.err("failed to disable terminal raw mode", .{});
    };
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
