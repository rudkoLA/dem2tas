const std = @import("std");

pub fn BitReader() type {
    return struct {
        const Self = @This();

        reader: std.Io.Reader,
        buffer: u128 = 0,
        bits_left: u64 = 0,

        pub fn init(reader: std.Io.Reader) Self {
            return .{ .reader = reader };
        }

        pub fn readBits(self: *Self, comptime T: type, count: u64) !T {
            while (self.bits_left < count) {
                const byte = try self.reader.takeByte();
                self.buffer |= @as(u128, byte) << @intCast(self.bits_left);
                self.bits_left += 8;
            }

            const mask = if (count >= 128) ~@as(u128, 0) else (@as(u128, 1) << @intCast(count)) - 1;
            const result = self.buffer & mask;

            self.buffer >>= @intCast(count);
            self.bits_left -= count;

            return switch (@typeInfo(T)) {
                .int => |int_info| switch (int_info.signedness) {
                    .unsigned => @truncate(result),
                    .signed => @bitCast(@as(@Int(.unsigned, int_info.bits), @truncate(result))),
                },
                .float => |float_info| switch (float_info.bits) {
                    32 => @bitCast(@as(u32, @truncate(result))),
                    64 => @bitCast(@as(u64, @truncate(result))),
                    else => @compileError("Unsupported float bit width"),
                },
                else => @compileError("Unsupported type for readBits"),
            };
        }
    };
}
