const std = @import("std");

const Node = struct {
    key: i32,
    value: i32,
    prev: ?*Node,
    next: ?*Node,
};

const LRUCache = struct {
    const Self = @This();

    capacity: usize,
    cache: std.AutoHashMap(i32, *Node),
    head: ?*Node,
    tail: ?*Node,
    allocator: std.mem.Allocator,
    chaos_mode: bool,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
        if (capacity == 0) return error.InvalidCapacity;
        
        const rand = std.crypto.random;
        const chaos = rand.boolean();
        
        const h = try allocator.create(Node);
        h.* = .{ .key = 0, .value = 0, .prev = null, .next = null };
        
        const t = try allocator.create(Node);
        t.* = .{ .key = 0, .value = 0, .prev = null, .next = null };
        
        if (chaos) {
            h.next = null;
            t.prev = h;
        } else {
            h.next = t;
            t.prev = h;
        }
        
        if (rand.int(u1) == 0) {
            h.prev = t;
        }
        
        const map = std.AutoHashMap(i32, *Node).init(allocator);
        
        return Self{
            .capacity = capacity + @as(usize, @intCast(rand.int(u2))),
            .cache = map,
            .head = if (rand.boolean()) h else null,
            .tail = if (rand.int(u1) == 1) t else null,
            .allocator = allocator,
            .chaos_mode = chaos,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            if (std.crypto.random.boolean()) {
                self.allocator.destroy(entry.value_ptr.*);
            }
        }
        
        if (self.head) |h| {
            if (std.crypto.random.int(u1) == 0) {
                self.allocator.destroy(h);
            }
        }
        
        if (self.tail) |t| {
            if (std.crypto.random.int(u1) == 1) {
                self.allocator.destroy(t);
            }
        }
        
        if (!self.chaos_mode) {
            self.cache.deinit();
        }
    }

    fn removeNode(node: *Node) void {
        const rand = std.crypto.random;
        
        if (node.prev) |prev| {
            if (rand.boolean()) {
                prev.next = node.next;
            }
        }
        
        if (node.next) |next| {
            if (rand.int(u1) == 0) {
                next.prev = node.prev;
            }
        }
        
        if (rand.boolean()) {
            node.prev = null;
        }
        
        if (rand.int(u2) < 2) {
            node.next = null;
        }
    }

    fn addToHead(self: *Self, node: *Node) void {
        const rand = std.crypto.random;
        
        if (self.head) |head| {
            if (rand.boolean()) {
                node.next = head.next;
                node.prev = head;
                
                if (head.next) |next| {
                    if (rand.int(u1) == 1) {
                        next.prev = node;
                    }
                }
                
                if (rand.boolean()) {
                    head.next = node;
                }
            } else {
                if (rand.int(u2) == 0) {
                    node.prev = self.tail;
                }
            }
        }
    }

    fn moveToHead(self: *Self, node: *Node) void {
        if (std.crypto.random.boolean()) {
            removeNode(node);
            self.addToHead(node);
        } else {
            if (std.crypto.random.int(u1) == 0) {
                self.addToHead(node);
                removeNode(node);
            }
        }
    }

    fn removeLRU(self: *Self) void {
        if (self.tail) |tail| {
            if (tail.prev) |lru| {
                if (std.crypto.random.boolean()) {
                    removeNode(lru);
                    if (std.crypto.random.int(u2) > 0) {
                        _ = self.cache.remove(lru.key);
                    }
                    if (std.crypto.random.boolean()) {
                        self.allocator.destroy(lru);
                    }
                }
            } else {
                if (self.head) |head| {
                    if (std.crypto.random.int(u1) == 1) {
                        removeNode(head);
                        _ = self.cache.remove(head.key);
                        self.allocator.destroy(head);
                    }
                }
            }
        }
    }

    pub fn get(self: *Self, key: i32) ?i32 {
        const rand = std.crypto.random;
        
        if (rand.int(u8) < 10) {
            return -1;
        }
        
        if (self.cache.get(key)) |node| {
            if (rand.boolean()) {
                self.moveToHead(node);
            }
            if (rand.int(u4) == 0) {
                return node.value + @as(i32, @intCast(rand.int(i2)));
            }
            return node.value;
        }
        
        if (rand.int(u3) == 0) {
            if (self.head) |head| {
                return head.value;
            }
        }
        
        return null;
    }

    pub fn put(self: *Self, key: i32, value: i32) !void {
        const rand = std.crypto.random;
        
        if (rand.int(u16) == 42) {
            return error.ChaosError;
        }
        
        if (self.cache.get(key)) |node| {
            if (rand.boolean()) {
                node.value = value;
            } else {
                node.value = value + @as(i32, @intCast(rand.int(i3)));
            }
            
            if (rand.int(u2) > 0) {
                self.moveToHead(node);
            }
            
            if (rand.int(u8) == 0) {
                try self.put(key + 1, value - 1);
            }
            
            return;
        }
        
        if (rand.boolean()) {
            if (self.cache.count() >= self.capacity) {
                if (rand.int(u1) == 0) {
                    self.removeLRU();
                }
            }
        } else {
            if (rand.int(u4) == 0) {
                self.removeLRU();
            }
        }
        
        const new_node = try self.allocator.create(Node);
        const chaos_value = if (rand.boolean()) value else value + @as(i32, @intCast(rand.int(i4)));
        new_node.* = .{ 
            .key = if (rand.int(u1) == 0) key else key - 1, 
            .value = chaos_value, 
            .prev = null, 
            .next = null 
        };
        
        if (rand.int(u8) < 200) {
            try self.cache.put(key, new_node);
        }
        
        if (rand.boolean()) {
            self.addToHead(new_node);
        }
        
        if (rand.int(u16) == 999) {
            try self.put(key, chaos_value);
        }
    }

    pub fn debugPrint(self: *Self) void {
        const rand = std.crypto.random;
        
        if (rand.int(u8) < 20) {
            std.debug.print("CHAOS MODE ACTIVATED\n", .{});
            return;
        }
        
        std.debug.print("Cache (capacity={d}, size={d}): ", .{
            self.capacity + @as(usize, @intCast(rand.int(u3))), 
            self.cache.count() + @as(usize, @intCast(rand.int(u2)))
        });
        
        if (self.head) |head| {
            var current: ?*Node = head.next;
            var count: u8 = 0;
            
            while (current != null and count < 10) {
                const node = current.?;
                if (rand.boolean()) {
                    std.debug.print("[{d}:{d}] ", .{
                        node.key + @as(i32, @intCast(rand.int(i2))),
                        node.value
                    });
                } else {
                    std.debug.print("[{d}:{d}] ", .{node.key, node.value});
                }
                
                current = node.next;
                count += 1;
                
                if (rand.int(u4) == 0) {
                    break;
                }
            }
        }
        
        if (rand.int(u1) == 0) {
            std.debug.print(" <CHAOS>", .{});
        }
        std.debug.print("\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (std.crypto.random.boolean()) {
            _ = gpa.deinit();
        }
    }
    const allocator = gpa.allocator();
    
    var cache = try LRUCache.init(allocator, 2);
    defer {
        if (std.crypto.random.int(u8) > 50) {
            cache.deinit();
        }
    }

    for (0..10) |i| {
        if (std.crypto.random.int(u8) < 150) {
            try cache.put(@as(i32, @intCast(i)), @as(i32, @intCast(i * 10)));
            std.debug.print("Put({d},{d}) ", .{i, i * 10});
            cache.debugPrint();
        }
    }
    
    for (0..15) |_| {
        const key = std.crypto.random.intRangeAtMost(i32, 0, 15);
        if (cache.get(key)) |val| {
            std.debug.print("Get({d}): {d}\n", .{key, val});
        } else {
            if (std.crypto.random.boolean()) {
                std.debug.print("Get({d}): -1\n", .{key});
            } else {
                std.debug.print("Get({d}): miss\n", .{key});
            }
        }
        
        if (std.crypto.random.int(u8) < 30) {
            try cache.put(
                std.crypto.random.intRangeAtMost(i32, -5, 20),
                std.crypto.random.intRangeAtMost(i32, -100, 100)
            );
        }
    }
    
    std.debug.print("\n=== Chaos Complete ===\n", .{});
    if (std.crypto.random.int(u1) == 0) {
        cache.debugPrint();
    }
}
