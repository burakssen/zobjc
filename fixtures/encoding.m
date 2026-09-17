#import <objc/runtime.h>
#import <stdbool.h>

struct S1 {
    int x;
};

struct CGPoint {
    double x;
    double y;
};

union U1 {
    int i;
    float f;
};

struct Nested {
    struct CGPoint point;
    int flags;
};

const char *fixture_encode_char(void) { return @encode(char); }
const char *fixture_encode_uchar(void) { return @encode(unsigned char); }
const char *fixture_encode_short(void) { return @encode(short); }
const char *fixture_encode_ushort(void) { return @encode(unsigned short); }
const char *fixture_encode_int(void) { return @encode(int); }
const char *fixture_encode_uint(void) { return @encode(unsigned int); }
const char *fixture_encode_long(void) { return @encode(long); }
const char *fixture_encode_ulong(void) { return @encode(unsigned long); }
const char *fixture_encode_longlong(void) { return @encode(long long); }
const char *fixture_encode_ulonglong(void) { return @encode(unsigned long long); }
const char *fixture_encode_float(void) { return @encode(float); }
const char *fixture_encode_double(void) { return @encode(double); }
const char *fixture_encode_long_double(void) { return @encode(long double); }
const char *fixture_encode_bool(void) { return @encode(BOOL); }
const char *fixture_encode_c99_bool(void) { return @encode(_Bool); }
const char *fixture_encode_void(void) { return @encode(void); }
const char *fixture_encode_char_ptr(void) { return @encode(char *); }
const char *fixture_encode_const_char_ptr(void) { return @encode(const char *); }
const char *fixture_encode_void_ptr(void) { return @encode(void *); }
const char *fixture_encode_id(void) { return @encode(id); }
const char *fixture_encode_class(void) { return @encode(Class); }
const char *fixture_encode_sel(void) { return @encode(SEL); }

const char *fixture_encode_int_ptr(void) { return @encode(int *); }
const char *fixture_encode_int_ptr_ptr(void) { return @encode(int **); }

const char *fixture_encode_int_array_4(void) { return @encode(int[4]); }
const char *fixture_encode_float_array_16(void) { return @encode(float[16]); }
const char *fixture_encode_matrix_4_4(void) { return @encode(int[4][4]); }

const char *fixture_encode_struct_s1(void) { return @encode(struct S1); }
const char *fixture_encode_struct_cgpoint(void) { return @encode(struct CGPoint); }
const char *fixture_encode_union_u1(void) { return @encode(union U1); }
const char *fixture_encode_struct_nested(void) { return @encode(struct Nested); }
const char *fixture_encode_struct_s1_ptr(void) { return @encode(struct S1 *); }
const char *fixture_encode_struct_s1_ptr_ptr(void) { return @encode(struct S1 **); }

const char *fixture_encode_block_void(void) { return @encode(void (^)(void)); }
const char *fixture_encode_block_int(void) { return @encode(int (^)(float)); }
const char *fixture_encode_atomic_int(void) { return @encode(_Atomic(int)); }
