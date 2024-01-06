import Foundation

/// Type representing a generator of Hylo source files
/// specific for integer types.
/// - Discussion
/// Is possible to generate `.all`, `.signed`, `.unsigned` integer group,
/// choosing if write or not on filesystem.
/// ```
///guard let gen = HyloIntGen(writeToPath: "${HYLO_PATH}/StandardLibrary/Sources/Core/Numbers/Integers/") else {
///   print("Could not use \(writeToPath) as current path.")
///   return
///}
/////build content of all Hylo integer types (useful for debugging). No write on filesystem by default.
///let allIntTypesDict = try gen.build()!
/////  iter over generated content which represent tthe several integer types
///for entry in allIntTypesDict {
///  print("Type: \(entry.key) - File string content:\n\n \(entry.value)\n")
///}
///
/////build content of all Hylo unsigned integer types writing on filesystem.
/////Avoids data caching consuming it, so is useless to wait for an output value (nil)
///do {
///  _ = try gen.build(intFamily: .unsigned, persist = true)
///catch {
///  print(error.localizedDescription)
///}
///```
public struct HyloIntGen {
  let pathToWrite: String

  init?(pathToWrite: String = "${HYLOPATH}/StandardLibrary/Sources/Core/Numbers/Integers/") {
    var isDir: ObjCBool = false
    if !FileManager.default.fileExists(atPath: pathToWrite, isDirectory: &isDir) {
      print("Given path \"\(pathToWrite)\" not found.")
      return nil
    }

    if !isDir.boolValue {
      print("Given path \"\(pathToWrite)\" is not a directory.")
      return nil
    }

    self.pathToWrite = pathToWrite
  }

  private func templateFormatter(
    family: IntFamily,
    kind: IntKind,
    representationType: String
  ) -> String {
    let type = kind.rawValue
    let isNotInt32 = kind != .int32

    let baseIntTemplate = """
      /// A \(family.rawValue) integer value.
      public type \(type) {

        var value: Builtin.\(isNotInt32 ? representationType : "i32")

        memberwise init

        \(isNotInt32 ? """
        /// Creates an instance with the same memory representation as `other`.
        public init(bit_pattern other: \(SpecificPartGen.bitPattern(kind))) {
          &self.value = other.value
        }
        """ : "")


        \(family == .signed ? """
        /// Returns the absolute value of `self`.
        public fun abs() -> \(type) {
          if self < 0 { -self } else { +self }
        }
        """ : "")

      }

      public conformance \(type): ExpressibleByIntegerLiteral {}

      public conformance \(type): Deinitializable {}

      public conformance \(type): Movable {}

      public conformance \(type): Copyable {

        public fun copy() -> Self {
          \(type)(value: value)
        }

      }

      public conformance \(type): Equatable {

        public fun infix== (_ other: Self) -> Bool {
          Bool(value: Builtin.icmp_eq_\(representationType)(value, other.value))
        }

        public fun infix!= (_ other: Self) -> Bool {
          Bool(value: Builtin.icmp_ne_\(representationType)(value, other.value))
        }

      }
      \(isNotInt32 ? "\npublic conformance \(type): Regular {}\n\n" : "")
      public conformance \(type): Hashable {

        public fun hash(into hasher: inout Hasher) {
          \(SpecificPartGen.hash(kind))
        }

      }

      \(isNotInt32 ? """
      public conformance UInt: Comparable {

        public fun infix< (_ other: Self) -> Bool {
          Bool(value: Builtin.icmp_ult_\(representationType)(value, other.value))
        }

        public fun infix<= (_ other: Self) -> Bool {
          Bool(value: Builtin.icmp_ule_\(representationType)(value, other.value))
        }

        public fun infix> (_ other: Self) -> Bool {
          Bool(value: Builtin.icmp_ugt_\(representationType)(value, other.value))
        }

        public fun infix>= (_ other: Self) -> Bool {
          Bool(value: Builtin.icmp_uge_\(representationType)(value, other.value))
        }

      }
      
      public conformance UInt: AdditiveArithmetic {

        public fun infix+ (_ other: Self) -> Self {
          \(type)(value: Builtin.add_\(representationType)(value, other.value))
        }

        public fun infix+= (_ other: Self) inout {
          &self.value = Builtin.add_\(representationType)(value, other.value)
        }

        public fun infix- (_ other: Self) -> Self {
          \(type)(value: Builtin.sub_\(representationType)(value, other.value))
        }

        public fun infix-= (_ other: Self) inout {
          &self.value = Builtin.sub_\(representationType)(value, other.value)
        }

        public static fun zero() -> Self {
          \(["Int8", "UInt8"].contains(type) ? "0" : "type()")
        }

      }

      public conformance \(type): Numeric {

        public typealias Magnitude = \(type)

        public fun magnitude() -> \(type) {
          self.copy()
        }

        public fun infix* (_ other: Self) -> Self {
          \(type)(value: Builtin.mul_\(representationType)(value, other.value))
        }

        public fun infix*= (_ other: Self) inout {
          &self.value = Builtin.mul_\(representationType)(value, other.value)
        }

      }
      """ : "")

      \(family == .signed ? """
      public conformance \(type): SignedNumeric {

        public fun prefix- () -> Self {
          Int() - self
        }

        public fun negate() inout {
          &self = -self
        }

      }
      """ : "")

      \(isNotInt32 ? """
      public conformance \(type): BinaryInteger {

        public init() {
          &self.value = Builtin.zeroinitializer_\(representationType)()
        }

        public init<T: BinaryInteger>(truncating_or_extending source: T) {
          let w = source.words()
          &self.value = w[w.start_position()].value
        }

        public fun instance_bit_width() -> \(type) {
          Self.bit_width()
        }

        public fun signum() -> \(type) {
          let positive = \(type)(value: Builtin.zext_i1_word((self > 0).value))
          return positive | (self &>> (Self.bit_width() - 1))
        }

        public fun trailing_zeros() -> \(type) {
          \(type)(value: Builtin.cttz_word(value))
        }

        public fun quotient_and_remainder(dividing_by other: Self) -> {quotient: Self, remainder: Self} {
          (quotient: self / other, remainder: self % other)
        }

        public fun words() -> CollectionOfOne<UInt> {
          CollectionOfOne(UInt(bit_pattern: self))
        }

        public fun infix/ (_ other: Self) -> Self {
          \(type)(value: Builtin.sdiv_\(representationType)(value, other.value))
        }

        public fun infix/= (_ other: Self) inout {
          &self.value = Builtin.sdiv_\(representationType)(value, other.value)
        }

        public fun infix% (_ other: Self) -> Self {
          \(type)(value: Builtin.srem_\(representationType)(value, other.value))
        }

        public fun infix%= (_ other: Self) inout {
          &self.value = Builtin.srem_\(representationType)(value, other.value)
        }

        public fun infix& (_ other: Self) -> Self {
          \(type)(value: Builtin.and_\(representationType)(value, other.value))
        }

        public fun infix&= (_ other: Self) inout {
          &self.value = Builtin.and_\(representationType)(value, other.value)
        }

        public fun infix| (_ other: Self) -> Self {
          \(type)(value: Builtin.or_\(representationType)(value, other.value))
        }

        public fun infix|= (_ other: Self) inout {
          &self.value = Builtin.or_\(representationType)(value, other.value)
        }

        public fun infix^ (_ other: Self) -> Self {
          \(type)(value: Builtin.xor_\(representationType)(value, other.value))
        }

        public fun infix^= (_ other: Self) inout {
          &self.value = Builtin.xor_\(representationType)(value, other.value)
        }

        public fun infix<< (_ n: \(type)) -> Self {
          \(type)(value: Builtin.shl_\(representationType)(value, n.value))
        }

        public fun infix<<= (_ n: \(type) inout {
          &self.value = Builtin.shl_\(representationType)(value, n.value)
        }

        public fun infix>> (_ n: \(type)) -> Self {
          \(type)(value: Builtin.ashr_\(representationType)(value, n.value))
        }

        public fun infix>>= (_ n: \(type)) inout {
          &self.value = Builtin.ashr_\(representationType)(value, n.value)
        }

        public static fun is_signed() -> Bool {
          \(family == .signed ? "true" : "false")
        }

      }
      """ : "")
      """

    return baseIntTemplate
  }

  /// Generates the file content for the specific integer Hylo type
  /// - Parameter kind: `IntKind`
  /// - Returns: A `String`` representing the Hylo `kind` implementation
  public func specificInt(kind: IntKind) -> String {
    var filledTemplate: String

    switch kind {
    case .int:
      filledTemplate = templateFormatter(
        family: .signed, kind: .int, representationType: "word")
    case .int8:
      filledTemplate = templateFormatter(family: .signed, kind: .int8, representationType: "i8")
    case .int32:
      filledTemplate = templateFormatter(
        family: .signed, kind: .int32, representationType: "i32")
    case .uint:
      filledTemplate = templateFormatter(
        family: .unsigned, kind: .uint, representationType: "word")
    case .uint8:
      filledTemplate = templateFormatter(
        family: .unsigned, kind: .uint8, representationType: "i8")
    }

    return filledTemplate
  }

  private func genIntKindSet(predicate: (IntKind) -> Bool) -> [String: String] {
    var storage = [String: String]()
    for kind in IntKind.allCases.filter(predicate) {
      storage[kind.rawValue] = self.specificInt(kind: kind)
    }
    return storage
  }

  /// Generates the file content for unsigned integer Hylo types
  /// - Parameter intFamily: An `enum` to select which group of integer to generate
  /// - Parameter persist: A `Bool` flag to choice if to write instantly
  /// - Returns: A `Dictionary<String, String>` representing the Hylo implementation for each `IntKind` case
  public func build(intFamily: IntFamily = .all, persist: Bool = false) throws -> [String: String]?
  {
    let storage: [String: String]

    switch intFamily {
    case .all:
      storage = genIntKindSet { kind in true }
    case .signed:
      storage = genIntKindSet { [.uint, .uint8].contains($0) }
    case .unsigned:
      storage = genIntKindSet { [.int, .int8, .int32].contains($0) }
    }

    // Optimization: writing on filesystem consume the storage cache.
    if persist {
      try write(storage)
      return nil
    }
    return storage
  }

  /// Write all content generated for integer types to filesystem.
  /// This i suseful when you want work on generated data, and write
  /// the content of filesystme only in a second moment.
  /// - Parameter storage: `Dictionary<String, String>` representing the content generated
  private func write(_ storage: consuming [String: String])
    throws
  {
    for entry in storage {
      try entry.key.write(to: URL(string: pathToWrite)!, atomically: true, encoding: .utf8)
    }
  }

}
