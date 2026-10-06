///|
test "Ion codec dependency parses schema-shaped input" {
  let values = @ion.parse_text("type::{name: Person, type: struct}")
  assert_eq(values.length(), 1)
}

///|
test "Ion codec preserves multiple top-level document values" {
  let values = @ion.parse_text("1 foo::null.int {nested: [2, 3]}")
  let encoded = @ion.encode_text(values)
  assert_eq(@ion.parse_text(encoded), values)
}
