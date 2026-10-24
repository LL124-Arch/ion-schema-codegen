///|
// Keep the first declaration for the public MoonBit representation. Further
// declarations are independent predicates over the original Ion value, never
// merged by overwriting fields or concatenating value sets.
fn separate_repeated_constraints(
  value : @model.IonValue,
) -> (@model.IonValue, Array[(String, @model.IonValue)]) {
  let seen : Array[String] = []
  let fields : Array[(@model.IonSymbol, @model.IonValue)] = []
  let repeated : Array[(String, @model.IonValue)] = []
  for (symbol, item) in value.fields() {
    let name = symbol.text_value().unwrap_or("")
    if [
        "type", "fields", "element", "field_names", "ordered_elements", "valid_values",
      ].contains(name) {
      if seen.contains(name) {
        repeated.push((name, item))
        continue
      }
      seen.push(name)
    }
    fields.push((symbol, item))
  }
  (
    @model.IonValue::Struct(fields).with_annotations(value.annotations()),
    repeated,
  )
}

///|
fn parse_repeated_constraint(
  keyword : String,
  argument : @model.IonValue,
  base_name : String,
  types : Array[NamedType],
  context : String,
) -> TypeRef raise SchemaError {
  if keyword == "type" && base_name != "document" {
    return parse_logical_type_argument(
      argument,
      "repeated type at " + context,
      types,
    )
  }
  let branch_name = "ion_schema_codegen_internal_inline_" +
    types.length().to_string()
  let base = if keyword == "fields" || keyword == "field_names" {
    "struct"
  } else {
    base_name
  }
  let fields : Array[(@model.IonSymbol, @model.IonValue)] = [
    (
      @model.IonSymbol::from_text("name"),
      @model.IonValue::Symbol(@model.IonSymbol::from_text(branch_name)),
    ),
  ]
  if keyword == "type" {
    fields.push((@model.IonSymbol::from_text("type"), argument))
  } else {
    fields.push(
      (
        @model.IonSymbol::from_text("type"),
        @model.IonValue::Symbol(@model.IonSymbol::from_text(base)),
      ),
    )
    fields.push((@model.IonSymbol::from_text(keyword), argument))
  }
  let branch_value = @model.IonValue::Struct(fields).with_annotations([
    @model.IonSymbol::from_text("type"),
  ])
  let index = types.length()
  types.push(empty_inline_named_type(branch_name))
  let branch = parse_named_type(branch_value, types, true)
  types[index] = { ..branch, is_inline: true, }
  TypeRef::Named(branch_name)
}

///|
fn named_type_is_document(
  named_type : NamedType,
  types : Array[NamedType],
) -> Bool raise SchemaError {
  match named_type.body {
    TypeBody::Scalar(reference) | TypeBody::Alias(reference) =>
      is_document_reference(types, reference)
    _ => false
  }
}

///|
fn is_internal_document_conjunction(
  reference : TypeRef,
  types : Array[NamedType],
) -> Bool raise SchemaError {
  match reference {
    TypeRef::Named(name) if name.has_prefix(
        "ion_schema_codegen_internal_inline_",
      ) =>
      match find_named_type(types, name) {
        Some(branch) =>
          branch.is_inline && named_type_is_document(branch, types)
        None => false
      }
    _ => false
  }
}
