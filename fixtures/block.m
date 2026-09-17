#import <objc/NSObject.h>
#import <objc/runtime.h>
#include <Block.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct _NSZone NSZone;

@protocol NSCopying
- (id)copyWithZone:(NSZone *)zone;
@end

@interface DeallocTracker : NSObject
@property (nonatomic, assign) int identifier;
- (instancetype)initWithIdentifier:(int)ident;
@end

@interface CopyableTracker : NSObject <NSCopying>
@property (nonatomic, assign) int identifier;
@property (nonatomic, assign) int copyCount;
- (instancetype)initWithIdentifier:(int)ident;
@end

int get_dealloc_count(void);
void reset_dealloc_count(void);
int (^make_int_multiplier_block(int multiplier))(int);
id (^make_object_holder_block(id obj))(void);
int (^make_byref_counter_block(int initial))(int);
int invoke_int_block(int (^block)(int), int val);
id invoke_object_block(id (^block)(id), id val);
int invoke_two_arg_block(int (^block)(int, int), int x, int y);
int32_t get_clang_block_flags(void *block);
uintptr_t get_clang_block_descriptor_size(void *block);
const char *get_clang_block_signature(void *block);

static int g_dealloc_count = 0;

@implementation DeallocTracker
- (instancetype)initWithIdentifier:(int)ident {
    self = [super init];
    if (self) {
        _identifier = ident;
    }
    return self;
}
- (void)dealloc {
    g_dealloc_count++;
    [super dealloc];
}
@end

@implementation CopyableTracker
- (instancetype)initWithIdentifier:(int)ident {
    self = [super init];
    if (self) {
        _identifier = ident;
        _copyCount = 0;
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    CopyableTracker *c = [[[self class] allocWithZone:zone] initWithIdentifier:self.identifier];
    c.copyCount = self.copyCount + 1;
    return c;
}
@end

int get_dealloc_count(void) { return g_dealloc_count; }
void reset_dealloc_count(void) { g_dealloc_count = 0; }

int (^make_int_multiplier_block(int multiplier))(int) {
    return Block_copy(^(int x) { return x * multiplier; });
}

id (^make_object_holder_block(id obj))(void) {
    return Block_copy(^{ return obj; });
}

int (^make_byref_counter_block(int initial))(int) {
    __block int counter = initial;
    return Block_copy(^(int delta) {
        counter += delta;
        return counter;
    });
}

int invoke_int_block(int (^block)(int), int val) { return block(val); }
id invoke_object_block(id (^block)(id), id val) { return block(val); }
int invoke_two_arg_block(int (^block)(int, int), int x, int y) { return block(x, y); }

struct ClangBlockDescriptor1 {
    uintptr_t reserved;
    uintptr_t size;
};

struct ClangBlockDescriptor2 {
    void (*copy)(void *, const void *);
    void (*dispose)(const void *);
};

struct ClangBlockDescriptor3 {
    const char *signature;
    const char *layout;
};

struct ClangBlockLayout {
    void *isa;
    volatile int32_t flags;
    int32_t reserved;
    void (*invoke)(void *, ...);
    struct ClangBlockDescriptor1 *descriptor;
};

int32_t get_clang_block_flags(void *block) {
    struct ClangBlockLayout *layout = (struct ClangBlockLayout *)block;
    return layout->flags;
}

uintptr_t get_clang_block_descriptor_size(void *block) {
    struct ClangBlockLayout *layout = (struct ClangBlockLayout *)block;
    return layout->descriptor->size;
}

const char *get_clang_block_signature(void *block) {
    struct ClangBlockLayout *layout = (struct ClangBlockLayout *)block;
    int32_t flags = layout->flags;
    if (!(flags & (1 << 30))) {
        return NULL;
    }

    const char *desc = (const char *)layout->descriptor;
    if (flags & (1 << 25)) {
        struct ClangBlockDescriptor3 *d3 = (struct ClangBlockDescriptor3 *)(desc + sizeof(struct ClangBlockDescriptor1) + sizeof(struct ClangBlockDescriptor2));
        return d3->signature;
    }
    struct ClangBlockDescriptor3 *d3 = (struct ClangBlockDescriptor3 *)(desc + sizeof(struct ClangBlockDescriptor1));
    return d3->signature;
}
