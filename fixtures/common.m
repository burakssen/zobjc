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

