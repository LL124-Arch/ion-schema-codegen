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
fn write_valid_values_range_helpers(output : StringBuilder) -> Unit {
  write_range_membership_helpers(output)
  write_numeric_range_helpers(output)
  write_timestamp_range_helpers(output)
}

///|
fn write_range_membership_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_has_annotation(\n  value : @ion_model.IonValue,\n  expected : String,\n) -> Bool {\n  for annotation in value.annotations() {\n    if annotation.text_value() == Some(expected) {\n      return true\n    }\n  }\n  false\n}\n\n///|\nfn ion_schema_codegen_is_minimum(value : @ion_model.IonValue) -> Bool {\n  match value.without_annotations() {\n    @ion_model.IonValue::Symbol(symbol) => symbol.text_value() == Some(\"min\")\n    _ => false\n  }\n}\n\n///|\nfn ion_schema_codegen_is_maximum(value : @ion_model.IonValue) -> Bool {\n  match value.without_annotations() {\n    @ion_model.IonValue::Symbol(symbol) => symbol.text_value() == Some(\"max\")\n    _ => false\n  }\n}\n\n///|\nfn ion_schema_codegen_valid_values_match(\n  value : @ion_model.IonValue,\n  candidate : @ion_model.IonValue,\n) -> Bool {\n  if ion_schema_codegen_has_annotation(candidate, \"range\") {\n    ion_schema_codegen_range_contains(value, candidate)\n  } else {\n    ion_schema_codegen_valid_values_equal(value, candidate)\n  }\n}\n\n///|\nfn ion_schema_codegen_range_contains(\n  value : @ion_model.IonValue,\n  range : @ion_model.IonValue,\n) -> Bool {\n  if value.is_null() {\n    return false\n  }\n  match range.without_annotations() {\n    @ion_model.IonValue::List([minimum, maximum]) => {\n      let minimum_matches = if ion_schema_codegen_is_minimum(minimum) {\n        true\n      } else {\n        match ion_schema_codegen_compare_values(value, minimum) {\n          Some(order) =>\n            order > 0 ||\n            (order == 0 && !ion_schema_codegen_has_annotation(minimum, \"exclusive\"))\n          None => false\n        }\n      }\n      let maximum_matches = if ion_schema_codegen_is_maximum(maximum) {\n        true\n      } else {\n        match ion_schema_codegen_compare_values(value, maximum) {\n          Some(order) =>\n            order < 0 ||\n            (order == 0 && !ion_schema_codegen_has_annotation(maximum, \"exclusive\"))\n          None => false\n        }\n      }\n      minimum_matches && maximum_matches\n    }\n    _ => false\n  }\n}\n\n///|\nfn ion_schema_codegen_compare_values(\n  left : @ion_model.IonValue,\n  right : @ion_model.IonValue,\n) -> Int? {\n  match (ion_schema_codegen_number_parts(left), ion_schema_codegen_number_parts(right)) {\n    (Some((left_coefficient, left_exponent)), Some((right_coefficient, right_exponent))) =>\n      Some(ion_schema_codegen_compare_decimal_parts(\n        left_coefficient,\n        left_exponent,\n        right_coefficient,\n        right_exponent,\n      ))\n    _ =>\n      match (left.without_annotations(), right.without_annotations()) {\n        (@ion_model.IonValue::Timestamp(left), @ion_model.IonValue::Timestamp(right)) =>\n          Some(ion_schema_codegen_compare_timestamps(left, right))\n        _ => None\n      }\n  }\n}\n",
  )
}

///|
fn write_numeric_range_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_power(base : Int, exponent : Int) -> @bigint.BigInt {\n  @bigint.BigInt::pow(\n    @bigint.BigInt::from_int(base),\n    @bigint.BigInt::from_int(exponent),\n  )\n}\n\n///|\nfn ion_schema_codegen_number_parts(\n  value : @ion_model.IonValue,\n) -> (@bigint.BigInt, Int)? {\n  match value.without_annotations() {\n    @ion_model.IonValue::Int(value) => Some((value, 0))\n    @ion_model.IonValue::Decimal(value) =>\n      Some((value.coefficient(), value.exponent()))\n    @ion_model.IonValue::Float(value) => ion_schema_codegen_float_parts(value)\n    _ => None\n  }\n}\n\n///|\nfn ion_schema_codegen_float_parts(\n  value : Float,\n) -> (@bigint.BigInt, Int)? {\n  let bits = value.reinterpret_as_uint()\n  let exponent_bits = ((bits >> 23) & 0xFF).reinterpret_as_int()\n  let fraction_bits = (bits & 0x7FFFFF).reinterpret_as_int()\n  if exponent_bits == 0xFF {\n    return None\n  }\n  let significand = if exponent_bits == 0 {\n    fraction_bits\n  } else {\n    fraction_bits + 0x800000\n  }\n  let binary_exponent = if exponent_bits == 0 {\n    -149\n  } else {\n    exponent_bits - 127 - 23\n  }\n  let mut coefficient = @bigint.BigInt::from_int(significand)\n  let decimal_exponent = if binary_exponent >= 0 {\n    coefficient = coefficient * ion_schema_codegen_power(2, binary_exponent)\n    0\n  } else {\n    coefficient = coefficient * ion_schema_codegen_power(5, -binary_exponent)\n    binary_exponent\n  }\n  if (bits & 0x80000000) != 0 {\n    coefficient = coefficient.neg()\n  }\n  Some((coefficient, decimal_exponent))\n}\n\n///|\nfn ion_schema_codegen_compare_decimal_parts(\n  left_coefficient : @bigint.BigInt,\n  left_exponent : Int,\n  right_coefficient : @bigint.BigInt,\n  right_exponent : Int,\n) -> Int {\n  let left_sign = left_coefficient.compare_int(0)\n  let right_sign = right_coefficient.compare_int(0)\n  if left_sign != right_sign {\n    return if left_sign < right_sign { -1 } else { 1 }\n  }\n  if left_sign == 0 {\n    return 0\n  }\n  let left_order =\n    @bigint.BigInt::from_int(left_coefficient.to_string().length()) +\n    @bigint.BigInt::from_int(left_exponent)\n  let right_order =\n    @bigint.BigInt::from_int(right_coefficient.to_string().length()) +\n    @bigint.BigInt::from_int(right_exponent)\n  let order = left_order.compare(right_order)\n  if order != 0 {\n    return if left_sign < 0 { -order } else { order }\n  }\n  let common_exponent = if left_exponent < right_exponent {\n    left_exponent\n  } else {\n    right_exponent\n  }\n  let left_scaled = left_coefficient *\n    ion_schema_codegen_power(10, left_exponent - common_exponent)\n  let right_scaled = right_coefficient *\n    ion_schema_codegen_power(10, right_exponent - common_exponent)\n  left_scaled.compare(right_scaled)\n}\n",
  )
}

///|
fn write_timestamp_range_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_is_leap_year(year : Int) -> Bool {\n  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)\n}\n\n///|\nfn ion_schema_codegen_days_in_month(year : Int, month : Int) -> Int {\n  match month {\n    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31\n    4 | 6 | 9 | 11 => 30\n    2 => if ion_schema_codegen_is_leap_year(year) { 29 } else { 28 }\n    _ => 30\n  }\n}\n\n///|\nfn ion_schema_codegen_timestamp_seconds(\n  timestamp : @ion_model.IonTimestamp,\n) -> @bigint.BigInt {\n  let previous_year =\n    @bigint.BigInt::from_int(timestamp.year()) - @bigint.BigInt::from_int(1)\n  let mut days =\n    previous_year * @bigint.BigInt::from_int(365) +\n    previous_year / @bigint.BigInt::from_int(4) -\n    previous_year / @bigint.BigInt::from_int(100) +\n    previous_year / @bigint.BigInt::from_int(400)\n  let month = timestamp.month().unwrap_or(1)\n  for prior_month in 1..<month {\n    days = days + @bigint.BigInt::from_int(\n      ion_schema_codegen_days_in_month(timestamp.year(), prior_month),\n    )\n  }\n  if month > 2 && ion_schema_codegen_is_leap_year(timestamp.year()) {\n    days = days + @bigint.BigInt::from_int(1)\n  }\n  days = days + @bigint.BigInt::from_int(timestamp.day().unwrap_or(1) - 1)\n  let local_seconds =\n    timestamp.hour().unwrap_or(0) * 3600 +\n    timestamp.minute().unwrap_or(0) * 60 +\n    timestamp.second().unwrap_or(0)\n  days * @bigint.BigInt::from_int(86400) +\n  @bigint.BigInt::from_int(local_seconds) -\n  @bigint.BigInt::from_int(timestamp.offset_minutes().unwrap_or(0) * 60)\n}\n\n///|\nfn ion_schema_codegen_compare_timestamps(\n  left : @ion_model.IonTimestamp,\n  right : @ion_model.IonTimestamp,\n) -> Int {\n  let seconds_order =\n    ion_schema_codegen_timestamp_seconds(left).compare(\n      ion_schema_codegen_timestamp_seconds(right),\n    )\n  if seconds_order != 0 {\n    return seconds_order\n  }\n  let left_fraction = left.fraction_coefficient().unwrap_or(\n    @bigint.BigInt::from_int(0),\n  )\n  let left_exponent = left.fraction_exponent().unwrap_or(0)\n  let right_fraction = right.fraction_coefficient().unwrap_or(\n    @bigint.BigInt::from_int(0),\n  )\n  let right_exponent = right.fraction_exponent().unwrap_or(0)\n  ion_schema_codegen_compare_decimal_parts(\n    left_fraction,\n    left_exponent,\n    right_fraction,\n    right_exponent,\n  )\n}\n",
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
        "valid_values for type " + named_type.name + " cannot be encoded",
      )
  }
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) =>
      raise SchemaError::UnsupportedFeature(
        "valid_values is only supported on scalar types at type " +
        named_type.name,
      )
  }
  let expected_type = expected_ion_type(type_ref, types)
  output.write_string(
    "///|\n/// Test whether an Ion value satisfies valid_values for ",
  )
  output.write_string(name)
  output.write_string(".\npub fn is_valid_values_")
  output.write_string(name)
  output.write_string(
    "(value : @ion_model.IonValue) -> Bool {\n  let allowed_values = @ion.parse_text(\"",
  )
  output.write_string(moonbit_string_literal(encoded))
  output.write_string(
    "\") catch {\n    _ => []\n  }\n  for candidate in allowed_values {\n    if ion_schema_codegen_valid_values_match(value, candidate) {\n      return true\n    }\n  }\n  false\n}\n\n",
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
