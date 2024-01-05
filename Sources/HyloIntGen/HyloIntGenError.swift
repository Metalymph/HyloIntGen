/// Error definition for the common operation required
public enum HyloIntGenError: Error {
  case EncodingData(for: String)
  case FileReading(path: String)
  case FileWriting(path: String)
}