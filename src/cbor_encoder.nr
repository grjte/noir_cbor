use super::cbor_types::{Value, TYPE_INT, TYPE_UINT};
struct CborEncoder;

impl CborEncoder {
    fn new() -> Self {
        Self {}
    }

    pub fn encode<let N: u32>(value: Value, buf: &mut [u8; N]) {
        if value.type_tag == TYPE_UINT {
            Self::encode_uint(value.uint_value, buf);
        } else if value.type_tag == TYPE_INT {
            Self::encode_int(value.int_value, buf);
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

    fn encode_int<let N: u32>(n: i64, buf: &mut [u8; N]) {
        if n >= 0 {
            // non-negative integers are encoded as unsigned, "Major type 0"
            Self::encode_uint(n as u64, buf);
        } else {
            // negative integers are "Major type 1"
            let u = (-1 - n) as u64;
            if u <= 23 {
                buf[0] = 0x20 | u as u8;
            } else if u <= 255 {
                buf[0] = 0x38;
                buf[1] = u as u8;
            } else if u <= 65535 {
                buf[0] = 0x39;
                buf[1] = (u >> 8) as u8;
                buf[2] = u as u8;
            } else if u <= 4294967295 {
                buf[0] = 0x3a;
                buf[1] = (u >> 24) as u8;
                buf[2] = (u >> 16) as u8;
                buf[3] = (u >> 8) as u8;
                buf[4] = u as u8;
            } else {
                buf[0] = 0x3b;
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
    }

    fn encode_bytes() {}

    fn encode_text() {}

    fn encode_array() {}

    fn encode_map() {}

    fn encode_simple() {}
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
    encode_and_compare(Value::new_uint(0), [0]);
    encode_and_compare(Value::new_uint(23), [0x17]);

    // 24-255 (two bytes)
    encode_and_compare(Value::new_uint(24), [0x18, 0x18]);
    encode_and_compare(Value::new_uint(255), [0x18, 0xff]);

    // 256-65535 (three bytes)
    encode_and_compare(Value::new_uint(256), [0x19, 1, 0]);
    encode_and_compare(Value::new_uint(65535), [0x19, 0xff, 0xff]);

    // 65536-4294967295 (five bytes)
    encode_and_compare(Value::new_uint(65536), [0x1a, 0, 1, 0, 0]);
    encode_and_compare(Value::new_uint(4294967295), [0x1a, 0xff, 0xff, 0xff, 0xff]);

    // 4294967296+ (nine bytes)
    encode_and_compare(Value::new_uint(4294967296), [0x1b, 0, 0, 0, 1, 0, 0, 0, 0]);
    encode_and_compare(
        Value::new_uint(18446744073709551615),
        [0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    );
}

#[test]
fn test_encode_int() {
    // Positive integers (should be encoded as unsigned)
    encode_and_compare(Value::new_int(0), [0]);
    encode_and_compare(
        Value::new_int(0x7fffffffffffffff), // max i64 value
        [0x1b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    );

    // -1 to -24 (single byte)
    encode_and_compare(Value::new_int(-1), [0x20]);
    encode_and_compare(Value::new_int(-24), [0x37]);

    // -25 to -256 (two bytes)
    encode_and_compare(Value::new_int(-25), [0x38, 0x18]);
    encode_and_compare(Value::new_int(-256), [0x38, 0xff]);

    // -257 to -65536 (three bytes)
    encode_and_compare(Value::new_int(-257), [0x39, 0x01, 0x00]);
    encode_and_compare(Value::new_int(-65536), [0x39, 0xff, 0xff]);

    // -65537 to -4294967296 (five bytes)
    encode_and_compare(Value::new_int(-65537), [0x3a, 0x00, 0x01, 0x00, 0x00]);
    encode_and_compare(Value::new_int(-4294967296), [0x3a, 0xff, 0xff, 0xff, 0xff]);

    // <= -4294967297 (nine bytes)
    encode_and_compare(
        Value::new_int(-4294967297),
        [0x3b, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]
    );
    encode_and_compare(
        Value::new_int(-0x8000000000000000), // min i64 value
        [0x3b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    );
}
