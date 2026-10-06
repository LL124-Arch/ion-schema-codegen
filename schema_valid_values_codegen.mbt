///|
fn has_valid_values(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.valid_values is Some(_) {
      return true
    }
  }
  false
}

///|
fn write_valid_values_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_valid_values_equal(\n  left : @ion_model.IonValue,\n  right : @ion_model.IonValue,\n) -> Bool {\n  let left = left.without_annotations()\n  let right = right.without_annotations()\n  match (left, right) {\n    (@ion_model.IonValue::Float(left), @ion_model.IonValue::Float(right)) =>\n      left == right || (left.is_nan() && right.is_nan())\n    _ => left.equal(right)\n  }\n}\n",
  )
}

///|
fn write_named_valid_values(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let name = moonbit_type_identifier(named_type.name)
  let values = match named_type.valid_values {
    Some(values) => values
    None => return
  }
  let encoded = @ion.encode_text(values[:]) catch {
    _ =>
      raise SchemaError::UnsupportedFeature(
        "valid_values for type {named_type.name} cannot be encoded",
      )
  }
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) =>
      raise SchemaError::UnsupportedFeature(
        "valid_values is only supported on scalar types at type {named_type.name}",
      )
  }
  let expected_type = expected_ion_type(type_ref, types)
  output.write_string(
    "///|\n/// Test whether an Ion value is in the valid_values set for ",
  )
  output.write_string(name)
  output.write_string(".\npub fn is_valid_values_")
  output.write_string(name)
  output.write_string(
    "(value : @ion_model.IonValue) -> Bool {\n  let allowed_values = @ion.parse_text(\"",
  )
  output.write_string(moonbit_string_literal(encoded))
  output.write_string(
    "\") catch {\n    _ => []\n  }\n  for candidate in allowed_values {\n    if ion_schema_codegen_valid_values_equal(value, candidate) {\n      return true\n    }\n  }\n  false\n}\n\n",
  )
  output.write_string(
    "///|\n/// Validate the Ion type and valid_values set for ",
  )
  output.write_string(name)
  output.write_string(".\npub fn validate_")
  output.write_string(name)
  output.write_string(
    "(value : @ion_model.IonValue) -> Unit raise ConversionError {\n  if !ion_schema_codegen_matches_type(value, \"",
  )
  output.write_string(moonbit_string_literal(expected_type))
  output.write_string(
    "\") {\n    raise ConversionError::TypeMismatch(\n      path=\"",
  )
  output.write_string(moonbit_string_literal(named_type.name))
  output.write_string("\",\n      expected=\"")
  output.write_string(moonbit_string_literal(expected_type))
  output.write_string(
    "\",\n      actual=ion_schema_codegen_actual_type(value),\n    )\n  }\n  if !is_valid_values_",
  )
  output.write_string(name)
  output.write_string(
    "(value) {\n    raise ConversionError::InvalidValue(\n      path=\"",
  )
  output.write_string(moonbit_string_literal(named_type.name))
  output.write_string(
    "\",\n      constraint=\"valid_values\",\n      actual=ion_schema_codegen_actual_type(value),\n    )\n  }\n",
  )
  write_reference_valid_values_checks(
    output,
    type_ref,
    types,
    "value",
    "\"" + moonbit_string_literal(named_type.name) + "\"",
    "  ",
  )
  output.write_string("}\n")
}

///|
fn write_reference_valid_values_checks(
  output : StringBuilder,
  type_ref : TypeRef,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  match type_ref {
    TypeRef::Named(name) =>
      write_named_valid_values_checks(
        output,
        name,
        types,
        value_expression,
        path_expression,
        indent,
        types.length(),
      )
    TypeRef::NullOrNamed(name) => {
      output.write_string(
        indent +
        "if !ion_schema_codegen_matches_type(" +
        value_expression +
        ", \"$null\") {\n",
      )
      write_named_valid_values_checks(
        output,
        name,
        types,
        value_expression,
        path_expression,
        indent + "  ",
        types.length(),
      )
      output.write_string(indent + "}\n")
    }
    TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
  }
}

///|
fn write_named_valid_values_checks(
  output : StringBuilder,
  name : String,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
  remaining : Int,
) -> Unit raise SchemaError {
  if remaining <= 0 {
    return
  }
  match find_named_type(types, name) {
    Some(named_type) => {
      if named_type.valid_values is Some(_) {
        let generated_name = moonbit_type_identifier(named_type.name)
        output.write_string(
          indent +
          "if !is_valid_values_" +
          generated_name +
          "(" +
          value_expression +
          ") {\n" +
          indent +
          "  raise ConversionError::InvalidValue(\n" +
          indent +
          "    path=" +
          path_expression +
          ",\n" +
          indent +
          "    constraint=\"valid_values\",\n" +
          indent +
          "    actual=ion_schema_codegen_actual_type(" +
          value_expression +
          "),\n" +
          indent +
          "  )\n" +
          indent +
          "}\n",
        )
      }
      match named_type.body {
        TypeBody::Alias(TypeRef::Named(next)) =>
          write_named_valid_values_checks(
            output,
            next,
            types,
            value_expression,
            path_expression,
            indent,
            remaining - 1,
          )
        _ => ()
      }
    }
    None => ()
  }
}

///|
fn reference_has_valid_values(
  type_ref : TypeRef,
  types : Array[NamedType],
) -> Bool {
  match type_ref {
    TypeRef::Named(name) =>
      named_type_has_valid_values(name, types, types.length())
    TypeRef::NullOrNamed(name) =>
      named_type_has_valid_values(name, types, types.length())
    TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => false
  }
}

///|
fn named_type_has_valid_values(
  name : String,
  types : Array[NamedType],
  remaining : Int,
) -> Bool {
  if remaining <= 0 {
    return false
  }
  match find_named_type(types, name) {
    Some(named_type) =>
      if named_type.valid_values is Some(_) {
        true
      } else {
        match named_type.body {
          TypeBody::Alias(TypeRef::Named(next)) =>
            named_type_has_valid_values(next, types, remaining - 1)
          _ => false
        }
      }
    None => false
  }
}

///|
fn moonbit_string_literal(value : String) -> String {
  let output = StringBuilder()
  for char in value {
    match char {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      _ => output.write_char(char)
    }
  }
  output.to_string()
}
