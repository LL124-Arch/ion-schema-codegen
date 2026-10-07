///|
fn has_timestamp_precision_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.timestamp_precision_ranges.length() > 0 {
      return true
    }
  }
  false
}

///|
fn write_timestamp_precision_helper(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_timestamp_precision(\n  value : @ion_model.IonValue,\n) -> Int? {\n  if value.is_null() {\n    return None\n  }\n  match value.without_annotations() {\n    @ion_model.IonValue::Timestamp(timestamp) => {\n      if timestamp.year() <= 0 {\n        return None\n      }\n      if timestamp.second() is Some(_) {\n        match (timestamp.fraction_exponent(), timestamp.fraction_coefficient()) {\n          (Some(exponent), Some(_)) if exponent < 0 => Some(12 - exponent)\n          (None, None) => Some(12)\n          _ => None\n        }\n      } else if timestamp.minute() is Some(_) {\n        Some(9)\n      } else if timestamp.day() is Some(_) {\n        Some(6)\n      } else if timestamp.month() is Some(_) {\n        Some(3)\n      } else {\n        Some(0)\n      }\n    }\n    _ => None\n  }\n}\n",
  )
}

///|
fn write_named_timestamp_precision_checks(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit {
  write_ion_value_integer_range_checks(
    output,
    named_type.timestamp_precision_ranges,
    value_expression,
    path_expression,
    "timestamp_precision",
    "ion_schema_codegen_timestamp_precision",
    indent,
  )
}

///|
fn write_named_timestamp_precision_validator(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  if named_type.timestamp_precision_ranges.length() == 0 {
    return
  }
  let generated_name = moonbit_type_identifier(named_type.name)
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  output.write_string("///|\n/// Validate timestamp_precision constraints for ")
  output.write_string(generated_name)
  output.write_string(
    ".\npub fn validate_timestamp_precision_" +
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
  write_named_timestamp_precision_checks(
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
