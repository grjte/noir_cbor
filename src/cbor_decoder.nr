use super::cbor_types::{Value, TYPE_UINT, TYPE_INT};
use super::cbor_error::CborDecodingError;

struct CborDecoder;

impl CborDecoder {
    fn new() -> Self {
        Self {}
    }

    pub fn decode<let N: u32>(input: [u8; N]) -> Value {
        assert(N != 0, CborDecodingError::InputTooShort());

        let first_byte = input[0];
        let major_type = first_byte >> 5;

        // create a default value, since early return is not allowed
        let mut result = Value::new_uint(0);

        if major_type == 0 {
            result = Self::decode_uint(input);
        } else if major_type == 1 {
            result = Self::decode_nint(input);
        } else {
            assert(false, CborDecodingError::UnsupportedType());
        }

        result
    }

    fn decode_uint<let N: u32>(input: [u8; N]) -> Value {
        assert(N != 0, CborDecodingError::InputTooShort());

        let additional_info = input[0] & 0x1f;
        let mut result = Value::new_uint(0);

        if additional_info < 24 {
            result = Value::new_uint(additional_info as u64);
        } else if additional_info == 24 {
            assert(N == 2, CborDecodingError::InputTooShort());
            result = Value::new_uint(input[1] as u64);
        } else if additional_info == 25 {
            assert(N == 3, CborDecodingError::InputTooShort());
            let value = ((input[1] as u64) << 8) | (input[2] as u64);
            result = Value::new_uint(value);
        } else if additional_info == 26 {
            assert(N == 5, CborDecodingError::InputTooShort());
            let value = ((input[1] as u64) << 24)
                | ((input[2] as u64) << 16)
                | ((input[3] as u64) << 8)
                | (input[4] as u64);
            result = Value::new_uint(value);
        } else {
            assert(additional_info == 27, CborDecodingError::InvalidAdditionalInfo());
            assert(N == 9, CborDecodingError::InputTooShort());
            let value = ((input[1] as u64) << 56)
                | ((input[2] as u64) << 48)
                | ((input[3] as u64) << 40)
                | ((input[4] as u64) << 32)
                | ((input[5] as u64) << 24)
                | ((input[6] as u64) << 16)
                | ((input[7] as u64) << 8)
                | (input[8] as u64);
            result = Value::new_uint(value);
        }

        result
    }

    fn decode_nint<let N: u32>(input: [u8; N]) -> Value {
        let unsigned = Self::decode_uint(input);
        let value = -1 - (unsigned.uint_value as i64);
        Value::new_int(value)
    }

    fn decode_bytes() {}

    fn decode_text() {}

    fn decode_array() {}

    fn decode_map() {}

    fn decode_simple() {}
}

// test helper function
fn decode_and_compare<let N: u32>(input: [u8; N], expected: Value) {
    let decoded = CborDecoder::decode(input);
    assert(decoded.type_tag == expected.type_tag);
    if expected.type_tag == TYPE_UINT {
        assert(decoded.uint_value == expected.uint_value);
    } else if expected.type_tag == TYPE_INT {
        assert(decoded.int_value == expected.int_value);
    }
}

#[test]
fn test_decode_uint() {
    // 0-23 (single byte)
    decode_and_compare([0x00], Value::new_uint(0));
    decode_and_compare([0x17], Value::new_uint(23));

    // 24-255 (two bytes)
    decode_and_compare([0x18, 0x18], Value::new_uint(24));
    decode_and_compare([0x18, 0xff], Value::new_uint(255));

    // 256-65535 (three bytes)
    decode_and_compare([0x19, 0x01, 0x00], Value::new_uint(256));
    decode_and_compare([0x19, 0xff, 0xff], Value::new_uint(65535));

    // 65536-4294967295 (five bytes)
    decode_and_compare([0x1a, 0x00, 0x01, 0x00, 0x00], Value::new_uint(65536));
    decode_and_compare([0x1a, 0xff, 0xff, 0xff, 0xff], Value::new_uint(4294967295));

    // 65536-4294967295 (nine bytes)
    decode_and_compare(
        [0x1b, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00],
        Value::new_uint(4294967296)
    );
    decode_and_compare(
        [0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
        Value::new_uint(18446744073709551615)
    );
}
