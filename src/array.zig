const std = @import("std");

pub fn Array(comptime T: type) type {
    return struct {
        data: []T,
        count: usize,
        capacity: usize,
        allocator: std.mem.Allocator,

        pub fn init(a: std.mem.Allocator) !@This() {
            const initial_capacity = 8;
            return .{
                .data = try a.alloc(T, initial_capacity),
                .count = 0,
                .capacity = initial_capacity,
                .allocator = a,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.data);
            self.data = undefined;
            self.count = 0;
            self.capacity = 0;
        }

        pub fn append(self: *@This(), item: T) !void {
            if (self.capacity < self.count + 1) {
                self.capacity *= 2;
                self.data = try self.allocator.realloc(self.data, self.capacity);
            }

            self.data[self.count] = item;
            self.count += 1;
        }
    };
}
