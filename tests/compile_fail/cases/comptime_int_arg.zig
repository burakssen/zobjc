const objc = @import("objc");

pub fn main() void {
    const obj: objc.Object = undefined;
    _ = objc.send(void, obj, "foo:", .{42});
}
