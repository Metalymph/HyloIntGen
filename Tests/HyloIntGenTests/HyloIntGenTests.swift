import XCTest

@testable import HyloIntGen

final class HyloIntGenTests: XCTestCase {
  func readIntTypeFile(path: String) async throws -> String {
    guard let data = Bundle.module.url(forResource: path, withExtension: nil) else {
      throw HyloIntGenError.FileReading(path: path)
    }

    return try String(contentsOf: data, encoding: .utf8)
  }

  func testSpecificInt() async throws {
    let cases = IntKind.allCases
    let randomIntKind = Int.random(in: 1...cases.count)
    print("Random case taken: \(cases[randomIntKind].rawValue)")
    let genData = HyloIntGen().specificInt(kind: cases[randomIntKind])
    let readFile = try await readIntTypeFile(path: "./Templates/\(cases[randomIntKind].rawValue).hylo")
    XCTAssertEqual(genData, readFile)
  }

  func testAll() async throws {
    for entry in HyloIntGen().all() {
      print("Testing \(entry.key)...")
      let readFile = try await readIntTypeFile(path: "./Templates/\(entry.key).hylo")
      XCTAssertEqual(entry.value, readFile)
    }
  }

  func testWrite() async throws {
    let generator = HyloIntGen()
    let genData = generator.all()
    
    try generator.write(path: "./Generated")
    for entry in genData {
        let oldIntTypeFile = try await readIntTypeFile(path: "./Templates/\(entry.key).hylo")
        let newIntTypeFile = try await readIntTypeFile(path: "./Generated/\(entry.key).hylo")
        XCTAssertEqual(oldIntTypeFile, newIntTypeFile)
    }
  }
}
