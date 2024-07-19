const std = @import("std");
const cpu = @import("cpu");

pub fn main() !void {
    const value = cpu.hello();
    _ = &value;
}
