use super::cbor_error::CborDecodingError;

trait CborDecoder {
    fn cbor_decode<let N: u32>(input: [u8; N]) -> Self;
}

impl CborDecoder for u64 {
    fn cbor_decode<let N: u32>(input: [u8; N]) -> u64 {
        assert(N != 0, CborDecodingError::InputTooShort());
        let major_type = input[0] >> 5;
        assert(major_type == 0, CborDecodingError::InvalidMajorType());

        let additional_info = input[0] & 0x1f;
        let mut result: u64 = 0;

        if additional_info < 24 {
            result = additional_info as u64;
        } else if additional_info == 24 {
            assert(N == 2, CborDecodingError::InputTooShort());
            result = input[1] as u64;
        } else if additional_info == 25 {
            assert(N == 3, CborDecodingError::InputTooShort());
            result = ((input[1] as u64) << 8) | (input[2] as u64);
        } else if additional_info == 26 {
            assert(N == 5, CborDecodingError::InputTooShort());
            result = ((input[1] as u64) << 24)
                | ((input[2] as u64) << 16)
                | ((input[3] as u64) << 8)
                | (input[4] as u64);
        } else {
            assert(additional_info == 27, CborDecodingError::InvalidAdditionalInfo());
            assert(N == 9, CborDecodingError::InputTooShort());
            result = ((input[1] as u64) << 56)
                | ((input[2] as u64) << 48)
                | ((input[3] as u64) << 40)
                | ((input[4] as u64) << 32)
                | ((input[5] as u64) << 24)
                | ((input[6] as u64) << 16)
                | ((input[7] as u64) << 8)
                | (input[8] as u64);
        }

        result
    }
}

impl CborDecoder for i64 {
    fn cbor_decode<let N: u32>(input: [u8; N]) -> i64 {
        let major_type = input[0] >> 5;
        assert(major_type == 1, CborDecodingError::InvalidMajorType());

        // set the major type to 0 for decoding as unsigned
        let mut input = input;
        input[0] = input[0] ^ 0x20;
        let input = input;

        // decode as unsigned then compute the result
        let unsigned: u64 = CborDecoder::cbor_decode(input);
        let result = -1 - (unsigned as i64);
        result
    }
}

// test helper function
fn decode_and_compare<let N: u32, T>(input: [u8; N], expected: T) where T: CborDecoder + Eq {
    let decoded = T::cbor_decode(input);
    assert(decoded == expected);
}

#[test]
fn test_decode_uint() {
    // 0-23 (single byte)
    decode_and_compare([0x00], 0 as u64);
    decode_and_compare([0x17], 23 as u64);

    // 24-255 (two bytes)
    decode_and_compare([0x18, 0x18], 24 as u64);
    decode_and_compare([0x18, 0xff], 255 as u64);

    // 256-65535 (three bytes)
    decode_and_compare([0x19, 0x01, 0x00], 256 as u64);
    decode_and_compare([0x19, 0xff, 0xff], 65535 as u64);

    // 65536-4294967295 (five bytes)
    decode_and_compare([0x1a, 0x00, 0x01, 0x00, 0x00], 65536 as u64);
    decode_and_compare([0x1a, 0xff, 0xff, 0xff, 0xff], 4294967295 as u64);

    // 65536-4294967295 (nine bytes)
    decode_and_compare(
        [0x1b, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00],
        4294967296 as u64
    );
    decode_and_compare(
        [0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
        18446744073709551615 as u64
    );
}

#[test]
fn test_decode_nint() {
    // -1 to -24 (single byte)
    decode_and_compare([0x20], -1 as i64);
    decode_and_compare([0x37], -24 as i64);

    // -25 to -256 (two bytes)
    decode_and_compare([0x38, 0x18], -25 as i64);
    decode_and_compare([0x38, 0xff], -256 as i64);

    // -257 to -65536 (three bytes)
    decode_and_compare([0x39, 0x01, 0x00], -257 as i64);
    decode_and_compare([0x39, 0xff, 0xff], -65536 as i64);

    // -65537 to -4294967296 (five bytes)
    decode_and_compare([0x3a, 0x00, 0x01, 0x00, 0x00], -65537 as i64);
    decode_and_compare([0x3a, 0xff, 0xff, 0xff, 0xff], -4294967296 as i64);

    // <= -4294967297 (nine bytes)
    decode_and_compare(
        [0x3b, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00],
        -4294967297 as i64
    );
    decode_and_compare(
        [0x3b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe],
        -0x7fffffffffffffff as i64
    );
}
