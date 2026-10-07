///|
fn has_distinct_element_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.element_distinct {
      return true
    }
  }
  false
}

///|
fn write_distinct_element_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_symbols_equal(\n  left : @ion_model.IonSymbol,\n  right : @ion_model.IonSymbol,\n) -> Bool {\n  match (left.text_value(), right.text_value()) {\n    (Some(left_text), Some(right_text)) => left_text == right_text\n    (None, None) => left.sid_value() == right.sid_value()\n    _ => false\n  }\n}\n\n///|\nfn ion_schema_codegen_annotations_equal(\n  left : Array[@ion_model.IonSymbol],\n  right : Array[@ion_model.IonSymbol],\n) -> Bool {\n  if left.length() != right.length() {\n    return false\n  }\n  for index in 0..<left.length() {\n    if !ion_schema_codegen_symbols_equal(left[index], right[index]) {\n      return false\n    }\n  }\n  true\n}\n\n///|\nfn ion_schema_codegen_values_equal(\n  left : @ion_model.IonValue,\n  right : @ion_model.IonValue,\n) -> Bool {\n  match (left, right) {\n    (@ion_model.IonValue::Annotated(left_annotations, left_value), @ion_model.IonValue::Annotated(right_annotations, right_value)) =>\n      ion_schema_codegen_annotations_equal(left_annotations, right_annotations) &&\n      ion_schema_codegen_values_equal(left_value, right_value)\n    (@ion_model.IonValue::Annotated(_, _), _) | (_, @ion_model.IonValue::Annotated(_, _)) => false\n    (@ion_model.IonValue::Null(left), @ion_model.IonValue::Null(right)) => left == right\n    (@ion_model.IonValue::Bool(left), @ion_model.IonValue::Bool(right)) => left == right\n    (@ion_model.IonValue::Int(left), @ion_model.IonValue::Int(right)) => left == right\n    (@ion_model.IonValue::Float(left), @ion_model.IonValue::Float(right)) =>\n      left == right || (left.is_nan() && right.is_nan())\n    (@ion_model.IonValue::Decimal(left), @ion_model.IonValue::Decimal(right)) =>\n      left.coefficient() == right.coefficient() && left.exponent() == right.exponent()\n    (@ion_model.IonValue::Timestamp(left), @ion_model.IonValue::Timestamp(right)) => left == right\n    (@ion_model.IonValue::Symbol(left), @ion_model.IonValue::Symbol(right)) =>\n      ion_schema_codegen_symbols_equal(left, right)\n    (@ion_model.IonValue::String(left), @ion_model.IonValue::String(right)) => left == right\n    (@ion_model.IonValue::Blob(left), @ion_model.IonValue::Blob(right)) => left == right\n    (@ion_model.IonValue::Clob(left), @ion_model.IonValue::Clob(right)) => left == right\n    (@ion_model.IonValue::List(left), @ion_model.IonValue::List(right)) |\n    (@ion_model.IonValue::Sexp(left), @ion_model.IonValue::Sexp(right)) =>\n      ion_schema_codegen_sequences_equal(left, right)\n    (@ion_model.IonValue::Struct(left), @ion_model.IonValue::Struct(right)) =>\n      ion_schema_codegen_structs_equal(left, right)\n    _ => false\n  }\n}\n\n///|\nfn ion_schema_codegen_sequences_equal(\n  left : Array[@ion_model.IonValue],\n  right : Array[@ion_model.IonValue],\n) -> Bool {\n  if left.length() != right.length() {\n    return false\n  }\n  for index in 0..<left.length() {\n    if !ion_schema_codegen_values_equal(left[index], right[index]) {\n      return false\n    }\n  }\n  true\n}\n\n///|\nfn ion_schema_codegen_structs_equal(\n  left : Array[(@ion_model.IonSymbol, @ion_model.IonValue)],\n  right : Array[(@ion_model.IonSymbol, @ion_model.IonValue)],\n) -> Bool {\n  if left.length() != right.length() {\n    return false\n  }\n  let matched : Array[Bool] = []\n  for _ in right {\n    matched.push(false)\n  }\n  for (left_symbol, left_value) in left {\n    let mut index = 0\n    let mut found = false\n    for (right_symbol, right_value) in right {\n      if !matched[index] &&\n        ion_schema_codegen_symbols_equal(left_symbol, right_symbol) &&\n        ion_schema_codegen_values_equal(left_value, right_value) {\n        matched[index] = true\n        found = true\n        break\n      }\n      index += 1\n    }\n    if !found {\n      return false\n    }\n  }\n  true\n}\n\n///|\nfn ion_schema_codegen_check_distinct(\n  values : Array[@ion_model.IonValue],\n  path : String,\n) -> Unit raise ConversionError {\n  let previous : Array[@ion_model.IonValue] = []\n  let mut index = 0\n  for value in values {\n    for prior in previous {\n      if ion_schema_codegen_values_equal(prior, value) {\n        raise ConversionError::InvalidValue(\n          path=path + \"[\" + index.to_string() + \"]\",\n          constraint=\"distinct::element\",\n          actual=ion_schema_codegen_actual_type(value),\n        )\n      }\n    }\n    previous.push(value)\n    index += 1\n  }\n}\n",
  )
}

///|
fn write_distinct_values_check(
  output : StringBuilder,
  values_expression : String,
  path_expression : String,
  indent : String,
) -> Unit {
  output.write_string(
    indent +
    "ion_schema_codegen_check_distinct(" +
    values_expression +
    ", " +
    path_expression +
    ")\n",
  )
}

///|
fn write_distinct_struct_check(
  output : StringBuilder,
  named_type : NamedType,
  fields_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  let values_name = "ion_schema_codegen_distinct_" +
    moonbit_type_identifier(named_type.name)
  output.write_string(
    indent +
    "let " +
    values_name +
    " : Array[@ion_model.IonValue] = []\n" +
    indent +
    "for (_, ion_schema_codegen_distinct_value) in " +
    fields_expression +
    " {\n" +
    indent +
    "  " +
    values_name +
    ".push(ion_schema_codegen_distinct_value)\n" +
    indent +
    "}\n",
  )
  write_distinct_values_check(output, values_name, path_expression, indent)
}
