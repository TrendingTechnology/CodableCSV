import Foundation

extension CSVEncoder {
    /// Configuration for how to write CSV data.
   @dynamicMemberLookup public struct Configuration {
        /// The underlying `CSVWriter` configurations.
        @usableFromInline private(set) internal var writerConfiguration: CSVWriter.Configuration
        /// The strategy to use when encoding `nil`.
        public var nilStrategy: Strategy.NilEncoding
        /// The strategy to use when encoding Boolean values.
        public var boolStrategy: Strategy.BoolEncoding
        /// The strategy to use when dealing with non-conforming numbers (e.g. `NaN`, `+Infinity`, or `-Infinity`).
        public var floatStrategy: Strategy.NonConformingFloat
        /// The strategy to use when encoding decimal values.
        public var decimalStrategy: Strategy.DecimalEncoding
        /// The strategy to use when encoding dates.
        public var dateStrategy: Strategy.DateEncoding
        /// The strategy to use when encoding binary data.
        public var dataStrategy: Strategy.DataEncoding
        /// Indication on how encoded CSV rows are cached and actually written to the output target.
        public var bufferingStrategy: Strategy.EncodingBuffer
        
        /// Designated initializer setting the default values.
        public init() {
            self.nilStrategy = .empty
            self.boolStrategy = .deferredToString
            self.writerConfiguration = .init()
            self.floatStrategy = .throw
            self.decimalStrategy = .locale(nil)
            self.dateStrategy = .deferredToDate
            self.dataStrategy = .base64
            self.bufferingStrategy = .keepAll
        }
    
        /// Gives direct access to all CSV writer's configuration values.
        /// - parameter member: Writable key path for the writer's configuration values.
        public subscript<V>(dynamicMember member: WritableKeyPath<CSVWriter.Configuration,V>) -> V {
            @inlinable get { self.writerConfiguration[keyPath: member] }
            set { self.writerConfiguration[keyPath: member] = newValue }
        }
    }
}

extension CSVEncoder.Configuration {
}

// MARK: -

extension Strategy {
    /// The strategy to use for encoding `nil`.
    public enum NilEncoding {
        /// `nil` is encoded as an empty string.
        case empty
        /// Encode `nil` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the error will be bubled up.
        /// - parameter encoding: Function receiving the encoder instance to encode `nil`.
        /// - parameter encoder: The encoder on which to encode a custom `nil` representation.
        case custom(_ encoding: (_ encoder: Encoder) throws -> Void)
    }
    
    ///
    public enum BoolEncoding {
        /// Defers to `String`'s initializer.
        case deferredToString
        /// Encode the `Bool` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the error will be bubled up.
        /// - parameter encoding: Function receiving the necessary instances to encode a custom `Decimal` value.
        /// - parameter value: The value to be encoded.
        /// - parameter encoder: The encoder on which to generate a single value container.
        case custom(_ encoding: (_ value: Bool, _ encoder: Encoder) throws -> Void)
    }
    
    /// The strategy to use for encoding `Decimal` values.
    public enum DecimalEncoding {
        /// The locale used to write the number (specifically the `decimalSeparator` property).
        /// - parameter locale: The locale used to encode a `Decimal` value into a `String` value. If `nil`, the current user's locale will be used.
        case locale(_ locale: Locale? = nil)
        /// Encode the `Decimal` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the error will be bubled up.
        /// - parameter encoding: Function receiving the necessary instances to encode a custom `Decimal` value.
        /// - parameter value: The value to be encoded.
        /// - parameter encoder: The encoder on which to generate a single value container.
        case custom(_ encoding: (_ value: Decimal, _ encoder: Encoder) throws -> Void)
    }
    
    /// The strategy to use for encoding `Date` values.
    public enum DateEncoding {
        /// Defer to `Date` for choosing an encoding.
        case deferredToDate
        /// Encode the `Date` as a UNIX timestamp (as a number).
        case secondsSince1970
        /// Encode the `Date` as UNIX millisecond timestamp (as a number).
        case millisecondsSince1970
        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        case iso8601
        /// Encode the `Date` as a string formatted by the given formatter.
        /// - parameter formatter: The date formatter used to encode a `Date` value into a `String`.
        case formatted(_ formatter: DateFormatter)
        /// Formats dates by calling a user-defined function.
        ///
        /// If the closure fails to encode a value into the given encoder, the error will be bubled up.
        /// - parameter encoding: Function receiving the necessary instances to encode a custom `Date` value.
        /// - parameter value: The value to be encoded.
        /// - parameter encoder: The encoder on which to generate a single value container.
        case custom(_ encoding: (_ value: Date, _ encoder: Encoder) throws -> Void)
    }
    
    /// The strategy to use for encoding `Data` values.
    public enum DataEncoding {
        /// Defer to `Data` for choosing an encoding.
        case deferredToData
        /// Encoded the `Data` as a Base64-encoded string.
        case base64
        /// Formats data blobs by calling a user defined function.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode an empty automatic container in its place.
        /// - parameter encoding: Function receiving the necessary instances to encode a custom `Data` value.
        /// - parameter value: The value to be encoded.
        /// - parameter encoder: The encoder on which to generate a single value container.
        case custom(_ encoding: (_ value: Data, _ encoder: Encoder) throws -> Void)
    }
    
    /// Indication on how encoded CSV rows are cached and written to the output target (file, data blocb, or string).
    ///
    /// CSV encoding is an inherently sequential operation, i.e. row 2 must be encoded after row 1. On the other hand, the `Encodable` protocol allows CSV rows to be encoded in a random-order through *keyed container*.
    ///
    /// Selecting the appropriate buffering strategy lets you pick your encoding style and minimize memory usage.
    public enum EncodingBuffer {
        /// All encoded rows/fields are cached and the *writing* only occurs at the end of the encodable process.
        ///
        /// *Keyed containers* can be used to encode rows/fields unordered. That means, a row at position 5 may be encoded before the row at position 3. Similar behavior is supported for fields within a row.
        /// - remark: This strategy consumes the largest amount of memory from all the supported options.
        case keepAll
        /// Encoded rows may be cached, but the encoder will keep the buffer as small as possible by writing completed ordered rows.
        ///
        /// *Keyed containers* can be used to encode rows/fields unordered. The writer will however consume rows in order.
        ///
        /// For example, an encoder starts encoding row 1 and gets all its fields. The row will get written and no cache for the row is kept anymore. Same situation occurs when the row 2 is encoded.
        /// However, the user may decide to jump to row 5 and encode it. This row will be kept in the cache till row 3 and 4 are encoded, at which time row 3, 4, 5, and any subsequent rows will be writen.
        /// - attention: If no headers are passed during configuration the encoder has no way to know when a row is completed. That is why, the `.keepAll` buffering strategy will be used instead for such a case.
        /// - remark: This strategy tries to keep the cache to a minimum, but memory usage may be big if there are holes while encoding rows/fields. Those holes are filled with empty rows/fields at the end of the encoding process.
        case assembled
        /// Only the last row (the one being written) is kept in memory. Writes are performed sequentially.
        ///
        /// *Keyed containers* can be used, but at file-level any forward jump will imply writing empty-rows. At row-level *keyed containers* may still be used for random-order writing.
        /// - remark: This strategy provides the smallest usage of memory from them all.
        case sequential
    }
}
