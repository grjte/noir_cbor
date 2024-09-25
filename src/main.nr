mod cbor_error;
mod cbor_encoder;
// mod cbor_decoder;

fn main() {
    let mut buf = [0; 1];
    (0 as u64).cbor_encode(&mut buf);
    assert(buf[0] == 0);
}
