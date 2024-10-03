// CBOR encoding/decoding library implementing RFC 7049
// https://datatracker.ietf.org/doc/html/rfc7049
// Major type 0:  an unsigned integer
// Major type 1:  a negative integer
// Major type 2:  a byte string
// Major type 3:  a text string, specifically a string of Unicode
//   characters that is encoded as UTF-8
// SKIP Major type 4:  an array of data items.
// SKIP Major type 5:  a map of pairs of data items.
// SKIP Major type 6:  optional semantic tagging of other major types.
// SKIP Major type 7:  floating-point numbers and simple data types that need
//   no content, as well as the "break" stop code.
//   => SKIP floating-point numbers
//   => simple types: False, True, Null, Undefined, Other(u8)

// TODO: optimize performance
fn cbor_encode_prefix<let N: u32>(major_type: u8, value: u64, buf: &mut [u8; N]) {
    // default to type prefix for major type 0
    let mut type_prefix = 0;
    if major_type == 1 {
        type_prefix = 0x20;
    } else if major_type == 2 {
        type_prefix = 0x40;
    } else if major_type == 3 {
        type_prefix = 0x60;
    } else if major_type != 0 {
        assert(false, "Major type not implemented");
    }

    if value <= 23 {
        buf[0] = type_prefix | value as u8;
    } else if value <= 255 {
        buf[0] = type_prefix | 0x18;
        buf[1] = value as u8;
    } else if value <= 65535 {
        buf[0] = type_prefix | 0x19;
        buf[1] = (value >> 8) as u8;
        buf[2] = value as u8;
    } else if value <= 4294967295 {
        buf[0] = type_prefix | 0x1a;
        buf[1] = (value >> 24) as u8;
        buf[2] = (value >> 16) as u8;
        buf[3] = (value >> 8) as u8;
        buf[4] = value as u8;
    } else if value > 4294967295 {
        // TODO: we should be able to use `else` here, but Noir doesn't execute properly
        buf[0] = type_prefix | 0x1b;
        buf[1] = (value >> 56) as u8;
        buf[2] = (value >> 48) as u8;
        buf[3] = (value >> 40) as u8;
        buf[4] = (value >> 32) as u8;
        buf[5] = (value >> 24) as u8;
        buf[6] = (value >> 16) as u8;
        buf[7] = (value >> 8) as u8;
        buf[8] = value as u8;
    }
}

trait CborEncoder {
    fn cbor_encode<let N: u32>(self, buf: &mut [u8; N]);
}

impl CborEncoder for u64 {
    fn cbor_encode<let N: u32>(self, buf: &mut [u8; N]) {
        // unsigned integers are "Major type 0"
        cbor_encode_prefix(0, self, buf);
    }
}

impl CborEncoder for i64 {
    fn cbor_encode<let N: u32>(self, buf: &mut [u8; N]) {
        if self >= 0 {
            // non-negative integers are encoded as unsigned
            (self as u64).cbor_encode(buf);
        } else {
            // negative integers are "Major type 1"
            let u = (-1 - self) as u64;
            cbor_encode_prefix(1, u, buf);
        }
    }
}

struct CborInputString<let N: u32> {
    bytes: [u8; N],
    is_text: bool
}

impl<let N: u32> CborInputString<N> {
    fn new(bytes: [u8; N], is_text: bool) -> Self {
        Self { bytes, is_text }
    }
}

impl<let N: u32> CborEncoder for CborInputString<N> {
    fn cbor_encode<let M: u32>(self, buf: &mut [u8; M]) {
        // encode the length of the byte string as an unsigned integer
        let len = N as u64;

        if !self.is_text {
            // byte strings are major type 2
            cbor_encode_prefix(2, len, buf);
        } else {
            // text strings are major type 3
            cbor_encode_prefix(3, len, buf);
        }

        // Copy the byte string, skipping the bytes that encode the length
        let prefix_len = M - N;
        for i in 0..N {
            buf[prefix_len + i] = self.bytes[i];
        }
    }
}

impl<let N: u32> CborEncoder for [u8; N] {
    fn cbor_encode<let M: u32>(self, buf: &mut [u8; M]) {
        let value = CborInputString::new(self, false);
        value.cbor_encode(buf)
    }
}

impl<let N: u32> CborEncoder for str<N> {
    fn cbor_encode<let M: u32>(self, buf: &mut [u8; M]) {
        let value = CborInputString::new(self.as_bytes(), true);
        value.cbor_encode(buf)
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

// Test encoding byte strings
#[test]
fn test_encode_bytes() {
    // Test empty byte string
    encode_and_compare([], [0x40]);

    // Test short byte string
    let bytes: [u8; 3] = [0x01, 0x02, 0x03];
    encode_and_compare(bytes, [0x43, 0x01, 0x02, 0x03]);

    // Test byte string with length 23 (boundary case)
    let input = [1 as u8; 23];
    let mut buf = [0 as u8; 24];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x57);
    for i in 0..23 {
        assert(buf[i + 1] == input[i]);
    }

    // Test byte string with length 24 (boundary case)
    let input = [1 as u8; 24];
    let mut buf = [0 as u8; 26];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x58);
    assert(buf[1] == 24);
    for i in 0..24 {
        assert(buf[i + 2] == input[i]);
    }

    // Test byte string with length 255 (boundary case)
    let input = [1 as u8; 255];
    let mut buf = [0 as u8; 257];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x58);
    assert(buf[1] == 255);
    for i in 0..255 {
        assert(buf[i + 2] == input[i]);
    }

    // Test byte string with length 256 (boundary case)
    let input = [1 as u8; 256];
    let mut buf = [0 as u8; 259];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x59);
    assert(buf[1] == 0x01);
    assert(buf[2] == 0x00);
    for i in 0..256 {
        assert(buf[i + 3] == input[i]);
    }
}

// Test cbor encoding for a string
#[test]
fn test_encode_str() {
    // Test short text string (length < 24)
    let input = "Hello";
    let input_bytes = input.as_bytes();
    let mut buf = [0 as u8; 6];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x65); // 0x60 | 5 (length of "Hello")
    for i in 0..input_bytes.len() {
        assert(buf[i + 1] == input_bytes[i]);
    }

    // Test text string with length 23 (boundary case)
    let input = "abcdefghijklmnopqrstuvw";
    let input_bytes = input.as_bytes();
    let mut buf = [0 as u8; 24];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x77); // 0x60 | 23
    for i in 0..input_bytes.len() {
        assert(buf[i + 1] == input_bytes[i]);
    }

    // Test UTF-8 encoding with non-ASCII characters
    let input = "こんにちは世界"; // "Hello world" in Japanese
    let input_bytes = input.as_bytes();
    let mut buf = [0 as u8; 22];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x75); // 0x60 | 21 (length of UTF-8 encoded string)
    for i in 0..input_bytes.len() {
        assert(buf[i + 1] == input_bytes[i]);
    }

    // Test text string with length 24 (requires 1-byte additional info)
    let input = "abcdefghijklmnopqrstuvwx";
    let input_bytes = input.as_bytes();
    let mut buf = [0 as u8; 26];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x78); // 0x60 | 24 (1-byte additional info)
    assert(buf[1] == 24); // Length encoded in 1 byte
    for i in 0..input_bytes.len() {
        assert(buf[i + 2] == input_bytes[i]);
    }

    // Test text string with length 255 bytes (max 1-byte additional info)
    let input = "Hello World! Àéîòü αβγδε АБВГД あいうえお 水火木金土 😁🌟🍕 €$£¥ ♠♣♥♦ ½¼¾ ©®™ ☃☕✈ ✔✘✖ ←↑→↓ ÅÆØ ĄĆĘ ßœŸ ışğ ΩΨΧ ЖЪЬ ღჩხ कखग กขค ツヨヮ ☺☢☠868";
    let input_bytes = input.as_bytes();
    let mut buf = [0 as u8; 257];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x78); // 0x60 | 24 (1-byte additional info)
    assert(buf[1] == 255); // Length encoded in 1 byte
    for i in 0..input_bytes.len() {
        assert(buf[i + 2] == input_bytes[i]);
    }

    // Test text string with length 256 bytes (min 2-byte additional info)
    let input = "😁✌👍❤️😂🌟✨🍕🎵☕🎉😍😘💪🌈🍔💜✅🌹😊🍺🎤😃🍃🎁😜📚💡😋✂👋🌊🍊😉😝🌺🍦💖💙💚💛💗💘🌷🌸🍀🍁🍂🍄🍅🍆🍇🍈🍉🍌🍍🍎🍏🍑🍒🍓🍖🍘🍝451";
    let input_bytes = input.as_bytes();
    let mut buf = [0 as u8; 259];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x79); // 0x60 | 25 (2-byte additional info)
    assert(buf[1] == 0x01); // Length encoded in 2 bytes (256 = 0x0100)
    assert(buf[2] == 0x00);
    for i in 0..input_bytes.len() {
        assert(buf[i + 3] == input_bytes[i]);
    }
}

// Test cbor encoding for a string of Unicode characters encoded as utf-8 bytes
#[test]
fn test_encode_text_bytes() {
    // Test short text string (length < 24)
    let input_bytes = "Hello".as_bytes();
    let input = CborInputString::new(input_bytes, true);
    let mut buf = [0 as u8; 6];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x65); // 0x60 | 5 (length of "Hello")
    for i in 0..input_bytes.len() {
        assert(buf[i + 1] == input_bytes[i]);
    }

    // Test text string with length 23 (boundary case)
    let input_bytes = "abcdefghijklmnopqrstuvw".as_bytes();
    let input = CborInputString::new(input_bytes, true);
    let mut buf = [0 as u8; 24];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x77); // 0x60 | 23
    for i in 0..input_bytes.len() {
        assert(buf[i + 1] == input_bytes[i]);
    }

    // Test UTF-8 encoding with non-ASCII characters
    let input_bytes = "こんにちは世界".as_bytes();
    let input = CborInputString::new(input_bytes, true);
    let mut buf = [0 as u8; 22];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x75); // 0x60 | 21 (length of UTF-8 encoded string)
    for i in 0..input_bytes.len() {
        assert(buf[i + 1] == input_bytes[i]);
    }

    // Test text string with length 24 (requires 1-byte additional info)
    let input_bytes = "abcdefghijklmnopqrstuvwx".as_bytes();
    let input = CborInputString::new(input_bytes, true);
    let mut buf = [0 as u8; 26];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x78); // 0x60 | 24 (1-byte additional info)
    assert(buf[1] == 24); // Length encoded in 1 byte
    for i in 0..input_bytes.len() {
        assert(buf[i + 2] == input_bytes[i]);
    }

    // Test text string with length 255 bytes (max 1-byte additional info)
    let input = "Hello World! Àéîòü αβγδε АБВГД あいうえお 水火木金土 😁🌟🍕 €$£¥ ♠♣♥♦ ½¼¾ ©®™ ☃☕✈ ✔✘✖ ←↑→↓ ÅÆØ ĄĆĘ ßœŸ ışğ ΩΨΧ ЖЪЬ ღჩხ कखग กขค ツヨヮ ☺☢☠868";
    let input_bytes = input.as_bytes();
    let input = CborInputString::new(input_bytes, true);
    let mut buf = [0 as u8; 257];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x78); // 0x60 | 24 (1-byte additional info)
    assert(buf[1] == 255); // Length encoded in 1 byte
    for i in 0..input_bytes.len() {
        assert(buf[i + 2] == input_bytes[i]);
    }

    // Test text string with length 256 bytes (min 2-byte additional info)
    let input = "😁✌👍❤️😂🌟✨🍕🎵☕🎉😍😘💪🌈🍔💜✅🌹😊🍺🎤😃🍃🎁😜📚💡😋✂👋🌊🍊😉😝🌺🍦💖💙💚💛💗💘🌷🌸🍀🍁🍂🍄🍅🍆🍇🍈🍉🍌🍍🍎🍏🍑🍒🍓🍖🍘🍝451";
    let input_bytes = input.as_bytes();
    let input = CborInputString::new(input_bytes, true);
    let mut buf = [0 as u8; 259];
    input.cbor_encode(&mut buf);
    assert(buf[0] == 0x79); // 0x60 | 25 (2-byte additional info)
    assert(buf[1] == 0x01); // Length encoded in 2 bytes (256 = 0x0100)
    assert(buf[2] == 0x00);
    for i in 0..input_bytes.len() {
        assert(buf[i + 3] == input_bytes[i]);
    }
}
