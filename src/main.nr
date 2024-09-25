mod cbor_types;
use cbor_types::Value;

mod cbor_encoder;
use cbor_encoder::CborEncoder;

fn main() {
    let uint_0 = Value::new_uint(0);
    let mut buf = [0; 1];
    CborEncoder::encode(uint_0, &mut buf);
    assert(buf[0] == 0);
}