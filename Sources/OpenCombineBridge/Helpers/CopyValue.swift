import Foundation

func copyValue<Source, Destination>(of source: Source, as destination: Destination) -> Destination {
  var value = source
  var buffer = destination
  let data = Data(bytes: &value, count: MemoryLayout<Source>.size)
  _ = withUnsafeMutableBytes(of: &buffer, { data.copyBytes(to: $0) })
  return buffer
}
