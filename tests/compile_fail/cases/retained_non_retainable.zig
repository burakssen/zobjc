const objc = @import("objc");

pub fn main() void {
    _ = objc.memory.Retained(u32);
}
