#import <objc/NSObject.h>

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
- (int)sum10Ints:(int)a b:(int)b c:(int)c d:(int)d e:(int)e f:(int)f g:(int)g h:(int)h i:(int)i j:(int)j;
- (double)sum10Doubles:(double)a b:(double)b c:(double)c d:(double)d e:(double)e f:(double)f g:(double)g h:(double)h i:(double)i j:(double)j;
- (double)passSize32:(ABISize32)val;
@end

@interface ABISubclass : ABIFixture
- (int)echoInt:(int)val;
- (int)callSuperEcho:(int)val;
@end

@implementation ABIFixture
- (void)returnVoid {}
- (int)returnInt { return 42; }
- (float)returnFloat { return 3.14f; }
- (double)returnDouble { return 2.718281828; }
- (long double)returnLongDouble { return 1.41421356237309504880L; }
- (_Complex long double)returnComplexLongDouble { return 1.0L + 2.0Li; }
- (ABISize1)returnSize1 { ABISize1 s = { 'A' }; return s; }
- (ABISize2)returnSize2 { ABISize2 s = { 100 }; return s; }
- (ABISize3)returnSize3 { ABISize3 s = { 'B', 200 }; return s; }
- (ABISize4)returnSize4 { ABISize4 s = { 1000 }; return s; }
- (ABISize7)returnSize7 { ABISize7 s = { 10, 'x', 'y', 'z' }; return s; }
- (ABISize8)returnSize8 { ABISize8 s = { 1234567890123LL }; return s; }
- (ABISize8Mixed)returnSize8Mixed { ABISize8Mixed s = { 10, 20.0f }; return s; }
- (ABISize9)returnSize9 { ABISize9 s = { 123LL, 'c' }; return s; }
- (ABISize12)returnSize12 { ABISize12 s = { 1, 2, 3 }; return s; }
- (ABISize16Int)returnSize16Int { ABISize16Int s = { 100LL, 200LL }; return s; }
- (ABISize16Float)returnSize16Float { ABISize16Float s = { 1.5, 2.5 }; return s; }
- (ABISize16Mixed)returnSize16Mixed { ABISize16Mixed s = { 42, 3.14 }; return s; }
- (ABISize17)returnSize17 { ABISize17 s = { 1LL, 2LL, 'z' }; return s; }
- (ABISize24)returnSize24 { ABISize24 s = { 1.0, 2.0, 3.0 }; return s; }
- (ABISize32)returnSize32 { ABISize32 s = { 1.0, 2.0, 3.0, 4.0 }; return s; }
- (ABIStructLongDouble)returnStructLongDouble { ABIStructLongDouble s = { 3.14L }; return s; }
- (ABIStructMixedLongDouble)returnStructMixedLongDouble { ABIStructMixedLongDouble s = { 1, 3.14L }; return s; }
- (ABIPoint)returnPoint { ABIPoint p = { 10.0, 20.0 }; return p; }
- (ABISize)returnSize { ABISize s = { 100.0, 200.0 }; return s; }
- (ABIRect)returnRect { ABIRect r = { { 10.0, 20.0 }, { 100.0, 200.0 } }; return r; }
- (ABINested)returnNested { ABINested n = { { 1.0, 2.0 }, 99 }; return n; }
- (ABIArrayInStruct)returnArrayInStruct { ABIArrayInStruct a = { { 1.1, 2.2 } }; return a; }
- (ABIUnion8)returnUnion8 { ABIUnion8 u; u.i = 0x123456789ABCDEF0LL; return u; }
+ (int)addInt:(int)a to:(int)b { return a + b; }
+ (double)multiplyDouble:(double)a by:(double)b { return a * b; }
- (int)echoInt:(int)val { return val; }
- (int)sum10Ints:(int)a b:(int)b c:(int)c d:(int)d e:(int)e f:(int)f g:(int)g h:(int)h i:(int)i j:(int)j {
    return a + b + c + d + e + f + g + h + i + j;
}
- (double)sum10Doubles:(double)a b:(double)b c:(double)c d:(double)d e:(double)e f:(double)f g:(double)g h:(double)h i:(double)i j:(double)j {
    return a + b + c + d + e + f + g + h + i + j;
}
- (double)passSize32:(ABISize32)val {
    return val.a + val.b + val.c + val.d;
}
@end

@implementation ABISubclass
- (int)echoInt:(int)val { return [super echoInt:val] * 10; }
- (int)callSuperEcho:(int)val { return [super echoInt:val]; }
@end
