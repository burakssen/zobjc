const objc = @import("objc");

fn badCallback(self: objc.Object) void {
    _ = self;
}

pub fn main() void {
    const superclass: objc.Class = undefined;
    var builder = objc.ClassBuilder.init("MissingCmdClass", superclass) catch return;
    _ = builder.addMethod(objc.sel("test"), badCallback);
}
