// CBOR encoding/decoding library implementing RFC 7049
// https://datatracker.ietf.org/doc/html/rfc7049
// Major type 0:  an unsigned integer
// Major type 1:  a negative integer
// SKIP Major type 2:  a byte string
// SKIP Major type 3:  a text string, specifically a string of Unicode
//   characters that is encoded as UTF-8
// SKIP Major type 4:  an array of data items.
// SKIP Major type 5:  a map of pairs of data items.
// SKIP Major type 6:  optional semantic tagging of other major types.
// SKIP Major type 7:  floating-point numbers and simple data types that need
//   no content, as well as the "break" stop code.
//   => SKIP floating-point numbers
//   => simple types: False, True, Null, Undefined, Other(u8)

global TYPE_UINT: u8 = 0;
global TYPE_INT: u8 = 1;
// global TYPE_BYTES: u8 = 2;
// global TYPE_TEXT: u8 = 3;
// global TYPE_ARRAY: u8 = 4;
// global TYPE_MAP: u8 = 5;
// global TYPE_TAG: u8 = 6;
// global TYPE_SIMPLE: u8 = 7;

struct Value {
    type_tag: u8,
    uint_value: u64,
    int_value: i64,
    simple_value: u8
}

impl Value {
    fn new_uint(value: u64) -> Self {
        Self { type_tag: TYPE_UINT, uint_value: value, int_value: Default::default(), simple_value: Default::default() }
    }

    fn new_int(value: i64) -> Self {
        Self { type_tag: TYPE_INT, uint_value: Default::default(), int_value: value, simple_value: Default::default() }
    }
}
