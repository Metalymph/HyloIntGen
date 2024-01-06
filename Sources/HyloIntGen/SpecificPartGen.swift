public struct TemplateFormatter {
  let family: IntFamily
  let kind: IntKind
  let representationType: String
  let type: String
  let isNotInt32: Bool

  var components = [String]()

  init(family: IntFamily, kind: IntKind, representationType: String) {
    self.family = family
    self.kind = kind
    self.representationType = representationType
    type = kind.rawValue
    isNotInt32 = kind != .int32
  }

  mutating func build() -> String {
    components.append(mainDecl())

    if isNotInt32 {
      components.append(mainInit())
    } else {
      components.append(int32ZeroInit())
    }

    if kind == .int || kind == .uint {
      components.append(initFromAddress())
    }

    if kind == .int8 || kind == .int32 {
      components.append(initCopy())
    }

    if family == .signed {
      components.append(abs())
      if kind == .int {
        components.append(roundUp())
      }
      components.append(prefixPlus())
    }

    if isNotInt32 {
      components.append(prefixTilde())
    }

    if kind == .int {
      components.append(overflow())
    }

    components.append("}")
    components.append(commonComformances())

    if isNotInt32 {
      components.append("\npublic conformance \(type): Regular {}")
    }

    components.append(hash())

    if isNotInt32 {
      components.append(comparable())
      components.append(addictiveArithmetic())
      components.append(numeric())
    }

    if family == .signed {
      components.append(signedNumeric())
    }

    if isNotInt32 {
      components.append(binaryInteger())
      components.append(fixedWidthInteger())
    }

    if kind == .int {
      components.append(foreignConvertible())
    }

    return components.joined(separator: "\n\n")
  }

  func mainDecl() -> String {
    """
    /// A \(family.rawValue) integer value.
    public type \(type) {

      var value: Builtin.\(isNotInt32 ? representationType : "i32")

      memberwise init
    """
  }

  func mainInit() -> String {
    """
    /// Creates an instance with the same memory representation as `other`.
    public init(bit_pattern other: \(bitPattern())) {
      &self.value = other.value
    }
    """
  }

  func int32ZeroInit() -> String {
    """
    /// Creates an instance with value `0`.
    public init() {
      &self.value = Builtin.zeroinitializer_i32()
    }
    """
  }

  func initFromAddress() -> String {
    """
    /// Creates an instance with the same memory representation as `address`.
    public init(bit_pattern address: \(kind == .int ? "PointerToMutable<Never>" : "MemoryAddress")) {
      &self.value = Builtin.ptrtoint_word(address.base)
    }
    """
  }

  func initCopy() -> String {
    """
    /// Creates a copy of `other`.
    ///
    /// - Requires: The value of `other` must be representable in this type.
    public init(_ other: Int) {
      &self.value = Builtin.trunc_word_\(type)(other.value)
    }
    """
  }

  private func bitPattern() -> String {
    switch kind {
    case .int, .int8:
      return "U\(kind.rawValue)"
    case .uint, .uint8:
      let startIndex = kind.rawValue.firstIndex(of: "I")!
      return String(kind.rawValue[startIndex...])
    default:
      return ""
    }
  }

  func abs() -> String {
    """
    /// Returns the absolute value of `self`.
    public fun abs() -> \(type) {
      if self < 0 { -self } else { +self }
    }
    """
  }

  func roundUp() -> String {
    """
    /// Returns `self` rounded up to the nearest multiple of `stride`.
    public fun round_up(nearest_multiple_of stride: Int) -> Int {
      if stride == 0 {
        return self.copy()
      }

      let r = abs() % stride
      if r == 0 {
        return self.copy()
      } else if r < 0 {
        return -(abs() - r)
      }

      return self + stride - r
    }
    """
  }

  func prefixPlus() -> String {
    """
    /// Returns `self`.
    public fun prefix+ () -> Self {
      self.copy()
    }
    """
  }

  func prefixTilde() -> String {
    """
    /// Returns the bitwise inverse of `self`.
    public fun prefix~ () -> Self {
      self ^ -1
    }
    """
  }

  func overflow() -> String {
    """
    /// Returns the product of `self` and `other, wrapping the result in case of any overflow.
    public fun infix &* (_ other: Self) -> Self {
      self.multiplied_reporting_overflow(by: other).0
    }
    """
  }

  func commonComformances() -> String {
    return """
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
      """
  }

  func hash() -> String {
    var innerHashPart: String

    switch kind {
    case .int, .uint:
      innerHashPart = """
        // TODO: use conditional compilation to avoid branches
        &hasher.unsafe_combine(bytes: pointer_to_bytes[of: self])
        """
    case .uint8:
      innerHashPart = "&hasher.combine(byte: Int8(bit_pattern: self))"
    case .int8:
      innerHashPart = "&hasher.combine(byte: self)"
    case .int32:
      innerHashPart = """
        let p = Pointer<Int8>(type_punning: pointer[to: self])
        &hasher.combine(byte: p.unsafe[])
        &hasher.combine(byte: p.advance(by: 1).unsafe[])
        &hasher.combine(byte: p.advance(by: 2).unsafe[])
        &hasher.combine(byte: p.advance(by: 3).unsafe[])
        """
    }

    return """
      public conformance \(type): Hashable {

        public fun hash(into hasher: inout Hasher) {
          \(innerHashPart)
        }

      }
      """
  }

  func comparable() -> String {
    """
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
    """
  }

  func addictiveArithmetic() -> String {
    """
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
        \(["Int8", "UInt8"].contains(type) ? "0" : "\(type)()")
        }

    }
    """
  }

  func numeric() -> String {
    """
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
    """
  }

  func signedNumeric() -> String {
    """
    public conformance \(type): SignedNumeric {

        public fun prefix- () -> Self {
        Int() - self
        }

        public fun negate() inout {
        &self = -self
        }

    }
    """
  }

  func binaryInteger() -> String {
    let signum = {
      switch kind {
      case .int:
        return """
          let positive = Int(value: Builtin.zext_i1_word((self > 0).value))
          return positive | (self &>> (Self.bit_width() - 1))
          """
      case .int8: return "(if self > 0 { 1 } else { 0 }) - (if self < 0 { 1 } else { 0 })"
      case .uint: return "Int(value: Builtin.zext_i1_word((self > UInt()).value))"
      case .uint8: return "Int(value: Builtin.zext_i1_word((self > 0).value))"
      default: return ""
      }
    }

    let is8Bit = [.int8, .uint8].contains(kind)

    return """
      public conformance \(type): BinaryInteger {

        public init() {
          &self.value = Builtin.zeroinitializer_\(representationType)()
        }

        public init<T: BinaryInteger>(truncating_or_extending source: T) {
          let w = source.words()
          \(is8Bit ? 
        "&self.value = Builtin.trunc_word_i8(w[w.start_position()].value)" : 
        "&self.value = w[w.start_position()].value")
        }

        public fun instance_bit_width() -> \(type) {
          \(is8Bit ? "8" : "Self.bit_width()")
        }

        public fun signum() -> \(type) {
          \(signum())
        }

        public fun trailing_zeros() -> \(type) {
          \(is8Bit ? "Int(value: Builtin.zext_i8_word(Builtin.cttz_i8(value)))" :
           "Int(value: Builtin.cttz_word(value)))")
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
      """
  }

  func fixedWidthInteger() -> String {
    """
    public conformance \(type): FixedWidthInteger {

      public fun matches(_ mask: Self) -> Bool {
        (self & mask) == mask
      }

      public fun adding_reporting_overflow(_ other: Self) -> {partial_value: Self, overflow: Bool} {
        let r = Builtin.uadd_with_overflow_\(representationType)(value, other.value)
        return (partial_value: UInt(value: r.0), overflow: Bool(value: r.1))
      }

      public fun subtracting_reporting_overflow(
          _ other: Self
      ) -> {partial_value: Self, overflow: Bool} {
        let r = Builtin.usub_with_overflow_word(value, other.value)
        return (partial_value: UInt(value: r.0), overflow: Bool(value: r.1))
      }

      public fun multiplied_reporting_overflow(
          by other: Self
      ) -> {partial_value: Self, overflow: Bool} {
        let r = Builtin.umul_with_overflow_word(value, other.value)
        return (partial_value: UInt(value: r.0), overflow: Bool(value: r.1))
      }

      public fun divided_reporting_overflow(by other: Self) -> {partial_value: Self, overflow: Bool} {
        if other == UInt() {
          (partial_value: self.copy(), overflow: true)
        } else {
          (partial_value: UInt(value: Builtin.udiv_word(value, other.value)), overflow: false)
        }
      }

      public fun remainder_reporting_overflow(
          dividing_by other: Self
      ) -> {partial_value: Self, overflow: Bool} {
        if other == UInt() {
          (partial_value: self.copy(), overflow: true)
        } else {
          (partial_value: UInt(value: Builtin.urem_word(value, other.value)), overflow: false)
        }
      }

      public fun nonzero_bit_count() -> Int {
        Int(value: Builtin.ctpop_\(representationType)(value))
      }

      public fun leading_zeros() -> Int {
        Int(value: Builtin.ctlz_\(representationType)(value))
      }

      public fun infix&<< (_ n: Int) -> Self {
        UInt(value: Builtin.shl_\(representationType)(value, n.value))
      }

      public fun infix&<<= (_ n: Int) inout {
        &self.value = Builtin.shl_\(representationType)(value, n.value)
      }

      public fun infix&>> (_ n: Int) -> Self {
        UInt(value: Builtin.lshr_\(representationType)(value, n.value))
      }

      public fun infix&>>= (_ n: Int) inout {
        &self.value = Builtin.lshr_\(representationType)(value, n.value)
      }

      public static fun bit_width() -> Int {
        MemoryLayout<Builtin.\(representationType)>.size() * 8
      }

      public static fun max() -> Self {
        ~UInt()
      }

      public static fun min() -> Self {
        0
      }

    }
    """
  }

  func foreignConvertible() -> String {
    """
    public conformance Int: ForeignConvertible {

      public typealias ForeignRepresentation = Builtin.word

      public init(foreign_value: sink Builtin.word) {
        &self.value = foreign_value
      }

      public fun foreign_value() -> Builtin.word {
        value
      }

    }
    """
  }

}
