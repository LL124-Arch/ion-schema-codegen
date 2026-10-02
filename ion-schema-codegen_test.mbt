///|
test "Ion codec dependency parses schema-shaped input" {
  let values = @ion.parse_text("type::{name: Person, type: struct}")
  assert_eq(values.length(), 1)
}
