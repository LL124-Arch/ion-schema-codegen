///|
test "relative imports resolve in their own schema scopes" {
  let original : @imports.ImportedExample = {
    shared: @bigint.BigInt::from_int(7),
    extra: "visible through the whole-schema import",
    envelope: { value: @bigint.BigInt::from_int(42), },
  }
  let encoded = @imports.ImportedExample::to_ion(original)
  let decoded = @imports.ImportedExample::from_ion(encoded)
  assert_eq(@imports.ImportedExample::to_ion(decoded), encoded)
}
