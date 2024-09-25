// CBOR encoding/decoding library implementing RFC 7049
// https://datatracker.ietf.org/doc/html/rfc7049
// Major type 0:  an unsigned integer
// SKIP Major type 1:  a negative integer
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

struct CborEncoder;

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
}

global TYPE_UINT: u8 = 0;
global TYPE_INT: u8 = 1;
// global TYPE_BYTES: u8 = 2;
// global TYPE_TEXT: u8 = 3;
// global TYPE_ARRAY: u8 = 4;
// global TYPE_MAP: u8 = 5;
// global TYPE_TAG: u8 = 6;
global TYPE_SIMPLE: u8 = 7;

impl CborEncoder {
    fn new() -> Self {
        Self {}
    }

    pub fn encode<let N: u32>(value: Value, buf: &mut [u8; N]) {
        if value.type_tag == TYPE_UINT {
            Self::encode_uint(value.uint_value, buf);
        }
    }

    fn encode_uint<let N: u32>(u: u64, buf: &mut [u8; N]) {
        if u <= 23 {
            buf[0] = u as u8;
        } else if u <= 255 {
            buf[0] = 24;
            buf[1] = u as u8;
        } else if u <= 65535 {
            buf[0] = 25;
            buf[1] = (u >> 8) as u8;
            buf[2] = u as u8;
        } else if u <= 4294967295 {
            buf[0] = 26;
            buf[1] = (u >> 24) as u8;
            buf[2] = (u >> 16) as u8;
            buf[3] = (u >> 8) as u8;
            buf[4] = u as u8;
        } else {
            buf[0] = 27;
            buf[1] = (u >> 56) as u8;
            buf[2] = (u >> 48) as u8;
            buf[3] = (u >> 40) as u8;
            buf[4] = (u >> 32) as u8;
            buf[5] = (u >> 24) as u8;
            buf[6] = (u >> 16) as u8;
            buf[7] = (u >> 8) as u8;
            buf[8] = u as u8;
        }
    }

    fn encode_sint() {}

    fn encode_bytes() {}

    fn encode_text() {}

    fn encode_array() {}

    fn encode_map() {}

    fn encode_simple() {}
}

fn main() {
    let uint_0 = Value { type_tag: TYPE_UINT, uint_value: 0, int_value: Default::default(), simple_value: Default::default() };
    let mut buf = [0; 1];
    CborEncoder::encode(uint_0, &mut buf);
    assert(buf[0] == 0);
}

// test helper function
fn encode_and_compare<let N: u32>(value: Value, expected: [u8; N]) {
    let mut buf = [0; N];
    CborEncoder::encode(value, &mut buf);

    for i in 0..N {
        assert(buf[i] == expected[i]);
    }
}

#[test]
fn test_encode_uint() {
    // 0-23 (single byte)
    let uint_0 = Value::new_uint(0);
    encode_and_compare(uint_0, [0]);
    let uint_23 = Value::new_uint(23);
    encode_and_compare(uint_23, [0x17]);

    // 24-255 (two bytes)
    let uint_24 = Value::new_uint(24);
    encode_and_compare(uint_24, [0x18, 0x18]);
    let uint_255= Value::new_uint(255);
    encode_and_compare(uint_255, [0x18, 0xff]);

    // 256-65535 (three bytes)
    let uint_256= Value::new_uint(256);
    encode_and_compare(uint_256, [0x19, 1, 0]);
    let uint_65535= Value::new_uint(65535);
    encode_and_compare(uint_65535, [0x19, 0xff, 0xff]);

    // 65536-4294967295 (five bytes)
    let uint_65536= Value::new_uint(65536);
    encode_and_compare(uint_65536, [0x1a, 0, 1, 0, 0]);
    let uint_4294967295= Value::new_uint(4294967295);
    encode_and_compare(uint_4294967295, [0x1a, 0xff, 0xff, 0xff, 0xff]);

    // 4294967296+ (nine bytes)
    let uint_4294967296= Value::new_uint(4294967296);
    encode_and_compare(uint_4294967296, [0x1b, 0, 0, 0, 1, 0, 0, 0, 0]);
    let uint_max= Value::new_uint(18446744073709551615);
    encode_and_compare(
        uint_max,
        [0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    );
}
