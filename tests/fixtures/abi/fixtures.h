#ifndef ABI_FIXTURES_H
#define ABI_FIXTURES_H

#import <objc/NSObject.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct { char a; } ABISize1;
typedef struct { short a; } ABISize2;
typedef struct { char a; short b; } ABISize3;
typedef struct { int a; } ABISize4;
typedef struct { int a; char b; char c; char d; } ABISize7;
typedef struct { long long a; } ABISize8;
typedef struct { int a; float b; } ABISize8Mixed;
typedef struct { long long a; char b; } ABISize9;
typedef struct { int a; int b; int c; } ABISize12;
typedef struct { long long a; long long b; } ABISize16Int;
typedef struct { double a; double b; } ABISize16Float;
typedef struct { int a; double b; } ABISize16Mixed;
typedef struct { long long a; long long b; char c; } ABISize17;
typedef struct { double a; double b; double c; } ABISize24;
typedef struct { double a; double b; double c; double d; } ABISize32;
typedef struct { long double x; } ABIStructLongDouble;
typedef struct { int a; long double b; } ABIStructMixedLongDouble;
typedef struct { double x, y; } ABIPoint;
typedef struct { double width, height; } ABISize;
typedef struct { ABIPoint origin; ABISize size; } ABIRect;
typedef struct { ABIPoint pt; int tag; } ABINested;
typedef struct { double vals[2]; } ABIArrayInStruct;
typedef union { long long i; double d; } ABIUnion8;

@interface ABIFixture : NSObject

- (void)returnVoid;
- (int)returnInt;
- (float)returnFloat;
- (double)returnDouble;
- (long double)returnLongDouble;
- (_Complex long double)returnComplexLongDouble;

- (ABISize1)returnSize1;
- (ABISize2)returnSize2;
- (ABISize3)returnSize3;
- (ABISize4)returnSize4;
- (ABISize7)returnSize7;
- (ABISize8)returnSize8;
- (ABISize8Mixed)returnSize8Mixed;
- (ABISize9)returnSize9;
- (ABISize12)returnSize12;
- (ABISize16Int)returnSize16Int;
- (ABISize16Float)returnSize16Float;
- (ABISize16Mixed)returnSize16Mixed;
- (ABISize17)returnSize17;
- (ABISize24)returnSize24;
- (ABISize32)returnSize32;
- (ABIStructLongDouble)returnStructLongDouble;
- (ABIStructMixedLongDouble)returnStructMixedLongDouble;
- (ABIPoint)returnPoint;
- (ABISize)returnSize;
- (ABIRect)returnRect;
- (ABINested)returnNested;
- (ABIArrayInStruct)returnArrayInStruct;
- (ABIUnion8)returnUnion8;

+ (int)addInt:(int)a to:(int)b;
+ (double)multiplyDouble:(double)a by:(double)b;
- (int)echoInt:(int)val;

// Register pressure and spilled arguments
- (int)sum10Ints:(int)a b:(int)b c:(int)c d:(int)d e:(int)e f:(int)f g:(int)g h:(int)h i:(int)i j:(int)j;
- (double)sum10Doubles:(double)a b:(double)b c:(double)c d:(double)d e:(double)e f:(double)f g:(double)g h:(double)h i:(double)i j:(double)j;
- (double)passSize32:(ABISize32)val;

@end

@interface ABISubclass : ABIFixture
- (int)echoInt:(int)val;
- (int)callSuperEcho:(int)val;
@end

#ifdef __cplusplus

}
#endif

#endif // ABI_FIXTURES_H
