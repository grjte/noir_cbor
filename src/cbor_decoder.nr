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

    fn decode_int() {}

    fn decode_bytes() {}

    fn decode_text() {}

    fn decode_array() {}

    fn decode_map() {}

    fn decode_simple() {}
}
