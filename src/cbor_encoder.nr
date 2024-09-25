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

trait CborEncoder {
    fn cbor_encode<let N: u32>(self, buf: &mut [u8; N]);
}

impl CborEncoder for u64 {
    fn cbor_encode<let N: u32>(self, buf: &mut [u8; N]) {
        if self <= 23 {
            buf[0] = self as u8;
        } else if self <= 255 {
            buf[0] = 24;
            buf[1] = self as u8;
        } else if self <= 65535 {
            buf[0] = 25;
            buf[1] = (self >> 8) as u8;
            buf[2] = self as u8;
        } else if self <= 4294967295 {
            buf[0] = 26;
            buf[1] = (self >> 24) as u8;
            buf[2] = (self >> 16) as u8;
            buf[3] = (self >> 8) as u8;
            buf[4] = self as u8;
        } else if self > 4294967295 {
            // TODO: we should be able to use `else` here, but Noir doesn't execute properly
            buf[0] = 27;
            buf[1] = (self >> 56) as u8;
            buf[2] = (self >> 48) as u8;
            buf[3] = (self >> 40) as u8;
            buf[4] = (self >> 32) as u8;
            buf[5] = (self >> 24) as u8;
            buf[6] = (self >> 16) as u8;
            buf[7] = (self >> 8) as u8;
            buf[8] = self as u8;
        }
    }
}

impl CborEncoder for i64 {
    fn cbor_encode<let N: u32>(self, buf: &mut [u8; N]) {
        if self >= 0 {
            // non-negative integers are encoded as unsigned, "Major type 0"
            (self as u64).cbor_encode(buf);
        } else {
            // negative integers are "Major type 1"
            let u = (-1 - self) as u64;
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
            } else if u > 4294967295 {
                // TODO: we should be able to use `else` here, but Noir doesn't execute properly
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
}

// test helper function
fn encode_and_compare<let N: u32, T>(value: T, expected: [u8; N]) where T: CborEncoder {
    let mut buf = [0; N];
    value.cbor_encode(&mut buf);

    for i in 0..N {
        assert(buf[i] == expected[i]);
    }
}

#[test]
fn test_encode_uint() {
    // 0-23 (single byte)
    encode_and_compare(0 as u64, [0x00]);
    encode_and_compare(23 as u64, [0x17]);

    // 24-255 (two bytes)
    encode_and_compare(24 as u64, [0x18, 0x18]);
    encode_and_compare(255 as u64, [0x18, 0xff]);

    // 256-65535 (three bytes)
    encode_and_compare(256 as u64, [0x19, 1, 0]);
    encode_and_compare(65535 as u64, [0x19, 0xff, 0xff]);

    // 65536-4294967295 (five bytes)
    encode_and_compare(65536 as u64, [0x1a, 0, 1, 0, 0]);
    encode_and_compare(4294967295 as u64, [0x1a, 0xff, 0xff, 0xff, 0xff]);

    // 4294967296+ (nine bytes)
    encode_and_compare(
        4294967296 as u64,
        [0x1b, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]
    );
    encode_and_compare(
        18446744073709551615 as u64,
        [0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    );
}

#[test]
fn test_encode_int() {
    // Positive integers (should be encoded as unsigned)
    encode_and_compare(0 as i64, [0]);
    encode_and_compare(
        0x7fffffffffffffff as i64, // max i64 value
        [0x1b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    );

    // -1 to -24 (single byte)
    encode_and_compare(-1 as i64, [0x20]);
    encode_and_compare(-24 as i64, [0x37]);

    // -25 to -256 (two bytes)
    encode_and_compare(-25 as i64, [0x38, 0x18]);
    encode_and_compare(-256 as i64, [0x38, 0xff]);

    // -257 to -65536 (three bytes)
    encode_and_compare(-257 as i64, [0x39, 0x01, 0x00]);
    encode_and_compare(-65536 as i64, [0x39, 0xff, 0xff]);

    // -65537 to -4294967296 (five bytes)
    encode_and_compare(-65537 as i64, [0x3a, 0x00, 0x01, 0x00, 0x00]);
    encode_and_compare(-4294967296 as i64, [0x3a, 0xff, 0xff, 0xff, 0xff]);

    // <= -4294967297 (nine bytes)
    encode_and_compare(
        -4294967297 as i64,
        [0x3b, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]
    );
    encode_and_compare(
        -0x7fffffffffffffff as i64,
        [0x3b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe]
    );
}
