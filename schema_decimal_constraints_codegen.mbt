///|
fn has_decimal_precision_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.precision_ranges.length() > 0 {
      return true
    }
  }
  false
}

///|
fn has_decimal_exponent_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.exponent_ranges.length() > 0 {
      return true
    }
  }
  false
}

///|
fn has_decimal_constraints(types : Array[NamedType]) -> Bool {
  has_decimal_precision_constraints(types) ||
  has_decimal_exponent_constraints(types)
}

///|
fn write_decimal_constraint_helpers(
  output : StringBuilder,
  include_precision : Bool,
  include_exponent : Bool,
) -> Unit {
  if include_precision {
    output.write_string(
      "///|\nfn ion_schema_codegen_decimal_precision(\n  value : @ion_model.IonValue,\n) -> Int? {\n  if value.is_null() {\n    return None\n  }\n  match value.without_annotations() {\n    @ion_model.IonValue::Decimal(decimal) => {\n      let coefficient : @bigint.BigInt = decimal.coefficient()\n      let digits = coefficient.to_string().length()\n      let sign_digits = if coefficient.compare_int(0) < 0 { 1 } else { 0 }\n      Some(digits - sign_digits)\n    }\n    _ => None\n  }\n}\n",
    )
  }
  if include_exponent {
    if include_precision {
      output.write_string("\n")
    }
    output.write_string(
      "///|\nfn ion_schema_codegen_decimal_exponent(\n  value : @ion_model.IonValue,\n) -> Int? {\n  if value.is_null() {\n    return None\n  }\n  match value.without_annotations() {\n    @ion_model.IonValue::Decimal(decimal) => Some(decimal.exponent())\n    _ => None\n  }\n}\n",
    )
  }
}

///|
fn write_decimal_constraint_value_checks(
  output : StringBuilder,
  ranges : Array[IntegerRange],
  value_expression : String,
  path_expression : String,
  constraint : String,
  measure : String,
  indent : String,
) -> Unit {
  if ranges.length() == 0 {
    return
  }
  let actual_name = "ion_schema_codegen_" + constraint + "_value"
  output.write_string(
    indent +
    "match " +
    measure +
    "(" +
    value_expression +
    ") {\n" +
    indent +
    "  Some(" +
    actual_name +
    ") => {\n",
  )
  write_integer_range_checks(
    output,
    ranges,
    actual_name,
    path_expression,
    constraint,
    indent + "    ",
  )
  output.write_string(
    indent +
    "  }\n" +
    indent +
    "  None => raise ConversionError::InvalidValue(\n" +
    indent +
    "    path=" +
    path_expression +
    ",\n" +
    indent +
    "    constraint=\"" +
    constraint +
    "\",\n" +
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

///|
fn write_named_decimal_constraint_checks(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit {
  write_decimal_constraint_value_checks(
    output,
    named_type.precision_ranges,
    value_expression,
    path_expression,
    "precision",
    "ion_schema_codegen_decimal_precision",
    indent,
  )
  write_decimal_constraint_value_checks(
    output,
    named_type.exponent_ranges,
    value_expression,
    path_expression,
    "exponent",
    "ion_schema_codegen_decimal_exponent",
    indent,
  )
}

///|
fn write_named_decimal_constraint_chain(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
  remaining : Int,
) -> Unit {
  if remaining <= 0 {
    return
  }
  write_named_decimal_constraint_checks(
    output, named_type, value_expression, path_expression, indent,
  )
  match named_type.body {
    TypeBody::Alias(TypeRef::Named(next)) =>
      match find_named_type(types, next) {
        Some(target) =>
          write_named_decimal_constraint_chain(
            output,
            target,
            types,
            value_expression,
            path_expression,
            indent,
            remaining - 1,
          )
        None => ()
      }
    _ => ()
  }
}

///|
fn write_named_decimal_constraint_validator(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  output.write_string(
    "///|\n/// Validate Decimal precision and exponent constraints for ",
  )
  output.write_string(generated_name)
  output.write_string(
    ".\npub fn validate_decimal_constraints_" +
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
  write_named_decimal_constraint_chain(
    output,
    named_type,
    types,
    "value",
    "\"" + moonbit_string_literal(named_type.name) + "\"",
    "  ",
    types.length(),
  )
  output.write_string("}\n")
}
