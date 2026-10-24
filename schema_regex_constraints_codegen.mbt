///|
fn has_regex_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.regex_constraints.length() > 0 {
      return true
    }
  }
  false
}

///|
fn write_regex_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_regex_matches(\n  value : @ion_model.IonValue,\n  pattern : String,\n) -> Bool {\n  if value.is_null() {\n    return false\n  }\n  let text = match value.without_annotations() {\n    @ion_model.IonValue::String(text) => Some(text)\n    @ion_model.IonValue::Symbol(symbol) => symbol.text_value()\n    _ => None\n  }\n  match text {\n    Some(text) => {\n      let regex = @string.Regex(pattern) catch {\n        _ => return false\n      }\n      regex.execute(text) is Some(_)\n    }\n    None => false\n  }\n}\n",
  )
}

///|
fn write_named_regex_checks(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit {
  for constraint in named_type.regex_constraints {
    output.write_string(
      indent +
      "if !ion_schema_codegen_regex_matches(" +
      value_expression +
      ", \"" +
      moonbit_string_literal(constraint.pattern) +
      "\") {\n" +
      indent +
      "  raise ConversionError::InvalidValue(\n" +
      indent +
      "    path=" +
      path_expression +
      ",\n" +
      indent +
      "    constraint=\"regex\",\n" +
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
}

///|
fn write_named_regex_validator(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  if named_type.regex_constraints.length() == 0 {
    return
  }
  let generated_name = moonbit_type_identifier(named_type.name)
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  output.write_string("///|\n/// Validate regex constraints for ")
  output.write_string(generated_name)
  output.write_string(
    ".\npub fn validate_regex_" +
    generated_name +
    "(value : @ion_model.IonValue) -> Unit raise ConversionError {\n",
  )
  write_type_validation_with_path_expression(
    output,
    type_ref,
    "value",
    types,
    "\"" + moonbit_string_literal(named_type.name) + "\"",
    "  ",
  )
  write_named_regex_checks(
    output,
    named_type,
    "value",
    "\"" + moonbit_string_literal(named_type.name) + "\"",
    "  ",
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
