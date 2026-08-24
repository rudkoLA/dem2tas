const std = @import("std");
const BitReader = @import("bit_reader.zig").BitReader();

const UserCmdInfo = struct {
    tick_count: i32,
    view_angles: [3]f32,
    forwardmove: f32,
    sidemove: f32,
    upmove: f32,
    buttons: u32,
};

fn parseUserCmdInfo(buf: []const u8, prev: UserCmdInfo) !UserCmdInfo {
    const stream: std.Io.Reader = .fixed(buf);

    var br: BitReader = .{ .reader = stream };

    var info = prev;

    if (1 == try br.readBits(u1, 1)) {
        _ = try br.readBits(i32, 32); // CommandNumber
    }

    if (1 == try br.readBits(u1, 1)) {
        info.tick_count = try br.readBits(i32, 32);
    }

    if (1 == try br.readBits(u1, 1)) {
        info.view_angles[0] = @bitCast(try br.readBits(i32, 32));
    }

    if (1 == try br.readBits(u1, 1)) {
        info.view_angles[1] = @bitCast(try br.readBits(i32, 32));
    }

    if (1 == try br.readBits(u1, 1)) {
        info.view_angles[2] = @bitCast(try br.readBits(i32, 32));
    }

    if (1 == try br.readBits(u1, 1)) {
        info.forwardmove = @bitCast(try br.readBits(i32, 32));
    } else {
        info.forwardmove = 0;
    }

    if (1 == try br.readBits(u1, 1)) {
        info.sidemove = @bitCast(try br.readBits(i32, 32));
    } else {
        info.sidemove = 0;
    }

    if (1 == try br.readBits(u1, 1)) {
        _ = try br.readBits(i32, 32); // UpMove
    }

    if (1 == try br.readBits(u1, 1)) {
        info.buttons = try br.readBits(u32, 32);
    } else {
        info.buttons = 0;
    }

    return info;
}

pub fn convert(file_name: []const u8, r: *std.Io.Reader, w: *std.Io.Writer) !void {
    if (!std.mem.eql(u8, try r.take(8), "HL2DEMO\x00")) return error.BadDemo;
    if (4 != try r.takeInt(i32, .little)) return error.BadDemo; // DemoProtocol
    try r.discardAll(4); // NetworkProtocol
    try r.discardAll(260); // ServerName
    try r.discardAll(260); // ClientName
    const map_name = try r.take(260);
    try r.discardAll(260); // GameDirectory
    try r.discardAll(4); // PlaybackTime
    try r.discardAll(4); // PlaybackTicks
    try r.discardAll(4); // PlaybackFrames
    try r.discardAll(4); // SignOnLength

    try w.print("version 1\n", .{});
    try w.print("start map {s}\n", .{std.mem.sliceTo(map_name, 0)});
    try w.print("0>\n", .{});

    var last_tick: i32 = 0;
    var last_cmd_info = UserCmdInfo{
        .tick_count = 0,
        .view_angles = .{ 0, 0, 0 },
        .forwardmove = 0,
        .sidemove = 0,
        .upmove = 0,
        .buttons = 0,
    };

    while (true) {
        const msg = r.takeInt(u8, .little) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };

        const tick = try r.takeInt(i32, .little);
        const slot = try r.takeInt(u8, .little);

        _ = slot;

        switch (msg) {
            1, 2 => { // SignOn/Packet
                try r.discardAll(76 * 2); // PacketInfo
                try r.discardAll(4); // InSequence
                try r.discardAll(4); // OutSequence
                const size = try r.takeInt(u32, .little);
                try r.discardAll(size); // Data
            },
            3 => {}, // SyncTick
            4 => { // ConsoleCmd
                const size = try r.takeInt(u32, .little);
                try r.discardAll(size); // Data
            },
            5 => { // UserCmd
                try r.discardAll(4); // Cmd
                const size = try r.takeInt(u32, .little);

                if (tick <= last_tick) {
                    // skip this one
                    try r.discardAll(size);
                } else {
                    // try and parse it

                    const buf = try r.take(size);
                    const info = try parseUserCmdInfo(buf, last_cmd_info);

                    if (last_tick == 0) {
                        last_cmd_info.view_angles = info.view_angles;
                    }

                    const buttons_off = "jduzbo";
                    const buttons_on = "JDUZBO";
                    const buttons_mask = [6]u32{ 1 << 1, 1 << 2, 1 << 5, 1 << 19, 1 << 0, 1 << 11 };

                    var buttons: [6]u8 = undefined;
                    for (&buttons, 0..6) |*b, i| {
                        b.* = if ((buttons_mask[i] & info.buttons) != 0)
                            buttons_on[i]
                        else
                            buttons_off[i];
                    }

                    try w.print("+{}>{d} {d}||{s}||setang {d} {d}\n", .{
                        tick - last_tick,
                        info.sidemove / 175.0,
                        info.forwardmove / 175.0,
                        &buttons,
                        info.view_angles[0],
                        info.view_angles[1],
                    });

                    last_tick = tick;
                    last_cmd_info = info;
                }
            },
            6 => { // DataTables
                const size = try r.takeInt(u32, .little);
                try r.discardAll(size); // Data
            },
            7 => { // Stop
                std.log.info("Demo \"{s}\" ended after parsing {} ticks.", .{ file_name, tick });
                break;
            },
            8 => { // CustomData
                try r.discardAll(4); // Type
                const size = try r.takeInt(u32, .little);
                try r.discardAll(size); // Data
            },
            9 => { // StringTables
                const size = try r.takeInt(u32, .little);
                try r.discardAll(size); // Data
            },
            else => return error.BadDemo,
        }
    }
}

pub fn main(init: std.process.Init) anyerror!void {
    const gpa = init.gpa;
    const io = init.io;

    const cwd = std.Io.Dir.cwd();

    var demos = try cwd.openDir(io, "demos", .{ .iterate = true });
    defer demos.close(io);

    cwd.createDir(io, "tases", .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    };

    var demo_iterator = demos.iterate();

    while (try demo_iterator.next(io)) |demo| {
        const demo_name = demo.name;
        if (!std.mem.endsWith(u8, demo_name, ".dem")) continue;

        const base_name = demo_name[0 .. demo_name.len - 4];

        const tas_path = try std.fmt.allocPrint(gpa, "tases/{s}.p2tas", .{base_name});
        defer gpa.free(tas_path);

        var file = try demos.openFile(io, demo_name, .{});
        defer file.close(io);

        var read_buf: [1 << 12]u8 = undefined;
        var file_reader = file.reader(io, &read_buf);
        const reader = &file_reader.interface;

        var output_file = try cwd.createFile(io, tas_path, .{});
        defer output_file.close(io);

        var write_buf: [1 << 12]u8 = undefined;
        var file_writer = output_file.writer(io, &write_buf);
        const writer = &file_writer.interface;

        try convert(base_name, reader, writer);

        try file_writer.flush();
    }
}
