const objc = @import("objc");

const ZigStruct = struct {
    a: u32,
    b: u32,
};

pub fn main() void {
    const obj: objc.Object = undefined;
    const s = ZigStruct{ .a = 1, .b = 2 };
    _ = objc.send(void, obj, "foo:", .{s});
}
