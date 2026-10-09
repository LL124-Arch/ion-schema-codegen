///|
fn has_type_algebra_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.all_of.length() > 0 {
      return true
    }
  }
  false
}

///|
fn named_type_needs_algebra_matcher(
  name : String,
  types : Array[NamedType],
) -> Bool {
  for named_type in types {
    for type_ref in named_type.all_of {
      match type_ref {
        TypeRef::Named(target) | TypeRef::NullOrNamed(target) =>
          if target == name {
            return true
          }
        TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
      }
    }
  }
  false
}

///|
fn write_named_type_algebra_checks(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  for type_ref in named_type.all_of {
    let expression = type_reference_match_expression(
      type_ref, value_expression, types,
    )
    output.write_string(
      indent +
      "if !" +
      expression +
      " {\n" +
      indent +
      "  raise ConversionError::InvalidValue(\n" +
      indent +
      "    path=" +
      path_expression +
      ",\n" +
      indent +
      "    constraint=\"all_of\",\n" +
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
fn type_reference_match_expression(
  type_ref : TypeRef,
  value_expression : String,
  types : Array[NamedType],
) -> String raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) =>
      "ion_schema_codegen_matches_type(" +
      value_expression +
      ", \"" +
      moonbit_string_literal(name) +
      "\")"
    TypeRef::NullOrBuiltin(name) =>
      "(ion_schema_codegen_matches_type(" +
      value_expression +
      ", \"$null\") || ion_schema_codegen_matches_type(" +
      value_expression +
      ", \"" +
      moonbit_string_literal(name) +
      "\"))"
    TypeRef::Named(name) => {
      ignore(find_named_type(types, name))
      "ion_schema_codegen_matches_named_" +
      moonbit_type_identifier(name) +
      "(" +
      value_expression +
      ")"
    }
    TypeRef::NullOrNamed(name) => {
      ignore(find_named_type(types, name))
      "(ion_schema_codegen_matches_type(" +
      value_expression +
      ", \"$null\") || ion_schema_codegen_matches_named_" +
      moonbit_type_identifier(name) +
      "(" +
      value_expression +
      "))"
    }
  }
}

///|
fn write_named_type_matcher(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  if !has_type_algebra_constraints(types) {
    return
  }
  let generated_name = moonbit_type_identifier(named_type.name)
  output.write_string(
    "///|\nfn ion_schema_codegen_matches_named_" +
    generated_name +
    "(value : @ion_model.IonValue) -> Bool {\n",
  )
  match named_type.body {
    TypeBody::Struct(_, _) =>
      output.write_string(
        "  try {\n    ignore(" +
        generated_name +
        "::from_ion(value))\n    true\n  } catch {\n    _ => false\n  }\n",
      )
    TypeBody::List(_) =>
      output.write_string(
        "  try {\n    ignore(from_ion_" +
        generated_name +
        "(value))\n    true\n  } catch {\n    _ => false\n  }\n",
      )
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar("document") => output.write_string("  false\n")
        _ => {
          output.write_string("  try {\n")
          write_type_validation_with_path_expression(
            output,
            type_ref,
            "value",
            types,
            "\"" + moonbit_string_literal(named_type.name) + "\"",
            "    ",
          )
          write_named_valid_values_checks(
            output,
            named_type.name,
            types,
            "value",
            "\"" + moonbit_string_literal(named_type.name) + "\"",
            "    ",
            types.length(),
          )
          output.write_string("    true\n  } catch {\n    _ => false\n  }\n")
        }
      }
  }
  output.write_string("}\n")
}

///|
fn write_named_type_algebra_validator(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  if named_type.all_of.length() == 0 {
    return
  }
  let generated_name = moonbit_type_identifier(named_type.name)
  output.write_string(
    "///|\n/// Validate the type algebra constraints for " +
    generated_name +
    ".\npub fn validate_type_" +
    generated_name +
    "(value : @ion_model.IonValue) -> Unit raise ConversionError {\n",
  )
  match named_type.body {
    TypeBody::Struct(_, _) =>
      output.write_string("  ignore(" + generated_name + "::from_ion(value))\n")
    TypeBody::List(_) =>
      output.write_string("  ignore(from_ion_" + generated_name + "(value))\n")
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => {
      write_type_validation_with_path_expression(
        output,
        type_ref,
        "value",
        types,
        "\"" + moonbit_string_literal(named_type.name) + "\"",
        "  ",
      )
      write_named_valid_values_checks(
        output,
        named_type.name,
        types,
        "value",
        "\"" + moonbit_string_literal(named_type.name) + "\"",
        "  ",
        types.length(),
      )
    }
  }
  output.write_string("}\n")
}
