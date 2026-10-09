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

///|
test "type algebra can reference a directly imported type" {
  @imports.validate_type_NotShared(@ion_model.IonValue::String("ion"))
  let rejected = try {
    @imports.validate_type_NotShared(
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(7)),
    )
    false
  } catch {
    @imports.ConversionError::InvalidValue(constraint="not", ..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
}
