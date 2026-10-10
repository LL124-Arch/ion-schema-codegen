///|
fn recursion_field(
  name : String,
  value : @ion_model.IonValue,
) -> (@ion_model.IonSymbol, @ion_model.IonValue) {
  (@ion_model.IonSymbol::from_text(name), value)
}

///|
fn tree_value(
  label : String,
  children : Array[@ion_model.IonValue],
) -> @ion_model.IonValue {
  @ion_model.IonValue::Struct([
    recursion_field("value", @ion_model.IonValue::String(label)),
    recursion_field("children", @ion_model.IonValue::List(children)),
  ])
}

///|
test "recursive tree values convert to MoonBit and round trip" {
  let source = tree_value("root", [tree_value("leaf", [])])
  let tree = @recursion.TreeNode::from_ion(source)
  assert_eq(tree.value, "root")
  assert_eq(tree.children.length(), 1)
  assert_eq(tree.children[0].value, "leaf")
  assert_eq(tree.children[0].children.length(), 0)
  assert_eq(tree.to_ion(), source)
}
