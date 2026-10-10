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
fn linked_value(
  label : String,
  next : @ion_model.IonValue?,
) -> @ion_model.IonValue {
  let fields = [recursion_field("label", @ion_model.IonValue::String(label))]
  match next {
    Some(value) => fields.push(recursion_field("next", value))
    None => ()
  }
  @ion_model.IonValue::Struct(fields)
}

///|
fn nullable_node_value(next : @ion_model.IonValue?) -> @ion_model.IonValue {
  let fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  match next {
    Some(value) => fields.push(recursion_field("next", value))
    None => ()
  }
  @ion_model.IonValue::Struct(fields)
}

///|
fn branch_value(
  name : String,
  leaves : Array[@ion_model.IonValue],
) -> @ion_model.IonValue {
  @ion_model.IonValue::Struct([
    recursion_field("name", @ion_model.IonValue::String(name)),
    recursion_field("leaves", @ion_model.IonValue::List(leaves)),
  ])
}

///|
fn branch_leaf_value(
  name : String,
  parent : @ion_model.IonValue?,
) -> @ion_model.IonValue {
  let fields = [recursion_field("name", @ion_model.IonValue::String(name))]
  match parent {
    Some(value) => fields.push(recursion_field("parent", value))
    None => ()
  }
  @ion_model.IonValue::Struct(fields)
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

///|
test "optional and nullable recursive fields terminate finite values" {
  let source = linked_value("first", Some(linked_value("last", None)))
  let link = @recursion.LinkNode::from_ion(source)
  match link.next {
    Some(next) => {
      assert_eq(next.label, "last")
      match next.next {
        None => ()
        Some(_) => assert_true(false)
      }
    }
    None => assert_true(false)
  }
  assert_eq(link.to_ion(), source)

  let nested = nullable_node_value(
    Some(
      nullable_node_value(
        Some(@ion_model.IonValue::null(kind=@ion_model.IonNull::Null)),
      ),
    ),
  )
  let nullable_node = @recursion.NullableNode::from_ion(nested)
  assert_eq(nullable_node.to_ion(), nested)
}

///|
test "mutually recursive structs and lists convert finite nested values" {
  let source = branch_value("root", [
    branch_leaf_value("leaf", Some(branch_value("nested", []))),
  ])
  let branch = @recursion.Branch::from_ion(source)
  assert_eq(branch.name, "root")
  assert_eq(branch.leaves.length(), 1)
  match branch.leaves[0].parent {
    Some(parent) => {
      assert_eq(parent.name, "nested")
      assert_eq(parent.leaves.length(), 0)
    }
    None => assert_true(false)
  }
  assert_eq(branch.to_ion(), source)
}
