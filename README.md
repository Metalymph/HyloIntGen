## HyloIntGen

Generator for Hylo programming language integer types.

#### Example

```swift
import HyloIntGen

// Generate the integer familly you want as Dictionary<String: String>
let contentDict = HyloIntGen()
let allIntTypesDict = contentDict.all()
let onlySignedInts = contentDict().signed()
let onlyUnsignedInts = contentDict().unsigned()

//  iter over generated content which represent tthe several integer types
for entry in allIntTypesDict {
    print("Type: \(entry.key) - File string content:\n\n \(entry.value)\n")
}

// write the content generated to a file for each Hylo integer type
do { 
    try contentDict.write() {
} catch {
    print(error.localizedDescription)
}

```