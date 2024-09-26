mod cbor_error;
mod cbor_encoder;
mod cbor_decoder;
use cbor_decoder::CborDecoder;

fn main() {
    let mut buf = [0; 1];
    (0 as u64).cbor_encode(&mut buf);
    assert(buf[0] == 0);

    let encoded = [0x00];
    let decoded: u64 = CborDecoder::cbor_decode(encoded);
    assert(decoded == 0);
}
