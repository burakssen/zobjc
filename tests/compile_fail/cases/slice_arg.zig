const objc = @import("objc");

pub fn main() void {
    const obj: objc.Object = undefined;
    const slice: []const u8 = "hello";
    _ = objc.send(void, obj, "foo:", .{slice});
}
