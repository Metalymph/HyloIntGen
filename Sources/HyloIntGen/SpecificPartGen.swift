internal struct SpecificPartGen {
    static func bitPattern(_ kind: IntKind) -> String {
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

    static func hash(_ kind: IntKind) -> String {
        switch kind {
        case .int, .uint:
            return """
            // TODO: use conditional compilation to avoid branches
            &hasher.unsafe_combine(bytes: pointer_to_bytes[of: self])
            """
        case .uint8:
            return "&hasher.combine(byte: Int8(bit_pattern: self))"
        case .int8:
            return "&hasher.combine(byte: self)"
        case .int32:
            return """
            let p = Pointer<Int8>(type_punning: pointer[to: self])
            &hasher.combine(byte: p.unsafe[])
            &hasher.combine(byte: p.advance(by: 1).unsafe[])
            &hasher.combine(byte: p.advance(by: 2).unsafe[])
            &hasher.combine(byte: p.advance(by: 3).unsafe[])
            """
        }
    }  
}