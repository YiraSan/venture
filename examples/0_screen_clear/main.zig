const venture = @import("venture");

pub fn main() !void {
    try venture.init();
    defer venture.deinit();
}
