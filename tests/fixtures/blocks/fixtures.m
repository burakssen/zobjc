#import "fixtures.h"
#include <Block.h>

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

int get_dealloc_count(void) {
    return g_dealloc_count;
}

void reset_dealloc_count(void) {
    g_dealloc_count = 0;
}

// --- Clang Block Producers ---

int (^make_int_multiplier_block(int multiplier))(int) {
    return Block_copy(^(int x) {
        return x * multiplier;
    });
}

id (^make_object_holder_block(id obj))(void) {
    return Block_copy(^{
        return obj;
    });
}

int (^make_byref_counter_block(int initial))(int) {
    __block int counter = initial;
    return Block_copy(^(int delta) {
        counter += delta;
        return counter;
    });
}

// --- Clang Block Consumers ---

int invoke_int_block(int (^block)(int), int val) {
    return block(val);
}

id invoke_object_block(id (^block)(id), id val) {
    return block(val);
}

int invoke_two_arg_block(int (^block)(int, int), int x, int y) {
    return block(x, y);
}

// --- ABI Introspection Helpers ---

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
    if (!(flags & (1 << 30))) { // BLOCK_HAS_SIGNATURE
        return NULL;
    }

    const char *desc = (const char *)layout->descriptor;
    if (flags & (1 << 25)) { // BLOCK_HAS_COPY_DISPOSE
        struct ClangBlockDescriptor3 *d3 = (struct ClangBlockDescriptor3 *)(desc + sizeof(struct ClangBlockDescriptor1) + sizeof(struct ClangBlockDescriptor2));
        return d3->signature;
    } else {
        struct ClangBlockDescriptor3 *d3 = (struct ClangBlockDescriptor3 *)(desc + sizeof(struct ClangBlockDescriptor1));
        return d3->signature;
    }
}
