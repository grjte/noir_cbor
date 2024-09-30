struct CborDecodingError {
    code: u8,
}

global DECODING_ERROR_INPUT_TOO_SHORT: u8 = 1;
global DECODING_ERROR_UNSUPPORTED_TYPE: u8 = 2;
global DECODING_ERROR_INVALID_MAJOR_TYPE: u8 = 3;
global DECODING_ERROR_INVALID_ADDITIONAL_INFO: u8 = 4;
global DECODING_ERROR_INPUT_TOO_LONG: u8 = 5;

impl CborDecodingError {
    fn InputTooShort() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_INPUT_TOO_SHORT }
    }

    fn InputTooLong() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_INPUT_TOO_LONG }
    }

    fn UnsupportedType() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_UNSUPPORTED_TYPE }
    }

    fn InvalidMajorType() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_INVALID_MAJOR_TYPE }
    }

    fn InvalidAdditionalInfo() -> CborDecodingError {
        CborDecodingError { code: DECODING_ERROR_INVALID_ADDITIONAL_INFO }
    }
}
