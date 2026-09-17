#ifndef ZOBJC_BLOCK_FIXTURES_H
#define ZOBJC_BLOCK_FIXTURES_H

#import <objc/NSObject.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct _NSZone NSZone;

@protocol NSCopying
- (id)copyWithZone:(NSZone *)zone;
@end

// --- Tracking Class for Lifetime Verification ---
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

// --- Clang Block Producers ---
int (^make_int_multiplier_block(int multiplier))(int);
id (^make_object_holder_block(id obj))(void);
int (^make_byref_counter_block(int initial))(int);

// --- Clang Block Consumers ---
int invoke_int_block(int (^block)(int), int val);
id invoke_object_block(id (^block)(id), id val);
int invoke_two_arg_block(int (^block)(int, int), int x, int y);

// --- Block & ByRef ABI Introspection Helpers ---
int32_t get_clang_block_flags(void *block);
uintptr_t get_clang_block_descriptor_size(void *block);
const char *get_clang_block_signature(void *block);

#endif // ZOBJC_BLOCK_FIXTURES_H
