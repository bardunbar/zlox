const std = @import("std");

const object_mod = @import("object.zig");
const Object = object_mod.Object;
const ObjectString = object_mod.ObjectString;

const value_mod = @import("value.zig");
const Value = value_mod.Value;

const Table = @This();

const initial_capacity: usize = 8;
const table_max_load: f32 = 0.75;

count: usize = 0,
entries: []Entry = undefined,
allocator: std.mem.Allocator,

pub const Entry = struct {
    key: ?*ObjectString,
    value: Value,
};

pub fn init(allocator: std.mem.Allocator) !@This() {
    const entries = try allocator.alloc(Entry, initial_capacity);
    for (entries) |*entry| {
        entry.* = .{ .key = null, .value = Value.fromNil() };
    }

    return .{
        .entries = entries,
        .allocator = allocator,
    };
}

pub fn deinit(self: *@This()) void {
    self.allocator.free(self.entries);
}

pub fn adjustCapacity(self: *@This(), capacity: usize) !void {
    const new_entries = try self.allocator.alloc(Entry, capacity);
    for (new_entries) |*entry| {
        entry.* = .{ .key = null, .value = Value.fromNil() };
    }

    self.count = 0;
    for (self.entries) |entry| {
        if (entry.key) |key| {
            var new_entry = findEntry(new_entries, key);
            new_entry.key = entry.key;
            new_entry.value = entry.value;
            self.count += 1;
        }
    }

    self.allocator.free(self.entries);
    self.entries = new_entries;
}

pub fn set(self: *@This(), key: *ObjectString, value: Value) !bool {
    if (@as(f32, @floatFromInt(self.count + 1)) > @as(f32, @floatFromInt(self.entries.len)) * table_max_load) {
        try self.adjustCapacity(self.entries.len * 2);
    }

    var entry = findEntry(self.entries, key);
    const is_new = entry.key == null;

    // Don't increment the count of we are replacing a tombstone
    if (is_new and entry.value.isNil()) {
        self.count += 1;
    }

    entry.key = key;
    entry.value = value;

    return is_new;
}

pub fn get(self: @This(), key: *ObjectString, value: *Value) bool {
    if (self.count == 0) {
        return false;
    }

    const entry = findEntry(self.entries, key);
    if (entry.key == null) {
        return false;
    }

    value.* = entry.value;
    return true;
}

pub fn delete(self: *@This(), key: *ObjectString) bool {
    if (self.count == 0) {
        return false;
    }

    const entry = findEntry(self.entries, key);
    if (entry.key == null) {
        return false;
    }

    entry.key = null;
    entry.value = Value.fromBool(true);

    return true;
}

pub fn insert(self: *@This(), other: Table) void {
    for (other.entries) |entry| {
        if (entry.key) {
            self.set(entry.key, entry.value);
        }
    }
}

fn findEntry(entries: []Entry, key: *ObjectString) *Entry {
    var index = key.hash % entries.len;
    var tombstone: ?*Entry = null;

    while (true) : (index = (index + 1) % entries.len) {
        const entry = &entries[index];
        if (entry.key == null) {
            if (entry.value.isNil()) {
                return if (tombstone) |t| t else entry;
            } else {
                if (tombstone == null) {
                    tombstone = entry;
                }
            }
        } else if (entry.key == key) {
            return entry;
        }
    }
}

pub fn findString(self: @This(), chars: []const u8, hash: u32) ?*ObjectString {
    if (self.count == 0) {
        return null;
    }

    var index = hash % self.entries.len;
    while (true) : (index = (index + 1) % self.entries.len) {
        const entry = &self.entries[index];
        if (entry.key) |key| {
            if (key.hash == hash and std.mem.eql(u8, key.chars, chars)) {
                return key;
            }
        } else {
            if (entry.value.isNil()) {
                return null;
            }
        }
    }
}
