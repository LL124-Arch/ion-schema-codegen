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
fn has_timestamp_offset_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.timestamp_offsets.length() > 0 {
      return true
    }
  }
  false
}

///|
fn has_ieee754_float_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.ieee754_float_formats.length() > 0 {
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
fn write_timestamp_offset_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_timestamp_offset_is_allowed(\n  value : @ion_model.IonValue,\n  allowed_offsets : Array[Int?],\n) -> Bool {\n  if value.is_null() {\n    return false\n  }\n  match value.without_annotations() {\n    @ion_model.IonValue::Timestamp(timestamp) =>\n      for offset in allowed_offsets {\n        if timestamp.offset_minutes() == offset {\n          return true\n        }\n      }\n    _ => ()\n  }\n  false\n}\n\n///|\nfn ion_schema_codegen_timestamp_offset_text(\n  value : @ion_model.IonValue,\n) -> String {\n  match value.without_annotations() {\n    @ion_model.IonValue::Timestamp(timestamp) => timestamp.offset_text()\n    _ => ion_schema_codegen_actual_type(value)\n  }\n}\n",
  )
}

///|
fn write_ieee754_float_helper(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_binary16_float_compatible(value : Float) -> Bool {\n  let bits = value.reinterpret_as_uint()\n  let exponent_bits = ((bits >> 23) & 0xFFU).reinterpret_as_int()\n  let fraction_bits = bits & 0x7FFFFFU\n  if exponent_bits == 0xFF {\n    true\n  } else if exponent_bits == 0 {\n    fraction_bits == 0U\n  } else {\n    let exponent = exponent_bits - 127\n    let significand = fraction_bits | 0x800000U\n    if exponent > 15 {\n      false\n    } else if exponent >= -14 {\n      (significand & 0x1FFFU) == 0U\n    } else if exponent < -24 {\n      false\n    } else {\n      let discarded_bits = -exponent - 1\n      let mask = (1U << discarded_bits) - 1U\n      (significand & mask) == 0U\n    }\n  }\n}\n\n///|\nfn ion_schema_codegen_ieee754_float_compatible(\n  value : @ion_model.IonValue,\n  format : String,\n) -> Bool {\n  if value.is_null() {\n    return false\n  }\n  match value.without_annotations() {\n    @ion_model.IonValue::Float(float) =>\n      match format {\n        \"binary16\" => ion_schema_codegen_binary16_float_compatible(float)\n        \"binary32\" | \"binary64\" => true\n        _ => false\n      }\n    _ => false\n  }\n}\n",
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
fn write_named_timestamp_offset_checks(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let mut index = 0
  for allowed_offsets in named_type.timestamp_offsets {
    let allowed_name = "ion_schema_codegen_allowed_offsets_" +
      generated_name +
      "_" +
      index.to_string()
    index += 1
    output.write_string(indent + "let " + allowed_name + " : Array[Int?] = [")
    let mut first = true
    for offset in allowed_offsets {
      if !first {
        output.write_string(", ")
      }
      first = false
      match offset {
        Some(minutes) =>
          output.write_string("Some(" + minutes.to_string() + ")")
        None => output.write_string("None")
      }
    }
    output.write_string("]\n")
    output.write_string(
      indent +
      "if !ion_schema_codegen_timestamp_offset_is_allowed(" +
      value_expression +
      ", " +
      allowed_name +
      ") {\n" +
      indent +
      "  raise ConversionError::InvalidValue(\n" +
      indent +
      "    path=" +
      path_expression +
      ",\n" +
      indent +
      "    constraint=\"timestamp_offset\",\n" +
      indent +
      "    actual=ion_schema_codegen_timestamp_offset_text(" +
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
fn write_named_ieee754_float_checks(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit {
  for format in named_type.ieee754_float_formats {
    output.write_string(
      indent +
      "if !ion_schema_codegen_ieee754_float_compatible(" +
      value_expression +
      ", \"" +
      moonbit_string_literal(format) +
      "\") {\n" +
      indent +
      "  raise ConversionError::InvalidValue(\n" +
      indent +
      "    path=" +
      path_expression +
      ",\n" +
      indent +
      "    constraint=\"ieee754_float\",\n" +
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

///|
fn write_named_timestamp_offset_validator(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  if named_type.timestamp_offsets.length() == 0 {
    return
  }
  let generated_name = moonbit_type_identifier(named_type.name)
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  output.write_string("///|\n/// Validate timestamp_offset constraints for ")
  output.write_string(generated_name)
  output.write_string(
    ".\npub fn validate_timestamp_offset_" +
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
  write_named_timestamp_offset_checks(
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

///|
fn write_named_ieee754_float_validator(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  if named_type.ieee754_float_formats.length() == 0 {
    return
  }
  let generated_name = moonbit_type_identifier(named_type.name)
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  output.write_string("///|\n/// Validate ieee754_float constraints for ")
  output.write_string(generated_name)
  output.write_string(
    ".\npub fn validate_ieee754_float_" +
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
  write_named_ieee754_float_checks(
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
