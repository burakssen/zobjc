#ifndef ZOBJC_ENCODING_FIXTURES_H
#define ZOBJC_ENCODING_FIXTURES_H

#ifdef __cplusplus
extern "C" {
#endif

// Scalar primitives
const char *fixture_encode_char(void);
const char *fixture_encode_uchar(void);
const char *fixture_encode_short(void);
const char *fixture_encode_ushort(void);
const char *fixture_encode_int(void);
const char *fixture_encode_uint(void);
const char *fixture_encode_long(void);
const char *fixture_encode_ulong(void);
const char *fixture_encode_longlong(void);
const char *fixture_encode_ulonglong(void);
const char *fixture_encode_float(void);
const char *fixture_encode_double(void);
const char *fixture_encode_long_double(void);
const char *fixture_encode_bool(void);
const char *fixture_encode_c99_bool(void);
const char *fixture_encode_void(void);
const char *fixture_encode_char_ptr(void);
const char *fixture_encode_const_char_ptr(void);
const char *fixture_encode_void_ptr(void);
const char *fixture_encode_id(void);
const char *fixture_encode_class(void);
const char *fixture_encode_sel(void);

// Pointers
const char *fixture_encode_int_ptr(void);
const char *fixture_encode_int_ptr_ptr(void);

// Arrays
const char *fixture_encode_int_array_4(void);
const char *fixture_encode_float_array_16(void);
const char *fixture_encode_matrix_4_4(void);

// Aggregates
const char *fixture_encode_struct_s1(void);
const char *fixture_encode_struct_cgpoint(void);
const char *fixture_encode_union_u1(void);
const char *fixture_encode_struct_nested(void);
const char *fixture_encode_struct_s1_ptr(void);
const char *fixture_encode_struct_s1_ptr_ptr(void);

// Blocks & Atomics
const char *fixture_encode_block_void(void);
const char *fixture_encode_block_int(void);
const char *fixture_encode_atomic_int(void);

#ifdef __cplusplus
}
#endif

#endif // ZOBJC_ENCODING_FIXTURES_H
