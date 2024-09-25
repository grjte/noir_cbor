struct CborDecodingError {
    code: u8,
}

global DECODING_ERROR_INPUT_TOO_SHORT: u8 = 1;
global DECODING_ERROR_UNSUPPORTED_TYPE: u8 = 2;
global DECODING_ERROR_INVALID_ADDITIONAL_INFO: u8 = 3;

impl CborDecodingError {
    fn InputTooShort() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_INPUT_TOO_SHORT }
    }

    fn UnsupportedType() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_UNSUPPORTED_TYPE }
    }

    fn InvalidAdditionalInfo() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_INVALID_ADDITIONAL_INFO }
    }
}
