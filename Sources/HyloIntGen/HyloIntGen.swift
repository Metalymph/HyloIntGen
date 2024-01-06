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

  /// Generates the file content for the specific integer Hylo type
  /// - Parameter kind: `IntKind`
  /// - Returns: A `String`` representing the Hylo `kind` implementation
  public func specificInt(kind: IntKind) -> String {
    var filledTemplate: TemplateFormatter

    switch kind {
    case .int:
      filledTemplate = TemplateFormatter(
        family: .signed, kind: .int, representationType: "word")
    case .int8:
      filledTemplate = TemplateFormatter(family: .signed, kind: .int8, representationType: "i8")
    case .int32:
      filledTemplate = TemplateFormatter(
        family: .signed, kind: .int32, representationType: "i32")
    case .uint:
      filledTemplate = TemplateFormatter(
        family: .unsigned, kind: .uint, representationType: "word")
    case .uint8:
      filledTemplate = TemplateFormatter(
        family: .unsigned, kind: .uint8, representationType: "i8")
    }

    return filledTemplate.build()
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
