## HyloIntGen

Generator for Hylo programming language integer types.

#### Example

```swift
import HyloIntGen

public func main() {
  guard let gen = HyloIntGen(writeToPath: "${HYLO_PATH}/StandardLibrary/Sources/Core/Numbers/Integers/") else {
  print("Could not use \(writeToPath) as current path.")
return
}
//build content of all Hylo integer types (useful for debugging). No write on filesystem by default.
let allIntTypesDict = try! gen.build()!
//  iter over generated content which represent tthe several integer types
for entry in allIntTypesDict {
  print("Type: \(entry.key) - File string content:\n\n \(entry.value)\n")
}

//build content of all Hylo unsigned integer types writing on filesystem.
//Avoids data caching consuming it, so is useless to wait for an output value (nil)
do {
  _ = try gen.build(intFamily: .unsigned, persist = true)
catch {
  print(error.localizedDescription)
}

```