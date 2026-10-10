///|
/// Generate MoonBit types and Ion conversions for the supported ISL 2.0 subset.
///
/// The returned package imports must be added to the target package's
/// moon.pkg file. Type names are converted to PascalCase; field names
/// lowercase an initial ASCII uppercase letter and replace hyphens with
/// underscores. Unsupported characters, reserved field names, and name
/// collisions are errors.
pub fn generate_code(source : String) -> GeneratedCode raise SchemaError {
  let schema = parse_schema(source)
  generate_code_for_schema(schema)
}

///|
/// Generate MoonBit code from already parsed Ion values for one schema.
///
/// This entry point avoids serializing parsed Ion values back to text, which
/// lets file-based callers preserve numeric precision while resolving imports.
/// Schema imports still need to be resolved before calling this function.
pub fn generate_code_from_ion_values(
  values : Array[@model.IonValue],
) -> GeneratedCode raise SchemaError {
  let schema = parse_schema_values(values)
  generate_code_for_schema(schema)
}

///|
fn generate_code_for_schema(schema : Schema) -> GeneratedCode raise SchemaError {
  validate_type_references(schema.types)
  validate_recursive_alias_cycles(schema.types)
  validate_unguarded_type_cycles(schema.types)
  validate_codegen_subset(schema.types)
  let ordered_types = order_named_types(schema.types)

  let package_imports : Array[String] = []
  if uses_model_types(schema.types) || has_conversion_types(schema.types) {
    package_imports.push(
      "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
    )
  }
  if has_valid_values(schema.types) || has_contains_constraints(schema.types) {
    package_imports.push("\"LL124-Arch/amazon-ion-moonbit-core\" @ion")
  }
  if uses_bigint(schema.types) ||
    has_valid_values(schema.types) ||
    has_decimal_constraints(schema.types) {
    package_imports.push("\"moonbitlang/core/bigint\"")
  }
  if has_regex_constraints(schema.types) {
    package_imports.push("\"moonbitlang/core/string\" @string")
  }

  let output = StringBuilder()
  if has_conversion_types(schema.types) {
    write_conversion_error(output)
    output.write_string("\n")
    write_ion_type_helpers(
      output,
      uses_nullable_type_checks(schema.types) ||
      has_decimal_constraints(schema.types) ||
      has_valid_values(schema.types) ||
      has_element_constraints(schema.types) ||
      has_ordered_elements(schema.types) ||
      has_named_type_matcher_references(schema.types),
    )
    if has_container_length_constraints(schema.types) {
      output.write_string("\n")
      write_container_length_helper(output)
    }
    if has_content_length_constraints(schema.types) {
      output.write_string("\n")
      write_content_length_helpers(output, schema.types)
    }
    if has_decimal_constraints(schema.types) {
      output.write_string("\n")
      write_decimal_constraint_helpers(
        output,
        has_decimal_precision_constraints(schema.types),
        has_decimal_exponent_constraints(schema.types),
      )
    }
    if has_timestamp_precision_constraints(schema.types) {
      output.write_string("\n")
      write_timestamp_precision_helper(output)
    }
    if has_timestamp_offset_constraints(schema.types) {
      output.write_string("\n")
      write_timestamp_offset_helpers(output)
    }
    if has_ieee754_float_constraints(schema.types) {
      output.write_string("\n")
      write_ieee754_float_helper(output)
    }
    if has_regex_constraints(schema.types) {
      output.write_string("\n")
      write_regex_helpers(output)
    }
    if has_annotation_constraints(schema.types) {
      output.write_string("\n")
      write_annotation_helper(output)
    }
    if has_annotation_ordered_constraints(schema.types) {
      output.write_string("\n")
      write_annotation_ordered_helper(output)
    }
    let has_distinct_elements = has_distinct_element_constraints(schema.types)
    let has_distinct_field_names = has_distinct_field_names_constraints(
      schema.types,
    )
    let has_contains = has_contains_constraints(schema.types)
    if has_distinct_elements || has_distinct_field_names || has_contains {
      output.write_string("\n")
      if has_distinct_elements || has_contains {
        write_ion_value_equality_helpers(output)
        if has_distinct_elements {
          write_distinct_element_check_helper(output)
        }
      } else {
        write_symbol_equality_helper(output)
      }
      if has_distinct_field_names {
        write_distinct_field_names_helper(output)
      }
      if has_contains {
        write_contains_helper(
          output,
          has_struct_contains_constraints(schema.types),
        )
      }
    }
    if has_valid_values(schema.types) {
      output.write_string("\n")
      write_valid_values_helpers(output)
      output.write_string("\n")
      write_valid_values_range_helpers(output)
    }
    if has_nested_conversion_types(schema.types) {
      output.write_string("\n")
      write_prefix_error_helper(output)
    }
    if has_ordered_elements(schema.types) {
      output.write_string("\n")
      write_ordered_element_helpers(output, schema.types)
    }
    output.write_string("\n")
  }
  let mut first_type = true
  for named_type in ordered_types {
    if named_type.is_inline {
      match named_type.body {
        TypeBody::Scalar(_) | TypeBody::Alias(_) =>
          if inline_type_is_used_in_container(named_type.name, schema.types) {
            write_named_type(output, named_type, schema.types)
            output.write_string("\n")
          }
        TypeBody::List(element_type) => {
          write_named_type(output, named_type, schema.types)
          if named_type.ordered_elements is Some(_) {
            write_ordered_list_conversions(output, named_type, schema.types)
          } else {
            write_list_conversions(
              output,
              named_type,
              element_type,
              schema.types,
            )
          }
          output.write_string("\n")
        }
        TypeBody::Struct(fields, is_open) => {
          write_named_type(output, named_type, schema.types)
          write_struct_conversions(
            output,
            named_type,
            fields,
            is_open,
            schema.types,
          )
          output.write_string("\n")
        }
      }
      if named_type.valid_values is Some(_) {
        write_named_valid_values(output, named_type, schema.types)
        output.write_string("\n")
      }
      if named_type_needs_algebra_matcher(named_type.name, schema.types) {
        write_named_type_matcher(output, named_type, schema.types)
        output.write_string("\n")
      }
    } else {
      if !first_type {
        output.write_string("\n")
      }
      first_type = false
      write_named_type(output, named_type, schema.types)
      if named_type.valid_values is Some(_) {
        output.write_string("\n")
        write_named_valid_values(output, named_type, schema.types)
      }
      if named_type.precision_ranges.length() > 0 ||
        named_type.exponent_ranges.length() > 0 {
        output.write_string("\n")
        write_named_decimal_constraint_validator(
          output,
          named_type,
          schema.types,
        )
      }
      if named_type.timestamp_precision_ranges.length() > 0 {
        output.write_string("\n")
        write_named_timestamp_precision_validator(
          output,
          named_type,
          schema.types,
        )
      }
      if named_type.timestamp_offsets.length() > 0 {
        output.write_string("\n")
        write_named_timestamp_offset_validator(output, named_type, schema.types)
      }
      if named_type.ieee754_float_formats.length() > 0 {
        output.write_string("\n")
        write_named_ieee754_float_validator(output, named_type, schema.types)
      }
      if named_type.regex_constraints.length() > 0 {
        output.write_string("\n")
        write_named_regex_validator(output, named_type, schema.types)
      }
      if named_type.annotation_constraints.length() > 0 {
        output.write_string("\n")
        write_named_annotations_validator(output, named_type, schema.types)
      }
      match named_type.body {
        TypeBody::Struct(fields, is_open) => {
          output.write_string("\n")
          write_struct_conversions(
            output,
            named_type,
            fields,
            is_open,
            schema.types,
          )
        }
        TypeBody::List(element_type) => {
          output.write_string("\n")
          if named_type.ordered_elements is Some(_) {
            write_ordered_list_conversions(output, named_type, schema.types)
          } else {
            write_list_conversions(
              output,
              named_type,
              element_type,
              schema.types,
            )
          }
        }
        TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
          if is_document_type(resolve_type_ref(schema.types, type_ref)) {
            output.write_string("\n")
            write_document_conversions(output, named_type, schema.types)
          } else if named_type.ordered_elements is Some(_) &&
            is_list_type(resolve_type_ref(schema.types, type_ref)) {
            output.write_string("\n")
            write_ordered_list_conversions(output, named_type, schema.types)
          }
      }
      if named_type.all_of.length() > 0 ||
        named_type.any_of.length() > 0 ||
        named_type.one_of.length() > 0 ||
        named_type.not_constraints.length() > 0 {
        output.write_string("\n")
        write_named_type_algebra_validator(output, named_type, schema.types)
      }
      if named_type_needs_algebra_matcher(named_type.name, schema.types) {
        output.write_string("\n")
        write_named_type_matcher(output, named_type, schema.types)
      }
    }
  }
  { source: output.to_string(), package_imports, }
}

///|
fn inline_type_is_used_in_container(
  name : String,
  types : Array[NamedType],
) -> Bool {
  for named_type in types {
    if !named_type.is_inline {
      continue
    }
    match named_type.body {
      TypeBody::List(TypeRef::Named(target)) if target == name => return true
      TypeBody::Struct(fields, _) =>
        for field in fields {
          match field.type_ref {
            TypeRef::Named(target) if target == name => return true
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn validate_codegen_subset(types : Array[NamedType]) -> Unit raise SchemaError {
  let generated_type_names : Array[(String, String)] = []
  let has_conversions = has_conversion_types(types)
  for named_type in types {
    let generated_name = moonbit_type_identifier(named_type.name)
    if is_builtin_output_type(generated_name) {
      raise SchemaError::InvalidIdentifier(
        "type name \{named_type.name} maps to built-in MoonBit type \{generated_name}",
      )
    }
    match find_generated_name(generated_type_names, generated_name) {
      Some((original, _)) =>
        raise SchemaError::IdentifierCollision(
          "type names \{original} and \{named_type.name} both map to \{generated_name}",
        )
      None => ()
    }
    generated_type_names.push((named_type.name, generated_name))

    match named_type.element_type {
      Some(element_type) => {
        validate_codegen_reference(
          element_type,
          "element of \{named_type.name}",
        )
        reject_document_reference(
          element_type,
          types,
          "element of \{named_type.name}",
        )
      }
      None => ()
    }
    match named_type.field_names_type {
      Some(field_names_type) => {
        validate_codegen_reference(
          field_names_type, "field_names of {named_type.name}",
        )
        reject_document_reference(
          field_names_type, types, "field_names of {named_type.name}",
        )
      }
      None => ()
    }
    match named_type.ordered_elements {
      Some(ordered_elements) =>
        for ordered_element in ordered_elements {
          validate_codegen_reference(
            ordered_element.type_ref,
            "ordered_elements of \{named_type.name}",
          )
          reject_document_reference(
            ordered_element.type_ref,
            types,
            "ordered_elements of \{named_type.name}",
          )
        }
      None => ()
    }
    for constraint in named_type.annotation_constraints {
      match constraint.standard_type_ref {
        Some(type_ref) =>
          validate_codegen_reference(
            type_ref,
            "annotations of \{named_type.name}",
          )
        None => ()
      }
      match constraint.standard_ordered_elements {
        Some(ordered_elements) =>
          for ordered_element in ordered_elements {
            validate_codegen_reference(
              ordered_element.type_ref,
              "annotations ordered_elements of \{named_type.name}",
            )
          }
        None => ()
      }
    }

    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        validate_codegen_reference(type_ref, "type \{named_type.name}")
      TypeBody::Struct(fields, is_open) => {
        let generated_fields : Array[(String, String)] = []
        if is_open {
          generated_fields.push(
            ("ion_schema_codegen_open_content", "open content storage"),
          )
        }
        for field in fields {
          let generated_field = moonbit_field_identifier(
            field.name,
            "field \{named_type.name}.\{field.name}",
          )
          if is_moonbit_reserved_word(generated_field) {
            raise SchemaError::InvalidIdentifier(
              "field \{named_type.name}.\{field.name} maps to reserved MoonBit word \{generated_field}",
            )
          }
          match find_generated_name(generated_fields, generated_field) {
            Some((original, _)) =>
              raise SchemaError::IdentifierCollision(
                "fields \{named_type.name}.\{original} and \{named_type.name}.\{field.name} both map to \{generated_field}",
              )
            None => ()
          }
          generated_fields.push((field.name, generated_field))
          validate_codegen_reference(
            field.type_ref,
            "field \{named_type.name}.\{field.name}",
          )
          reject_document_reference(
            field.type_ref,
            types,
            "field \{named_type.name}.\{field.name}",
          )
        }
      }
      TypeBody::List(type_ref) => {
        validate_codegen_reference(type_ref, "element of \{named_type.name}")
        reject_document_reference(
          type_ref,
          types,
          "element of \{named_type.name}",
        )
      }
    }
  }
  if has_conversions &&
    find_generated_name(generated_type_names, "ConversionError")
    is Some((original, _)) {
    raise SchemaError::IdentifierCollision(
      "type name \{original} maps to ConversionError, which is reserved for generated conversion errors",
    )
  }
}

///|
fn reject_document_reference(
  type_ref : TypeRef,
  types : Array[NamedType],
  context : String,
) -> Unit raise SchemaError {
  if is_document_type(resolve_type_ref(types, type_ref)) {
    raise SchemaError::UnsupportedFeature(
      "document streams cannot be nested as an Ion value at \{context}",
    )
  }
}

///|
fn is_document_type(resolved : ResolvedType) -> Bool {
  match resolved {
    ResolvedType::Scalar("document") => true
    _ => false
  }
}

///|
fn validate_codegen_reference(
  type_ref : TypeRef,
  context : String,
) -> Unit raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => ignore(moonbit_type_for_builtin(name, context))
    TypeRef::Named(_) => ()
    TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) => ()
  }
}

///|
fn write_named_type(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  output.write_string("///|\n")
  let generated_name = moonbit_type_identifier(named_type.name)
  let type_visibility = if named_type.is_inline { "type " } else { "pub type " }
  match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => {
      output.write_string(type_visibility)
      output.write_string(generated_name)
      output.write_string(" = ")
      let resolves_to_list = match resolve_type_ref(types, type_ref) {
        ResolvedType::List(_) => true
        _ => false
      }
      if named_type.ordered_elements is Some(_) && resolves_to_list {
        output.write_string("Array[@ion_model.IonValue]")
      } else {
        output.write_string(
          moonbit_type_for_reference_in(
            type_ref,
            types,
            "type \{named_type.name}",
          ),
        )
      }
      output.write_string("\n")
    }
    TypeBody::Struct(fields, is_open) => {
      output.write_string(
        if named_type.is_inline {
          "priv struct "
        } else {
          "pub(all) struct "
        },
      )
      output.write_string(generated_name)
      if fields.length() == 0 && !is_open {
        output.write_string(" {}\n")
        return
      }
      output.write_string(" {\n")
      for field in fields {
        output.write_string("  ")
        output.write_string(
          moonbit_field_identifier(
            field.name,
            "field \{named_type.name}.\{field.name}",
          ),
        )
        output.write_string(" : ")
        if is_repeated_field(field.occurrence) {
          output.write_string("Array[")
        }
        output.write_string(
          moonbit_type_for_reference_in(
            field.type_ref,
            types,
            "field \{named_type.name}.\{field.name}",
          ),
        )
        if is_repeated_field(field.occurrence) {
          output.write_string("]")
        } else if is_optional_field(field.occurrence) {
          output.write_string("?")
        }
        output.write_string("\n")
      }
      if is_open {
        output.write_string(
          "  ion_schema_codegen_open_content : Array[(@ion_model.IonSymbol, @ion_model.IonValue)]\n",
        )
      }
      output.write_string("}\n")
    }
    TypeBody::List(element_type) => {
      output.write_string(type_visibility)
      output.write_string(generated_name)
      if named_type.ordered_elements is Some(_) {
        output.write_string(" = Array[@ion_model.IonValue]\n")
      } else {
        output.write_string(" = Array[")
        output.write_string(
          moonbit_type_for_reference_in(
            element_type,
            types,
            "element of \{named_type.name}",
          ),
        )
        output.write_string("]\n")
      }
    }
  }
}

///|
fn write_document_conversions(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  output.write_string("///|\n/// Convert an Ion document stream to ")
  output.write_string(generated_name)
  output.write_string(".\npub fn from_ion_document_")
  output.write_string(generated_name)
  output.write_string("(\n  values : Array[@ion_model.IonValue],\n) -> ")
  output.write_string(generated_name)
  if named_type.container_lengths.length() > 0 ||
    named_type.element_type is Some(_) ||
    named_type.annotation_constraints.length() > 0 ||
    has_named_contains_values(named_type) ||
    named_type.ordered_elements is Some(_) ||
    has_document_alias_constraints(named_type, types, types.length()) {
    output.write_string(" raise ConversionError {\n  let type_path = \"")
    output.write_string(named_type.name)
    output.write_string("\"\n")
    write_document_constraint_chain(
      output,
      named_type,
      types,
      "values",
      "type_path",
      "  ",
      types.length(),
    )
    output.write_string("  values\n}\n\n")
  } else {
    output.write_string(" {\n  values\n}\n\n")
  }
  output.write_string("///|\n/// Convert ")
  output.write_string(generated_name)
  output.write_string(" to an Ion document stream.\npub fn to_ion_document_")
  output.write_string(generated_name)
  output.write_string("(\n  values : ")
  output.write_string(generated_name)
  output.write_string("\n) -> Array[@ion_model.IonValue] {\n  values\n}\n")
}

///|
fn has_document_alias_constraints(
  named_type : NamedType,
  types : Array[NamedType],
  remaining : Int,
) -> Bool {
  if remaining <= 0 {
    return false
  }
  match named_type.body {
    TypeBody::Alias(TypeRef::Named(next)) =>
      match find_named_type(types, next) {
        Some(target) =>
          target.container_lengths.length() > 0 ||
          target.annotation_constraints.length() > 0 ||
          target.element_type is Some(_) ||
          has_named_contains_values(target) ||
          target.element_distinct ||
          target.ordered_elements is Some(_) ||
          has_document_alias_constraints(target, types, remaining - 1)
        None => false
      }
    _ => false
  }
}

///|
fn write_document_constraint_chain(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  values_expression : String,
  path_expression : String,
  indent : String,
  remaining : Int,
) -> Unit raise SchemaError {
  if remaining <= 0 {
    return
  }
  write_integer_range_checks(
    output,
    named_type.container_lengths,
    values_expression + ".length()",
    path_expression,
    "container_length",
    indent,
  )
  match named_type.contains_values {
    Some(required) =>
      write_contains_check(
        output, required, values_expression, path_expression, indent,
      )
    None => ()
  }
  if named_type.element_distinct {
    write_distinct_values_check(
      output, values_expression, path_expression, indent,
    )
  }
  match named_type.element_type {
    Some(element_type) =>
      write_document_element_checks(
        output, element_type, types, values_expression, path_expression, indent,
        remaining,
      )
    None => ()
  }
  write_ordered_sequence_check(
    output, named_type, values_expression, path_expression, indent,
  )
  write_document_annotations_failure(
    output, named_type, path_expression, indent,
  )
  match named_type.body {
    TypeBody::Alias(TypeRef::Named(next)) =>
      match find_named_type(types, next) {
        Some(target) =>
          write_document_constraint_chain(
            output,
            target,
            types,
            values_expression,
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
fn write_document_element_checks(
  output : StringBuilder,
  element_type : TypeRef,
  types : Array[NamedType],
  values_expression : String,
  path_expression : String,
  indent : String,
  depth : Int,
) -> Unit raise SchemaError {
  let index_name = "ion_schema_codegen_document_index_" + depth.to_string()
  let value_name = "ion_schema_codegen_document_value_" + depth.to_string()
  let element_path = "ion_schema_codegen_document_path_" + depth.to_string()
  output.write_string(
    indent +
    "let mut " +
    index_name +
    " = 0\n" +
    indent +
    "for " +
    value_name +
    " in " +
    values_expression +
    " {\n" +
    indent +
    "  let " +
    element_path +
    " = " +
    path_expression +
    " + \"[\" + " +
    index_name +
    ".to_string() + \"]\"\n",
  )
  write_element_item_validation(
    output,
    element_type,
    value_name,
    types,
    element_path,
    indent + "  ",
  )
  output.write_string(indent + "  " + index_name + " += 1\n" + indent + "}\n")
}

///|
fn write_struct_element_checks(
  output : StringBuilder,
  element_type : TypeRef,
  types : Array[NamedType],
  fields_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  output.write_string(
    indent +
    "let mut ion_schema_codegen_struct_element_index = 0\n" +
    indent +
    "for (ion_schema_codegen_struct_element_symbol, ion_schema_codegen_struct_element_value) in " +
    fields_expression +
    " {\n" +
    indent +
    "  let ion_schema_codegen_struct_element_path = " +
    path_expression +
    " + \".\" + ion_schema_codegen_struct_element_symbol.text_value().unwrap_or(\"<field>\") + \"[\" + ion_schema_codegen_struct_element_index.to_string() + \"]\"\n",
  )
  write_element_item_validation(
    output,
    element_type,
    "ion_schema_codegen_struct_element_value",
    types,
    "ion_schema_codegen_struct_element_path",
    indent + "  ",
  )
  output.write_string(
    indent + "  ion_schema_codegen_struct_element_index += 1\n" + indent + "}\n",
  )
}

///|
fn write_named_element_checks(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  let element_type = match named_type.element_type {
    Some(type_ref) => type_ref
    None => return
  }
  match named_type.body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
    _ => ()
  }
  let base_type = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  match resolve_type_ref(types, base_type) {
    ResolvedType::Scalar("sexp" | "$sexp") =>
      write_named_sequence_element_checks(
        output, named_type, element_type, types, value_expression, path_expression,
        indent, "Sexp", "ion_schema_codegen_sexp_element",
      )
    ResolvedType::Scalar("list" | "$list") =>
      write_named_sequence_element_checks(
        output, named_type, element_type, types, value_expression, path_expression,
        indent, "List", "ion_schema_codegen_nullable_list_element",
      )
    ResolvedType::List(_) =>
      write_named_sequence_element_checks(
        output, named_type, element_type, types, value_expression, path_expression,
        indent, "List", "ion_schema_codegen_list_alias_element",
      )
    ResolvedType::Struct(_) | ResolvedType::Scalar("struct" | "$struct") =>
      write_named_struct_alias_element_checks(
        output, named_type, element_type, types, value_expression, path_expression,
        indent,
      )
    ResolvedType::Scalar(_) => ()
  }
}

///|
fn write_named_field_names_checks(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  let field_names_type = match named_type.field_names_type {
    Some(type_ref) => type_ref
    None => return
  }
  match named_type.body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
    _ => ()
  }
  let base_type = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  match resolve_type_ref(types, base_type) {
    ResolvedType::Struct(_) | ResolvedType::Scalar("struct" | "$struct") => {
      let fields_name = "ion_schema_codegen_field_name_fields_" +
        moonbit_type_identifier(named_type.name)
      output.write_string(
        indent +
        "let " +
        fields_name +
        " = match " +
        value_expression +
        ".without_annotations() {\n" +
        indent +
        "  @ion_model.IonValue::Struct(fields) => fields\n" +
        indent +
        "  _ => raise ConversionError::InvalidValue(path=" +
        path_expression +
        ", constraint=\"field_names\", actual=ion_schema_codegen_actual_type(" +
        value_expression +
        "))\n" +
        indent +
        "}\n",
      )
      write_field_names_checks(
        output,
        named_type,
        field_names_type,
        named_type.field_names_distinct,
        types,
        fields_name,
        path_expression,
        indent,
      )
    }
    ResolvedType::Scalar(_) | ResolvedType::List(_) => ()
  }
}

///|
fn write_named_contains_checks(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  let required = match named_type.contains_values {
    Some(values) if values.length() > 0 => values
    _ => return
  }
  match named_type.body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
    _ => ()
  }
  let base_type = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  match resolve_type_ref(types, base_type) {
    ResolvedType::Scalar("sexp" | "$sexp") =>
      write_named_sequence_contains_check(
        output, named_type, value_expression, path_expression, indent, "Sexp", required,
      )
    ResolvedType::Scalar("list" | "$list") | ResolvedType::List(_) =>
      write_named_sequence_contains_check(
        output, named_type, value_expression, path_expression, indent, "List", required,
      )
    ResolvedType::Struct(_) | ResolvedType::Scalar("struct" | "$struct") =>
      write_named_struct_contains_check(
        output, named_type, value_expression, path_expression, indent, required,
      )
    ResolvedType::Scalar("document") | ResolvedType::Scalar(_) => ()
  }
}

///|
fn write_named_sequence_contains_check(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
  variant : String,
  required : Array[@model.IonValue],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let values_name = "ion_schema_codegen_contains_values_" + generated_name
  output.write_string(
    indent +
    "let " +
    values_name +
    " = match " +
    value_expression +
    ".without_annotations() {\n" +
    indent +
    "  @ion_model.IonValue::" +
    variant +
    "(values) => values\n" +
    indent +
    "  _ => raise ConversionError::InvalidValue(path=" +
    path_expression +
    ", constraint=\"contains\", actual=ion_schema_codegen_actual_type(" +
    value_expression +
    "))\n" +
    indent +
    "}\n",
  )
  write_contains_check(output, required, values_name, path_expression, indent)
}

///|
fn write_named_struct_contains_check(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
  required : Array[@model.IonValue],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let fields_name = "ion_schema_codegen_contains_fields_" + generated_name
  output.write_string(
    indent +
    "let " +
    fields_name +
    " = match " +
    value_expression +
    ".without_annotations() {\n" +
    indent +
    "  @ion_model.IonValue::Struct(fields) => fields\n" +
    indent +
    "  _ => raise ConversionError::InvalidValue(path=" +
    path_expression +
    ", constraint=\"contains\", actual=ion_schema_codegen_actual_type(" +
    value_expression +
    "))\n" +
    indent +
    "}\n",
  )
  write_contains_check(
    output,
    required,
    "ion_schema_codegen_struct_field_values(" + fields_name + ")",
    path_expression,
    indent,
  )
}

///|
fn write_field_names_checks(
  output : StringBuilder,
  named_type : NamedType,
  field_names_type : TypeRef,
  distinct : Bool,
  types : Array[NamedType],
  fields_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  let owner = moonbit_type_identifier(named_type.name)
  let index_name = "ion_schema_codegen_field_name_index_" + owner
  let symbol_name = "ion_schema_codegen_field_name_symbol_" + owner
  let field_path = "ion_schema_codegen_field_name_path_" + owner
  output.write_string(
    indent +
    "let mut " +
    index_name +
    " = 0\n" +
    indent +
    "for (" +
    symbol_name +
    ", _) in " +
    fields_expression +
    " {\n" +
    indent +
    "  let " +
    field_path +
    " = " +
    path_expression +
    " + \".\" + " +
    symbol_name +
    ".text_value().unwrap_or(\"<field>\") + \"[\" + " +
    index_name +
    ".to_string() + \"]\"\n",
  )
  write_element_item_validation(
    output,
    field_names_type,
    "@ion_model.IonValue::Symbol(" + symbol_name + ")",
    types,
    field_path,
    indent + "  ",
  )
  output.write_string(indent + "  " + index_name + " += 1\n" + indent + "}\n")
  if distinct {
    write_field_names_distinct_check(
      output, named_type, fields_expression, path_expression, indent,
    )
  }
}

///|
fn write_named_ordered_checks(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  if named_type.ordered_elements is None {
    return
  }
  match named_type.body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
    _ => ()
  }
  let base_type = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  match resolve_type_ref(types, base_type) {
    ResolvedType::Scalar("sexp" | "$sexp") => {
      let generated_name = moonbit_type_identifier(named_type.name)
      let sequence_name = "ion_schema_codegen_ordered_sexp_" + generated_name
      output.write_string(
        indent +
        "let " +
        sequence_name +
        " = match " +
        value_expression +
        ".without_annotations() {\n" +
        indent +
        "  @ion_model.IonValue::Sexp(values) => values\n" +
        indent +
        "  _ => raise ConversionError::InvalidValue(path=" +
        path_expression +
        ", constraint=\"ordered_elements\", actual=ion_schema_codegen_actual_type(" +
        value_expression +
        "))\n" +
        indent +
        "}\n",
      )
      write_ordered_sequence_check(
        output, named_type, sequence_name, path_expression, indent,
      )
    }
    ResolvedType::Scalar(_) | ResolvedType::Struct(_) | ResolvedType::List(_) =>
      ()
  }
}

///|
fn write_named_sequence_element_checks(
  output : StringBuilder,
  named_type : NamedType,
  element_type : TypeRef,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
  ion_variant : String,
  variable_prefix : String,
) -> Unit raise SchemaError {
  let elements_name = variable_prefix + "s"
  let index_name = variable_prefix + "_index"
  let element_name = variable_prefix + "_value"
  let element_path = variable_prefix + "_path"
  output.write_string(
    indent +
    "let " +
    elements_name +
    " = match " +
    value_expression +
    ".without_annotations() {\n" +
    indent +
    "  @ion_model.IonValue::" +
    ion_variant +
    "(elements) => elements\n" +
    indent +
    "  _ => raise ConversionError::InvalidValue(path=" +
    path_expression +
    ", constraint=\"element\", actual=ion_schema_codegen_actual_type(" +
    value_expression +
    "))\n" +
    indent +
    "}\n" +
    indent +
    "let mut " +
    index_name +
    " = 0\n" +
    indent +
    "for " +
    element_name +
    " in " +
    elements_name +
    " {\n" +
    indent +
    "  let " +
    element_path +
    " = " +
    path_expression +
    " + \"[\" + " +
    index_name +
    ".to_string() + \"]\"\n",
  )
  write_element_item_validation(
    output,
    element_type,
    element_name,
    types,
    element_path,
    indent + "  ",
  )
  output.write_string(indent + "  " + index_name + " += 1\n" + indent + "}\n")
  if named_type.element_distinct {
    write_distinct_values_check(output, elements_name, path_expression, indent)
  }
}

///|
fn write_named_struct_alias_element_checks(
  output : StringBuilder,
  named_type : NamedType,
  element_type : TypeRef,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  output.write_string(
    indent +
    "let ion_schema_codegen_struct_elements = match " +
    value_expression +
    ".without_annotations() {\n" +
    indent +
    "  @ion_model.IonValue::Struct(fields) => fields\n" +
    indent +
    "  _ => raise ConversionError::InvalidValue(path=" +
    path_expression +
    ", constraint=\"element\", actual=ion_schema_codegen_actual_type(" +
    value_expression +
    "))\n" +
    indent +
    "}\n" +
    indent +
    "let mut ion_schema_codegen_struct_element_index = 0\n" +
    indent +
    "for (ion_schema_codegen_struct_element_symbol, ion_schema_codegen_struct_element_value) in ion_schema_codegen_struct_elements {\n" +
    indent +
    "  let ion_schema_codegen_struct_element_path = " +
    path_expression +
    " + \".\" + ion_schema_codegen_struct_element_symbol.text_value().unwrap_or(\"<field>\") + \"[\" + ion_schema_codegen_struct_element_index.to_string() + \"]\"\n",
  )
  write_element_item_validation(
    output,
    element_type,
    "ion_schema_codegen_struct_element_value",
    types,
    "ion_schema_codegen_struct_element_path",
    indent + "  ",
  )
  output.write_string(
    indent + "  ion_schema_codegen_struct_element_index += 1\n" + indent + "}\n",
  )
  if named_type.element_distinct {
    write_distinct_struct_check(
      output, named_type, "ion_schema_codegen_struct_elements", path_expression,
      indent,
    )
  }
}

///|
fn write_element_item_validation(
  output : StringBuilder,
  element_type : TypeRef,
  value_expression : String,
  types : Array[NamedType],
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  if !is_raw_ion_value_reference(element_type, types) &&
    !reference_has_valid_values(element_type, types) {
    output.write_string(
      indent +
      "if " +
      value_expression +
      ".annotations().length() > 0 {\n" +
      indent +
      "  raise ConversionError::AnnotatedValueNotSupported(path=" +
      path_expression +
      ")\n" +
      indent +
      "}\n",
    )
  }
  if !reference_accepts_null(element_type, types) {
    output.write_string(
      indent +
      "if " +
      value_expression +
      ".is_null() {\n" +
      indent +
      "  raise ConversionError::NullNotAllowed(path=" +
      path_expression +
      ")\n" +
      indent +
      "}\n",
    )
  }
  if is_null_or_type_ref(element_type) {
    output.write_string(
      indent +
      "if !ion_schema_codegen_matches_type(" +
      value_expression +
      ", \"$null\") {\n",
    )
    write_type_validation_with_path_expression(
      output,
      nullable_inner_type_ref(element_type),
      value_expression,
      types,
      path_expression,
      indent + "  ",
    )
    output.write_string(indent + "}\n")
  } else {
    write_type_validation_with_path_expression(
      output, element_type, value_expression, types, path_expression, indent,
    )
  }
  write_reference_valid_values_checks(
    output, element_type, types, value_expression, path_expression, indent,
  )
}

///|
fn ordered_elements_validator_name(
  named_type : NamedType,
) -> String raise SchemaError {
  "ion_schema_codegen_validate_ordered_" +
  moonbit_type_identifier(named_type.name)
}

///|
fn ordered_element_matcher_name(
  named_type : NamedType,
  index : Int,
) -> String raise SchemaError {
  "ion_schema_codegen_ordered_matches_" +
  moonbit_type_identifier(named_type.name) +
  "_" +
  index.to_string()
}

///|
fn write_ordered_element_helpers(
  output : StringBuilder,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  for named_type in types {
    match named_type.ordered_elements {
      Some(ordered_elements) => {
        let mut index = 0
        for ordered_element in ordered_elements {
          output.write_string(
            "///|\nfn " +
            ordered_element_matcher_name(named_type, index) +
            "(value : @ion_model.IonValue) -> Bool {\n  try {\n",
          )
          write_element_item_validation(
            output,
            ordered_element.type_ref,
            "value",
            types,
            "\"ordered_elements\"",
            "    ",
          )
          output.write_string(
            "    true\n  } catch {\n    _ => false\n  }\n}\n\n",
          )
          index += 1
        }
        write_ordered_sequence_validator(output, named_type, ordered_elements)
      }
      None => ()
    }
  }
}

///|
fn write_ordered_sequence_validator(
  output : StringBuilder,
  named_type : NamedType,
  ordered_elements : Array[OrderedElementSpec],
) -> Unit raise SchemaError {
  let validator_name = ordered_elements_validator_name(named_type)
  let element_count = ordered_elements.length()
  output.write_string(
    "///|\nfn " +
    validator_name +
    "(\n  values : Array[@ion_model.IonValue],\n  path : String,\n) -> Unit raise ConversionError {\n  let value_count = values.length()\n  let possible : Array[Array[Bool]] = []\n  let mut row_index = 0\n  while row_index <= " +
    element_count.to_string() +
    " {\n    let row : Array[Bool] = []\n    let mut column_index = 0\n    while column_index <= value_count {\n      row.push(false)\n      column_index += 1\n    }\n    possible.push(row)\n    row_index += 1\n  }\n  possible[" +
    element_count.to_string() +
    "][value_count] = true\n",
  )

  let mut index = element_count
  while index > 0 {
    index -= 1
    let ordered_element = ordered_elements[index]
    let row = index + 1
    let start_name = "ordered_start_" + index.to_string()
    let count_name = "ordered_count_" + index.to_string()
    let found_name = "ordered_found_" + index.to_string()
    let prefix_name = "ordered_prefix_matches_" + index.to_string()
    let matcher_name = ordered_element_matcher_name(named_type, index)
    output.write_string(
      "  let mut " +
      start_name +
      " = 0\n  while " +
      start_name +
      " <= value_count {\n    let mut " +
      count_name +
      " = " +
      ordered_element.occurrence.min_count.to_string() +
      "\n    let mut " +
      found_name +
      " = false\n    let mut " +
      prefix_name +
      " = true\n    while " +
      count_name +
      " <= value_count - " +
      start_name,
    )
    match ordered_element.occurrence.max_count {
      Some(maximum) =>
        output.write_string(" && " + count_name + " <= " + maximum.to_string())
      None => ()
    }
    output.write_string(
      " && " +
      prefix_name +
      " {\n      if " +
      count_name +
      " > 0 && !" +
      matcher_name +
      "(values[" +
      start_name +
      " + " +
      count_name +
      " - 1]) {\n        " +
      prefix_name +
      " = false\n      }\n      if " +
      prefix_name +
      " && possible[" +
      row.to_string() +
      "][" +
      start_name +
      " + " +
      count_name +
      "] {\n        " +
      found_name +
      " = true\n      }\n      " +
      count_name +
      " += 1\n    }\n    possible[" +
      index.to_string() +
      "][" +
      start_name +
      "] = " +
      found_name +
      "\n    " +
      start_name +
      " += 1\n  }\n",
    )
  }

  output.write_string(
    "  if !possible[0][0] {\n    let mut failure_index = value_count\n    let mut probe_index = 0\n    while probe_index < value_count {\n      let mut recognized = false\n",
  )
  index = 0
  for _ in ordered_elements {
    let matcher_name = ordered_element_matcher_name(named_type, index)
    output.write_string(
      "      if !recognized && " +
      matcher_name +
      "(values[probe_index]) {\n        recognized = true\n      }\n",
    )
    index += 1
  }
  output.write_string(
    "      if !recognized && failure_index == value_count {\n        failure_index = probe_index\n      }\n      probe_index += 1\n    }\n    let actual = if failure_index < value_count {\n      ion_schema_codegen_actual_type(values[failure_index])\n    } else {\n      \"sequence length \" + value_count.to_string()\n    }\n    raise ConversionError::InvalidValue(\n      path=path + \"[\" + failure_index.to_string() + \"]\",\n      constraint=\"ordered_elements\",\n      actual=actual,\n    )\n  }\n}\n\n",
  )
}

///|
fn write_ordered_sequence_check(
  output : StringBuilder,
  named_type : NamedType,
  values_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  match named_type.ordered_elements {
    Some(_) =>
      output.write_string(
        indent +
        ordered_elements_validator_name(named_type) +
        "(" +
        values_expression +
        ", " +
        path_expression +
        ")\n",
      )
    None => ()
  }
}

///|
fn write_conversion_error(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\npub(all) suberror ConversionError {\n  TypeMismatch(path~ : String, expected~ : String, actual~ : String)\n  InvalidValue(path~ : String, constraint~ : String, actual~ : String)\n  MissingRequiredField(path~ : String)\n  DuplicateField(path~ : String)\n  FieldOccurrenceMismatch(path~ : String, expected~ : String, actual~ : Int)\n  UnknownField(path~ : String)\n  UnknownSymbol(path~ : String, sid~ : Int)\n  NullNotAllowed(path~ : String)\n  AnnotatedValueNotSupported(path~ : String)\n}\n",
  )
}

///|
fn write_ion_type_helpers(
  output : StringBuilder,
  include_nullable_matcher : Bool,
) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_kind_name(kind : @ion_model.IonNull) -> String {\n  match kind {\n    @ion_model.IonNull::Null => \"null\"\n    @ion_model.IonNull::Bool => \"bool\"\n    @ion_model.IonNull::Int => \"int\"\n    @ion_model.IonNull::Float => \"float\"\n    @ion_model.IonNull::Decimal => \"decimal\"\n    @ion_model.IonNull::Timestamp => \"timestamp\"\n    @ion_model.IonNull::Symbol => \"symbol\"\n    @ion_model.IonNull::String => \"string\"\n    @ion_model.IonNull::Blob => \"blob\"\n    @ion_model.IonNull::Clob => \"clob\"\n    @ion_model.IonNull::List => \"list\"\n    @ion_model.IonNull::Sexp => \"sexp\"\n    @ion_model.IonNull::Struct => \"struct\"\n  }\n}\n\n///|\nfn ion_schema_codegen_actual_type(value : @ion_model.IonValue) -> String {\n  let kind = value.kind()\n  match (value.is_null(), kind) {\n    (true, @ion_model.IonNull::Null) => \"null\"\n    (true, typed_kind) => \"null.\\{ion_schema_codegen_kind_name(typed_kind)}\"\n    (false, actual_kind) => ion_schema_codegen_kind_name(actual_kind)\n  }\n}\n",
  )
  if include_nullable_matcher {
    output.write_string(
      "///|\nfn ion_schema_codegen_matches_type(\n  value : @ion_model.IonValue,\n  expected : String,\n) -> Bool {\n  let kind = value.kind()\n  let is_null = value.is_null()\n  match expected {\n    \"any\" => !is_null\n    \"$any\" => true\n    \"$null\" => is_null && kind == @ion_model.IonNull::Null\n    \"bool\" => !is_null && kind == @ion_model.IonNull::Bool\n    \"$bool\" => kind == @ion_model.IonNull::Bool\n    \"int\" => !is_null && kind == @ion_model.IonNull::Int\n    \"$int\" => kind == @ion_model.IonNull::Int\n    \"float\" => !is_null && kind == @ion_model.IonNull::Float\n    \"$float\" => kind == @ion_model.IonNull::Float\n    \"decimal\" => !is_null && kind == @ion_model.IonNull::Decimal\n    \"$decimal\" => kind == @ion_model.IonNull::Decimal\n    \"string\" => !is_null && kind == @ion_model.IonNull::String\n    \"$string\" => kind == @ion_model.IonNull::String\n    \"symbol\" => !is_null && kind == @ion_model.IonNull::Symbol\n    \"$symbol\" => kind == @ion_model.IonNull::Symbol\n    \"timestamp\" => !is_null && kind == @ion_model.IonNull::Timestamp\n    \"$timestamp\" => kind == @ion_model.IonNull::Timestamp\n    \"blob\" => !is_null && kind == @ion_model.IonNull::Blob\n    \"$blob\" => kind == @ion_model.IonNull::Blob\n    \"clob\" => !is_null && kind == @ion_model.IonNull::Clob\n    \"$clob\" => kind == @ion_model.IonNull::Clob\n    \"list\" => !is_null && kind == @ion_model.IonNull::List\n    \"$list\" => kind == @ion_model.IonNull::List\n    \"sexp\" => !is_null && kind == @ion_model.IonNull::Sexp\n    \"$sexp\" => kind == @ion_model.IonNull::Sexp\n    \"struct\" => !is_null && kind == @ion_model.IonNull::Struct\n    \"$struct\" => kind == @ion_model.IonNull::Struct\n    \"number\" | \"$number\" =>\n      (kind == @ion_model.IonNull::Int ||\n        kind == @ion_model.IonNull::Float ||\n        kind == @ion_model.IonNull::Decimal) && (expected == \"$number\" || !is_null)\n    \"text\" | \"$text\" =>\n      (kind == @ion_model.IonNull::String || kind == @ion_model.IonNull::Symbol) &&\n      (expected == \"$text\" || !is_null)\n    \"lob\" | \"$lob\" =>\n      (kind == @ion_model.IonNull::Blob || kind == @ion_model.IonNull::Clob) &&\n      (expected == \"$lob\" || !is_null)\n    _ => false\n  }\n}\n",
    )
  }
}

///|
fn has_container_length_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.container_lengths.length() > 0 {
      match named_type.body {
        TypeBody::Alias(_) => return true
        _ if !named_type.is_inline => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn has_ordered_elements(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.ordered_elements is Some(_) {
      return true
    }
  }
  false
}

///|
fn has_element_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.element_type is Some(_) {
      return true
    }
  }
  false
}

///|
fn write_container_length_helper(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_container_length(\n  value : @ion_model.IonValue,\n) -> Int? {\n  match value.without_annotations() {\n    @ion_model.IonValue::List(elements) => Some(elements.length())\n    @ion_model.IonValue::Sexp(elements) => Some(elements.length())\n    @ion_model.IonValue::Struct(fields) => Some(fields.length())\n    _ => None\n  }\n}\n",
  )
}

///|
fn write_container_length_value_checks(
  output : StringBuilder,
  ranges : Array[IntegerRange],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit {
  write_ion_value_integer_range_checks(
    output, ranges, value_expression, path_expression, "container_length", "ion_schema_codegen_container_length",
    indent,
  )
}

///|
fn write_ion_value_integer_range_checks(
  output : StringBuilder,
  ranges : Array[IntegerRange],
  value_expression : String,
  path_expression : String,
  constraint : String,
  measure_function : String,
  indent : String,
) -> Unit {
  if ranges.length() == 0 {
    return
  }
  output.write_string(
    indent +
    "match " +
    measure_function +
    "(" +
    value_expression +
    ") {\n" +
    indent +
    "  Some(actual_length) => {\n",
  )
  write_integer_range_checks(
    output,
    ranges,
    "actual_length",
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
fn write_integer_range_checks(
  output : StringBuilder,
  ranges : Array[IntegerRange],
  actual_expression : String,
  path_expression : String,
  constraint : String,
  indent : String,
) -> Unit {
  for range in ranges {
    let mut invalid_condition = actual_expression +
      " < " +
      range.minimum.to_string()
    match range.maximum {
      Some(maximum) =>
        invalid_condition = invalid_condition +
          " || " +
          actual_expression +
          " > " +
          maximum.to_string()
      None => ()
    }
    output.write_string(indent + "if " + invalid_condition + " {\n")
    output.write_string(
      indent +
      "  raise ConversionError::InvalidValue(\n" +
      indent +
      "    path=" +
      path_expression +
      ",\n" +
      indent +
      "    constraint=\"" +
      constraint +
      "\",\n" +
      indent +
      "    actual=" +
      actual_expression +
      ".to_string(),\n" +
      indent +
      "  )\n" +
      indent +
      "}\n",
    )
  }
}

///|
fn write_prefix_error_helper(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_prefix_error(\n  error : ConversionError,\n  prefix : String,\n) -> ConversionError {\n  match error {\n    ConversionError::TypeMismatch(path~, expected~, actual~) =>\n      ConversionError::TypeMismatch(\n        path=prefix + path,\n        expected~,\n        actual~,\n      )\n    ConversionError::InvalidValue(path~, constraint~, actual~) =>\n      ConversionError::InvalidValue(\n        path=prefix + path,\n        constraint~,\n        actual~,\n      )\n    ConversionError::MissingRequiredField(path~) =>\n      ConversionError::MissingRequiredField(path=prefix + path)\n    ConversionError::DuplicateField(path~) =>\n      ConversionError::DuplicateField(path=prefix + path)\n    ConversionError::FieldOccurrenceMismatch(path~, expected~, actual~) =>\n      ConversionError::FieldOccurrenceMismatch(path=prefix + path, expected~, actual~)\n    ConversionError::UnknownField(path~) =>\n      ConversionError::UnknownField(path=prefix + path)\n    ConversionError::UnknownSymbol(path~, sid~) =>\n      ConversionError::UnknownSymbol(path=prefix + path, sid~)\n    ConversionError::NullNotAllowed(path~) =>\n      ConversionError::NullNotAllowed(path=prefix + path)\n    ConversionError::AnnotatedValueNotSupported(path~) =>\n      ConversionError::AnnotatedValueNotSupported(path=prefix + path)\n  }\n}\n",
  )
}

///|
fn write_struct_conversions(
  output : StringBuilder,
  named_type : NamedType,
  fields : Array[FieldSpec],
  is_open : Bool,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let name = moonbit_type_identifier(named_type.name)
  let visibility = if named_type.is_inline { "fn " } else { "pub fn " }
  output.write_string("///|\n/// Convert an Ion struct to ")
  output.write_string(name)
  output.write_string(" with field-level diagnostics.\n")
  output.write_string(visibility)
  output.write_string(name)
  output.write_string("::from_ion(\n  value : @ion_model.IonValue,\n) -> ")
  output.write_string(name)
  output.write_string(" raise ConversionError {\n")
  output.write_string("  let type_path = \"")
  output.write_string(named_type.name)
  output.write_string("\"\n")
  output.write_string(
    "  if value.is_null() {\n    raise ConversionError::NullNotAllowed(path=type_path)\n  }\n",
  )
  output.write_string(
    "  if value.annotations().length() > 0 {\n    raise ConversionError::AnnotatedValueNotSupported(path=type_path)\n  }\n",
  )
  output.write_string(
    "  let input_fields = match value.without_annotations() {\n    @ion_model.IonValue::Struct(fields) => fields\n    _ => raise ConversionError::TypeMismatch(path=type_path, expected=\"struct\", actual=ion_schema_codegen_actual_type(value))\n  }\n",
  )
  match named_type.contains_values {
    Some(required) =>
      write_contains_check(
        output, required, "ion_schema_codegen_struct_field_values(input_fields)",
        "type_path", "  ",
      )
    None => ()
  }
  match named_type.element_type {
    Some(element_type) =>
      write_struct_element_checks(
        output, element_type, types, "input_fields", "type_path", "  ",
      )
    None => ()
  }
  match named_type.field_names_type {
    Some(field_names_type) =>
      write_field_names_checks(
        output,
        named_type,
        field_names_type,
        named_type.field_names_distinct,
        types,
        "input_fields",
        "type_path",
        "  ",
      )
    None => ()
  }
  if named_type.element_distinct {
    write_distinct_struct_check(
      output, named_type, "input_fields", "type_path", "  ",
    )
  }
  write_integer_range_checks(
    output,
    named_type.container_lengths,
    "input_fields.length()",
    "type_path",
    "container_length",
    "  ",
  )
  if is_open {
    output.write_string(
      "  let ion_schema_codegen_open_content : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []\n",
    )
  }
  let mut i = 0
  for field in fields {
    output.write_string(
      if is_repeated_field(field.occurrence) {
        "  let input_field_"
      } else {
        "  let mut input_field_"
      },
    )
    output.write_string(i.to_string())
    if is_repeated_field(field.occurrence) {
      output.write_string(" : Array[@ion_model.IonValue] = []\n")
    } else {
      output.write_string(" : @ion_model.IonValue? = None\n")
    }
    i += 1
  }
  output.write_string(
    "  for (field_symbol, field_value) in input_fields {\n    match field_symbol.text_value() {\n      Some(field_name) =>\n        match field_name {\n",
  )
  i = 0
  for field in fields {
    output.write_string("          \"")
    output.write_string(field.name)
    output.write_string("\" => ")
    output.write_string("input_field_")
    output.write_string(i.to_string())
    if is_repeated_field(field.occurrence) {
      output.write_string(".push(field_value)\n")
    } else {
      output.write_string(" = match input_field_")
      output.write_string(i.to_string())
      output.write_string(
        " {\n            Some(_) =>\n              raise ConversionError::DuplicateField(\n                path=\"",
      )
      output.write_string(named_type.name)
      output.write_char('.')
      output.write_string(field.name)
      output.write_string(
        "\",\n              )\n            None => Some(field_value)\n          }\n",
      )
    }
    i += 1
  }
  if is_open {
    output.write_string(
      "          _ => ion_schema_codegen_open_content.push((field_symbol, field_value))\n        }\n      None => ion_schema_codegen_open_content.push((field_symbol, field_value))\n    }\n  }\n",
    )
  } else {
    output.write_string(
      "          _ => raise ConversionError::UnknownField(path=\"",
    )
    output.write_string(named_type.name)
    output.write_string(
      ".\" + field_name)\n        }\n      None => raise ConversionError::UnknownSymbol(path=\"",
    )
    output.write_string(named_type.name)
    output.write_string(
      ".<field>\", sid=field_symbol.sid_value().unwrap_or(0))\n    }\n  }\n",
    )
  }

  let locals = generated_value_local_prefix(fields)
  i = 0
  for field in fields {
    let index = i.to_string()
    let field_local = locals + index
    let ion_type = expected_ion_type(field.type_ref, types)
    let base_type = moonbit_type_for_reference_in(
      field.type_ref,
      types,
      "field \{named_type.name}.\{field.name}",
    )
    if is_repeated_field(field.occurrence) {
      output.write_string("  let field_count_")
      output.write_string(index)
      output.write_string(" = input_field_")
      output.write_string(index)
      output.write_string(".length()\n")
      if field.occurrence.min_count > 0 {
        output.write_string("  if field_count_")
        output.write_string(index)
        output.write_string(" < ")
        output.write_string(field.occurrence.min_count.to_string())
        output.write_string(" {\n")
        write_field_occurrence_error(
          output,
          field,
          named_type.name,
          "field_count_" + index,
          "    ",
        )
        output.write_string("  }\n")
      }
      match field.occurrence.max_count {
        Some(maximum) => {
          output.write_string("  if field_count_")
          output.write_string(index)
          output.write_string(" > ")
          output.write_string(maximum.to_string())
          output.write_string(" {\n")
          write_field_occurrence_error(
            output,
            field,
            named_type.name,
            "field_count_" + index,
            "    ",
          )
          output.write_string("  }\n")
        }
        None => ()
      }
      output.write_string("  let ")
      output.write_string(field_local)
      output.write_string("_values : Array[")
      output.write_string(base_type)
      output.write_string("] = []\n  let mut field_index_")
      output.write_string(index)
      output.write_string(" = 0\n  for field_value in input_field_")
      output.write_string(index)
      output.write_string(" {\n    let field_path = \"")
      output.write_string(named_type.name)
      output.write_char('.')
      output.write_string(field.name)
      output.write_string("[\" + field_index_")
      output.write_string(index)
      output.write_string(".to_string() + \"]\"\n")
      write_field_item_conversion(
        output, field, types, named_type, base_type, "      ", ion_type,
      )
      output.write_string("      ")
      output.write_string(field_local)
      output.write_string("_values.push(field_item)\n      field_index_")
      output.write_string(index)
      output.write_string(" += 1\n  }\n  let ")
      output.write_string(field_local)
      output.write_string(" : Array[")
      output.write_string(base_type)
      output.write_string("] = ")
      output.write_string(field_local)
      output.write_string("_values\n")
    } else {
      output.write_string("  let ")
      output.write_string(field_local)
      output.write_string(" : ")
      output.write_string(base_type)
      if is_optional_field(field.occurrence) {
        output.write_string("?")
      }
      output.write_string(" = match input_field_")
      output.write_string(index)
      output.write_string(" {\n    Some(field_value) => {\n")
      output.write_string("      let field_path = \"")
      output.write_string(named_type.name)
      output.write_char('.')
      output.write_string(field.name)
      output.write_string("\"\n")
      write_field_item_conversion(
        output, field, types, named_type, base_type, "      ", ion_type,
      )
      output.write_string("      ")
      if is_optional_field(field.occurrence) {
        output.write_string("Some(field_item)\n")
      } else {
        output.write_string("field_item\n")
      }
      output.write_string("    }\n")
      if is_optional_field(field.occurrence) {
        output.write_string("    None => None\n")
      } else {
        output.write_string(
          "    None => raise ConversionError::MissingRequiredField(path=\"",
        )
        output.write_string(named_type.name)
        output.write_char('.')
        output.write_string(field.name)
        output.write_string("\")\n")
      }
      output.write_string("  }\n")
    }
    i += 1
  }

  write_named_type_algebra_checks(
    output, named_type, types, "value", "type_path", "  ",
  )
  output.write_string("  {")
  if fields.length() > 0 || is_open {
    output.write_string("\n")
    i = 0
    for field in fields {
      output.write_string("    ")
      output.write_string(
        moonbit_field_identifier(
          field.name,
          "field \{named_type.name}.\{field.name}",
        ),
      )
      output.write_string(": ")
      output.write_string(locals + i.to_string())
      output.write_string(",\n")
      i += 1
    }
    if is_open {
      output.write_string(
        "    ion_schema_codegen_open_content: ion_schema_codegen_open_content,\n",
      )
    }
    output.write_string("  ")
  }
  output.write_string("}\n}\n\n")
  if !named_type.is_inline {
    output.write_string("///|\n/// Convert ")
    output.write_string(name)
    output.write_string(" into an Ion struct in schema field order.\n")
    output.write_string(visibility)
    output.write_string(name)
    output.write_string("::to_ion(self : ")
    output.write_string(name)
    output.write_string(
      ") -> @ion_model.IonValue {\n  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []\n",
    )
    for field in fields {
      let identifier = moonbit_field_identifier(
        field.name,
        "field \{named_type.name}.\{field.name}",
      )
      if is_repeated_field(field.occurrence) {
        output.write_string("  for field_value in self.")
        output.write_string(identifier)
        output.write_string(" {\n")
        write_struct_field_push(
          output, field, types, named_type, "    ", "field_value",
        )
        output.write_string("  }\n")
      } else if is_optional_field(field.occurrence) {
        output.write_string("  match self.")
        output.write_string(identifier)
        output.write_string(" {\n    Some(field_value) => {\n")
        write_struct_field_push(
          output, field, types, named_type, "      ", "field_value",
        )
        output.write_string("    }\n    None => ()\n  }\n")
      } else {
        write_struct_field_push(
          output,
          field,
          types,
          named_type,
          "  ",
          "self." + identifier,
        )
      }
    }
    if is_open {
      output.write_string(
        "  for (field_symbol, field_value) in self.ion_schema_codegen_open_content {\n    output_fields.push((field_symbol, field_value))\n  }\n",
      )
    }
    output.write_string("  @ion_model.IonValue::Struct(output_fields)\n}\n")
  }
}

///|
fn is_required_field(occurrence : FieldOccurrence) -> Bool {
  occurrence.min_count == 1 && occurrence.max_count == Some(1)
}

///|
fn is_list_type(resolved : ResolvedType) -> Bool {
  match resolved {
    ResolvedType::List(_) => true
    _ => false
  }
}

///|
fn write_ordered_list_conversions(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let visibility = if named_type.is_inline { "fn " } else { "pub fn " }
  output.write_string(
    "///|\n/// Convert an Ion list to " +
    generated_name +
    " while validating its ordered elements.\n" +
    visibility +
    "from_ion_" +
    generated_name +
    "(\n  value : @ion_model.IonValue,\n) -> " +
    generated_name +
    " raise ConversionError {\n  let type_path = \"" +
    named_type.name +
    "\"\n  if value.is_null() {\n    raise ConversionError::NullNotAllowed(path=type_path)\n  }\n  if value.annotations().length() > 0 {\n    raise ConversionError::AnnotatedValueNotSupported(path=type_path)\n  }\n  let input_elements = match value.without_annotations() {\n    @ion_model.IonValue::List(elements) => elements\n    _ => raise ConversionError::TypeMismatch(path=type_path, expected=\"list\", actual=ion_schema_codegen_actual_type(value))\n  }\n",
  )
  write_ordered_list_constraint_chain(
    output,
    named_type,
    types,
    "input_elements",
    "type_path",
    "  ",
    types.length(),
  )
  write_named_type_algebra_checks(
    output, named_type, types, "value", "type_path", "  ",
  )
  output.write_string("  input_elements\n}\n\n")
  if !named_type.is_inline {
    output.write_string(
      "///|\n/// Convert " +
      generated_name +
      " into an Ion list.\n" +
      visibility +
      "to_ion_" +
      generated_name +
      "(items : " +
      generated_name +
      ") -> @ion_model.IonValue {\n  @ion_model.IonValue::List(items)\n}\n",
    )
  }
}

///|
fn write_ordered_list_constraint_chain(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  values_expression : String,
  path_expression : String,
  indent : String,
  remaining : Int,
) -> Unit raise SchemaError {
  if remaining <= 0 {
    return
  }
  write_integer_range_checks(
    output,
    named_type.container_lengths,
    values_expression + ".length()",
    path_expression,
    "container_length",
    indent,
  )
  match named_type.contains_values {
    Some(required) =>
      write_contains_check(
        output, required, values_expression, path_expression, indent,
      )
    None => ()
  }
  if named_type.element_distinct {
    write_distinct_values_check(
      output, values_expression, path_expression, indent,
    )
  }
  match named_type.element_type {
    Some(element_type) =>
      write_sequence_element_checks(
        output,
        element_type,
        types,
        values_expression,
        path_expression,
        indent,
        "ion_schema_codegen_ordered_list_" + remaining.to_string(),
      )
    None => ()
  }
  write_ordered_sequence_check(
    output, named_type, values_expression, path_expression, indent,
  )
  match named_type.body {
    TypeBody::Alias(TypeRef::Named(next)) =>
      match find_named_type(types, next) {
        Some(target) =>
          write_ordered_list_constraint_chain(
            output,
            target,
            types,
            values_expression,
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
fn write_sequence_element_checks(
  output : StringBuilder,
  element_type : TypeRef,
  types : Array[NamedType],
  values_expression : String,
  path_expression : String,
  indent : String,
  variable_prefix : String,
) -> Unit raise SchemaError {
  let index_name = variable_prefix + "_index"
  let element_name = variable_prefix + "_value"
  let element_path = variable_prefix + "_path"
  output.write_string(
    indent +
    "let mut " +
    index_name +
    " = 0\n" +
    indent +
    "for " +
    element_name +
    " in " +
    values_expression +
    " {\n" +
    indent +
    "  let " +
    element_path +
    " = " +
    path_expression +
    " + \"[\" + " +
    index_name +
    ".to_string() + \"]\"\n",
  )
  write_element_item_validation(
    output,
    element_type,
    element_name,
    types,
    element_path,
    indent + "  ",
  )
  output.write_string(indent + "  " + index_name + " += 1\n" + indent + "}\n")
}

///|
fn write_list_conversions(
  output : StringBuilder,
  named_type : NamedType,
  element_type : TypeRef,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let visibility = if named_type.is_inline { "fn " } else { "pub fn " }
  let element_moonbit_type = moonbit_type_for_reference_in(
    element_type,
    types,
    "element of \{named_type.name}",
  )
  let expected_type = expected_ion_type(element_type, types)
  let is_raw_ion_value = is_raw_ion_value_reference(element_type, types)
  let allows_null = reference_accepts_null(element_type, types)
  let needs_element_path = !is_raw_ion_value ||
    !allows_null ||
    !is_universal_any_reference(element_type, types) ||
    reference_has_valid_values(element_type, types)
  output.write_string("///|\n/// Convert an Ion list to ")
  output.write_string(generated_name)
  output.write_string(" with element-level diagnostics.\n")
  output.write_string(visibility)
  output.write_string("from_ion_")
  output.write_string(generated_name)
  output.write_string("(\n  value : @ion_model.IonValue,\n) -> ")
  output.write_string(generated_name)
  output.write_string(" raise ConversionError {\n")
  output.write_string("  let type_path = \"")
  output.write_string(named_type.name)
  output.write_string("\"\n")
  output.write_string(
    "  if value.is_null() {\n    raise ConversionError::NullNotAllowed(path=type_path)\n  }\n",
  )
  output.write_string(
    "  if value.annotations().length() > 0 {\n    raise ConversionError::AnnotatedValueNotSupported(path=type_path)\n  }\n",
  )
  output.write_string(
    "  let input_elements = match value.without_annotations() {\n    @ion_model.IonValue::List(elements) => elements\n    _ =>\n      raise ConversionError::TypeMismatch(\n        path=type_path,\n        expected=\"list\",\n        actual=ion_schema_codegen_actual_type(value),\n      )\n  }\n",
  )
  write_integer_range_checks(
    output,
    named_type.container_lengths,
    "input_elements.length()",
    "type_path",
    "container_length",
    "  ",
  )
  match named_type.contains_values {
    Some(required) =>
      write_contains_check(
        output, required, "input_elements", "type_path", "  ",
      )
    None => ()
  }
  if named_type.element_distinct {
    write_distinct_values_check(output, "input_elements", "type_path", "  ")
  }
  output.write_string("  let converted : ")
  output.write_string(generated_name)
  output.write_string(" = []\n")
  if needs_element_path {
    output.write_string("  let mut index = 0\n")
  }
  output.write_string("  for element in input_elements {\n")
  if needs_element_path {
    output.write_string(
      "    let element_path = type_path + \"[\" + index.to_string() + \"]\"\n",
    )
  }
  if !is_raw_ion_value && !reference_has_valid_values(element_type, types) {
    output.write_string(
      "    if element.annotations().length() > 0 {\n      raise ConversionError::AnnotatedValueNotSupported(path=element_path)\n    }\n",
    )
  }
  if !allows_null {
    output.write_string(
      "    if element.is_null() {\n      raise ConversionError::NullNotAllowed(path=element_path)\n    }\n",
    )
  }
  output.write_string("    let item : ")
  output.write_string(element_moonbit_type)
  output.write_string(" = ")
  if is_null_or_type_ref(element_type) {
    output.write_string(
      "if ion_schema_codegen_matches_type(element, \"$null\") {\n  element\n} else {\n",
    )
    write_type_validation_with_path_expression(
      output,
      nullable_inner_type_ref(element_type),
      "element",
      types,
      "element_path",
      "  ",
    )
    output.write_string("  element\n}\n")
  } else {
    match resolve_type_ref(types, element_type) {
      ResolvedType::Scalar("any" | "$any") => output.write_string("element\n")
      ResolvedType::Scalar("number") =>
        write_scalar_type_value(output, "element", "number", "element_path", "")
      ResolvedType::Scalar(scalar_name) if scalar_name.has_prefix("$") =>
        write_scalar_type_value(
          output, "element", scalar_name, "element_path", "",
        )
      ResolvedType::Scalar(scalar_name) => {
        output.write_string("match element.without_annotations() {\n      ")
        output.write_string(ion_value_variant(scalar_name))
        output.write_string(
          "(item) => item\n      _ =>\n        raise ConversionError::TypeMismatch(\n          path=element_path,\n          expected=\"",
        )
        output.write_string(expected_type)
        output.write_string(
          "\",\n          actual=ion_schema_codegen_actual_type(element),\n        )\n    }\n",
        )
      }
      ResolvedType::Struct(_) | ResolvedType::List(_) =>
        output.write_string(
          ion_from_expression(
            element_type, "element", types, "element_path + \".\"",
          ) +
          "\n",
        )
    }
  }
  write_reference_valid_values_checks(
    output, element_type, types, "element", "element_path", "    ",
  )
  output.write_string("    converted.push(item)\n")
  if needs_element_path {
    output.write_string("    index += 1\n")
  }
  output.write_string("  }\n")
  write_named_type_algebra_checks(
    output, named_type, types, "value", "type_path", "  ",
  )
  output.write_string("  converted\n}\n\n")

  if !named_type.is_inline {
    output.write_string("///|\n/// Convert ")
    output.write_string(generated_name)
    output.write_string(" into an Ion list.\n")
    output.write_string(visibility)
    output.write_string("to_ion_")
    output.write_string(generated_name)
    output.write_string("(items : ")
    output.write_string(generated_name)
    output.write_string(
      ") -> @ion_model.IonValue {\n  let output_elements : Array[@ion_model.IonValue] = []\n  for element in items {\n    output_elements.push(",
    )
    output.write_string(ion_value_expression(element_type, "element", types))
    output.write_string(
      ")\n  }\n  @ion_model.IonValue::List(output_elements)\n}\n",
    )
  }
}

///|
fn generated_value_local_prefix(
  fields : Array[FieldSpec],
) -> String raise SchemaError {
  let mut prefix = "ion_schema_codegen_value_"
  let mut has_collision = true
  while has_collision {
    has_collision = false
    let mut value_index = 0
    for _field in fields {
      let local_name = prefix + value_index.to_string()
      let mut field_index = 0
      for field in fields {
        let field_identifier = moonbit_field_identifier(
          field.name,
          "field \{field.name}",
        )
        if field_identifier == local_name {
          has_collision = true
        }
        if "input_field_" + field_index.to_string() == local_name {
          has_collision = true
        }
        field_index += 1
      }
      value_index += 1
    }
    if has_collision {
      prefix = prefix + "_"
    }
  }
  prefix
}

///|
fn is_optional_field(occurrence : FieldOccurrence) -> Bool {
  occurrence.min_count == 0 && occurrence.max_count == Some(1)
}

///|
fn is_repeated_field(occurrence : FieldOccurrence) -> Bool {
  !is_required_field(occurrence) && !is_optional_field(occurrence)
}

///|
fn field_item_needs_path(
  field : FieldSpec,
  types : Array[NamedType],
) -> Bool raise SchemaError {
  if is_null_or_type_ref(field.type_ref) {
    return true
  }
  let raw = is_raw_ion_value_reference(field.type_ref, types)
  let allows_null = reference_accepts_null(field.type_ref, types)
  if !raw || !allows_null || reference_has_valid_values(field.type_ref, types) {
    return true
  }
  match resolve_type_ref(types, field.type_ref) {
    ResolvedType::Scalar(name) => name.has_prefix("$") && name != "$any"
    _ => false
  }
}

///|
fn occurrence_expected_text(occurrence : FieldOccurrence) -> String {
  match occurrence.max_count {
    Some(maximum) if maximum == occurrence.min_count =>
      occurrence.min_count.to_string()
    Some(maximum) =>
      occurrence.min_count.to_string() + ".." + maximum.to_string()
    None => occurrence.min_count.to_string() + "+"
  }
}

///|
fn write_field_occurrence_error(
  output : StringBuilder,
  field : FieldSpec,
  type_name : String,
  actual_expression : String,
  indent : String,
) -> Unit {
  output.write_string(
    indent +
    "raise ConversionError::FieldOccurrenceMismatch(\n" +
    indent +
    "  path=\"" +
    type_name +
    "." +
    field.name +
    "\",\n" +
    indent +
    "  expected=\"" +
    occurrence_expected_text(field.occurrence) +
    "\",\n" +
    indent +
    "  actual=" +
    actual_expression +
    ",\n" +
    indent +
    ")\n",
  )
}

///|
fn write_field_item_conversion(
  output : StringBuilder,
  field : FieldSpec,
  types : Array[NamedType],
  named_type : NamedType,
  base_type : String,
  indent : String,
  ion_type : String,
) -> Unit raise SchemaError {
  let raw = is_raw_ion_value_reference(field.type_ref, types)
  let allows_null = reference_accepts_null(field.type_ref, types)
  if !field_item_needs_path(field, types) {
    output.write_string(indent + "let _ = field_path\n")
  }
  if !raw && !reference_has_valid_values(field.type_ref, types) {
    output.write_string(
      indent +
      "if field_value.annotations().length() > 0 {\n" +
      indent +
      "  raise ConversionError::AnnotatedValueNotSupported(path=field_path)\n" +
      indent +
      "}\n",
    )
  }
  if !allows_null {
    output.write_string(
      indent +
      "if field_value.is_null() {\n" +
      indent +
      "  raise ConversionError::NullNotAllowed(path=field_path)\n" +
      indent +
      "}\n",
    )
  }
  output.write_string(indent + "let field_item : " + base_type + " = ")
  if is_null_or_type_ref(field.type_ref) {
    output.write_string(
      "if ion_schema_codegen_matches_type(field_value, \"$null\") {\n",
    )
    output.write_string(indent + "  field_value\n" + indent + "} else {\n")
    write_type_validation_with_path_expression(
      output,
      nullable_inner_type_ref(field.type_ref),
      "field_value",
      types,
      "field_path",
      indent + "  ",
    )
    output.write_string(indent + "  field_value\n" + indent + "}\n")
  } else {
    match resolve_type_ref(types, field.type_ref) {
      ResolvedType::Scalar("any" | "$any") =>
        output.write_string("field_value\n")
      ResolvedType::Scalar("number") =>
        write_scalar_type_value(
          output, "field_value", "number", "field_path", "",
        )
      ResolvedType::Scalar(scalar_name) if scalar_name.has_prefix("$") =>
        write_scalar_type_value(
          output, "field_value", scalar_name, "field_path", "",
        )
      ResolvedType::Scalar(scalar_name) => {
        output.write_string("match field_value.without_annotations() {\n  ")
        output.write_string(ion_value_variant(scalar_name))
        output.write_string(
          "(converted_value) => converted_value\n  _ => raise ConversionError::TypeMismatch(\n    path=field_path,\n    expected=\"",
        )
        output.write_string(ion_type)
        output.write_string(
          "\",\n    actual=ion_schema_codegen_actual_type(field_value),\n  )\n}\n",
        )
      }
      ResolvedType::Struct(_) | ResolvedType::List(_) =>
        output.write_string(
          ion_from_expression(
            field.type_ref,
            "field_value",
            types,
            "field_path + \".\"",
          ) +
          "\n",
        )
    }
  }
  write_reference_valid_values_checks(
    output,
    field.type_ref,
    types,
    "field_value",
    "field_path",
    indent,
  )
  ignore(named_type)
}

///|
fn write_struct_field_push(
  output : StringBuilder,
  field : FieldSpec,
  types : Array[NamedType],
  named_type : NamedType,
  indent : String,
  value_expression : String,
) -> Unit raise SchemaError {
  output.write_string(indent + "output_fields.push(\n")
  output.write_string(
    indent + "  (@ion_model.IonSymbol::from_text(\"" + field.name + "\"),\n",
  )
  output.write_string(
    indent +
    "    " +
    ion_value_expression(field.type_ref, value_expression, types) +
    "),\n" +
    indent +
    ")\n",
  )
  ignore(named_type)
}

///|
fn is_null_or_type_ref(type_ref : TypeRef) -> Bool {
  match type_ref {
    TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) => true
    _ => false
  }
}

///|
fn is_raw_ion_value_reference(
  type_ref : TypeRef,
  types : Array[NamedType],
) -> Bool raise SchemaError {
  if is_null_or_type_ref(type_ref) {
    return true
  }
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar("any" | "$any" | "number") => true
    ResolvedType::Scalar(name) => name.has_prefix("$")
    _ => false
  }
}

///|
fn reference_accepts_null(
  type_ref : TypeRef,
  types : Array[NamedType],
) -> Bool raise SchemaError {
  if is_null_or_type_ref(type_ref) {
    return true
  }
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar("$any") => true
    ResolvedType::Scalar(name) => name.has_prefix("$")
    _ => false
  }
}

///|
fn is_universal_any_reference(
  type_ref : TypeRef,
  types : Array[NamedType],
) -> Bool raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar("$any") => true
    _ => false
  }
}

///|
fn uses_nullable_type_checks(
  types : Array[NamedType],
) -> Bool raise SchemaError {
  for named_type in types {
    match named_type.ordered_elements {
      Some(ordered_elements) =>
        for ordered_element in ordered_elements {
          if needs_nullable_type_check(ordered_element.type_ref, types) {
            return true
          }
        }
      None => ()
    }
    match named_type.element_type {
      Some(type_ref) if needs_nullable_type_check(type_ref, types) =>
        return true
      _ => ()
    }
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        if needs_nullable_type_check(type_ref, types) {
          return true
        }
      TypeBody::Struct(fields, _) =>
        for field in fields {
          if needs_nullable_type_check(field.type_ref, types) {
            return true
          }
        }
      TypeBody::List(type_ref) =>
        if needs_nullable_type_check(type_ref, types) {
          return true
        }
    }
  }
  false
}

///|
fn needs_nullable_type_check(
  type_ref : TypeRef,
  types : Array[NamedType],
) -> Bool raise SchemaError {
  if is_null_or_type_ref(type_ref) {
    return true
  }
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar(name) => name.has_prefix("$") && name != "$any"
    _ => false
  }
}

///|
fn nullable_inner_type_ref(type_ref : TypeRef) -> TypeRef {
  match type_ref {
    TypeRef::NullOrBuiltin(name) => TypeRef::Builtin(name)
    TypeRef::NullOrNamed(name) => TypeRef::Named(name)
    _ => type_ref
  }
}

///|
fn write_scalar_type_check_with_path_expression(
  output : StringBuilder,
  value_expression : String,
  expected : String,
  path_expression : String,
  indent : String,
) -> Unit {
  output.write_string(
    indent +
    "if !ion_schema_codegen_matches_type(" +
    value_expression +
    ", \"" +
    expected +
    "\") {\n" +
    indent +
    "  raise ConversionError::TypeMismatch(\n" +
    indent +
    "    path=" +
    path_expression +
    ",\n" +
    indent +
    "    expected=\"" +
    expected +
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
fn write_scalar_type_value(
  output : StringBuilder,
  value_expression : String,
  expected : String,
  path_expression : String,
  indent : String,
) -> Unit {
  output.write_string(
    indent +
    "if ion_schema_codegen_matches_type(" +
    value_expression +
    ", \"" +
    expected +
    "\") {\n" +
    indent +
    "  " +
    value_expression +
    "\n" +
    indent +
    "} else {\n" +
    indent +
    "  raise ConversionError::TypeMismatch(\n" +
    indent +
    "    path=" +
    path_expression +
    ",\n" +
    indent +
    "    expected=\"" +
    expected +
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
fn write_type_validation_with_path_expression(
  output : StringBuilder,
  type_ref : TypeRef,
  value_expression : String,
  types : Array[NamedType],
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar(name) =>
      write_scalar_type_check_with_path_expression(
        output, value_expression, name, path_expression, indent,
      )
    ResolvedType::Struct(_) | ResolvedType::List(_) => {
      output.write_string(indent + "let _ = ")
      output.write_string(
        ion_from_expression(
          type_ref,
          value_expression,
          types,
          path_expression + " + \".\"",
        ),
      )
      output.write_char('\n')
    }
  }
}

///|
fn ion_value_variant(name : String) -> String raise SchemaError {
  match name {
    "bool" => "@ion_model.IonValue::Bool"
    "int" => "@ion_model.IonValue::Int"
    "float" => "@ion_model.IonValue::Float"
    "decimal" => "@ion_model.IonValue::Decimal"
    "string" => "@ion_model.IonValue::String"
    "symbol" => "@ion_model.IonValue::Symbol"
    "timestamp" => "@ion_model.IonValue::Timestamp"
    "blob" => "@ion_model.IonValue::Blob"
    "clob" => "@ion_model.IonValue::Clob"
    "sexp" => "@ion_model.IonValue::Sexp"
    _ =>
      raise SchemaError::UnsupportedFeature(
        "no Ion value mapping for scalar type \{name}",
      )
  }
}

///|
priv enum ResolvedType {
  Scalar(String)
  Struct(String)
  List(String)
}

///|
fn moonbit_type_for_reference_in(
  type_ref : TypeRef,
  types : Array[NamedType],
  context : String,
) -> String raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => moonbit_type_for_builtin(name, context)
    TypeRef::Named(name) => {
      ignore(find_named_type(types, name))
      moonbit_type_identifier(name)
    }
    TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) => "@ion_model.IonValue"
  }
}

///|
fn find_named_type(types : Array[NamedType], name : String) -> NamedType? {
  for named_type in types {
    if named_type.name == name {
      return Some(named_type)
    }
  }
  None
}

///|
fn resolve_type_ref(
  types : Array[NamedType],
  type_ref : TypeRef,
) -> ResolvedType raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => ResolvedType::Scalar(name)
    TypeRef::Named(name) =>
      match find_named_type(types, name) {
        Some(named_type) =>
          match named_type.body {
            TypeBody::Scalar(target) | TypeBody::Alias(target) =>
              resolve_type_ref(types, target)
            TypeBody::Struct(_, _) => ResolvedType::Struct(name)
            TypeBody::List(_) => ResolvedType::List(name)
          }
        None => raise SchemaError::UnknownType("unknown type \{name}")
      }
    TypeRef::NullOrBuiltin(name) => ResolvedType::Scalar(name)
    TypeRef::NullOrNamed(name) => resolve_type_ref(types, TypeRef::Named(name))
  }
}

///|
fn expected_ion_type(
  type_ref : TypeRef,
  types : Array[NamedType],
) -> String raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar(name) => name
    ResolvedType::Struct(_) => "struct"
    ResolvedType::List(_) => "list"
  }
}

///|
fn ion_from_expression(
  type_ref : TypeRef,
  value_expression : String,
  types : Array[NamedType],
  error_prefix : String,
) -> String raise SchemaError {
  let ordered_conversion_name = match type_ref {
    TypeRef::Named(name) =>
      match find_named_type(types, name) {
        Some(named_type) if named_type.ordered_elements is Some(_) &&
          is_list_type(resolve_type_ref(types, type_ref)) =>
          Some(moonbit_type_identifier(named_type.name))
        _ => None
      }
    _ => None
  }
  let from_expression = match ordered_conversion_name {
    Some(name) => "from_ion_" + name + "(" + value_expression + ")"
    None =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Struct(name) =>
          moonbit_type_identifier(name) + "::from_ion(" + value_expression + ")"
        ResolvedType::List(name) =>
          "from_ion_" +
          moonbit_type_identifier(name) +
          "(" +
          value_expression +
          ")"
        ResolvedType::Scalar(_) =>
          raise SchemaError::UnsupportedFeature(
            "internal named conversion requested for scalar type",
          )
      }
  }
  "try " +
  from_expression +
  " catch { error =>\n  raise ion_schema_codegen_prefix_error(error, " +
  error_prefix +
  ")\n}"
}

///|
fn ion_value_expression(
  type_ref : TypeRef,
  value_expression : String,
  types : Array[NamedType],
) -> String raise SchemaError {
  let ordered_conversion_name = match type_ref {
    TypeRef::Named(name) =>
      match find_named_type(types, name) {
        Some(named_type) if named_type.ordered_elements is Some(_) &&
          is_list_type(resolve_type_ref(types, type_ref)) =>
          Some(moonbit_type_identifier(named_type.name))
        _ => None
      }
    _ => None
  }
  match ordered_conversion_name {
    Some(name) => "to_ion_" + name + "(" + value_expression + ")"
    None =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar("any" | "$any" | "number") => value_expression
        ResolvedType::Scalar(name) if name.has_prefix("$") => value_expression
        _ if is_null_or_type_ref(type_ref) => value_expression
        ResolvedType::Scalar("document") =>
          raise SchemaError::UnsupportedFeature(
            "document streams cannot be embedded as a single Ion value",
          )
        ResolvedType::Scalar(name) =>
          ion_value_variant(name) + "(" + value_expression + ")"
        ResolvedType::Struct(name) =>
          moonbit_type_identifier(name) + "::to_ion(" + value_expression + ")"
        ResolvedType::List(name) =>
          "to_ion_" +
          moonbit_type_identifier(name) +
          "(" +
          value_expression +
          ")"
      }
  }
}

///|
fn order_named_types(
  types : Array[NamedType],
) -> Array[NamedType] raise SchemaError {
  let ordered : Array[NamedType] = []
  let visited : Array[String] = []
  for named_type in types {
    visit_named_type(named_type.name, types, [], visited, ordered)
  }
  ordered
}

///|
fn visit_named_type(
  name : String,
  types : Array[NamedType],
  path : Array[String],
  visited : Array[String],
  ordered : Array[NamedType],
) -> Unit raise SchemaError {
  if contains_string(visited, name) {
    return
  }
  if contains_string(path, name) {
    return
  }
  let named_type = match find_named_type(types, name) {
    Some(found) => found
    None => raise SchemaError::UnknownType("unknown type \{name}")
  }
  let next_path : Array[String] = []
  for item in path {
    next_path.push(item)
  }
  next_path.push(name)
  for dependency in referenced_type_names(named_type, true) {
    visit_named_type(dependency, types, next_path, visited, ordered)
  }
  visited.push(name)
  ordered.push(named_type)
}

///|
fn validate_unguarded_type_cycles(
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let visited : Array[String] = []
  for named_type in types {
    visit_unguarded_type_reference(named_type.name, types, [], visited)
  }
}

///|
fn validate_recursive_alias_cycles(
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let visited : Array[String] = []
  for named_type in types {
    visit_recursive_alias_reference(named_type.name, types, [], visited)
  }
}

///|
fn visit_recursive_alias_reference(
  name : String,
  types : Array[NamedType],
  path : Array[String],
  visited : Array[String],
) -> Unit raise SchemaError {
  if contains_string(visited, name) {
    return
  }
  if contains_string(path, name) {
    raise SchemaError::CyclicTypeReference(
      type_reference_cycle_chain(path, name),
    )
  }
  let named_type = match find_named_type(types, name) {
    Some(found) => found
    None => raise SchemaError::UnknownType("unknown type \{name}")
  }
  let next_path : Array[String] = []
  for item in path {
    next_path.push(item)
  }
  next_path.push(name)
  let dependency = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match type_ref {
        TypeRef::Named(target) => Some(target)
        TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => None
        TypeRef::NullOrNamed(target) => Some(target)
      }
    TypeBody::List(type_ref) =>
      match type_ref {
        TypeRef::Named(target) | TypeRef::NullOrNamed(target) => Some(target)
        TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => None
      }
    TypeBody::Struct(_, _) => None
  }
  match dependency {
    Some(target) =>
      visit_recursive_alias_reference(target, types, next_path, visited)
    None => ()
  }
  visited.push(name)
}

///|
fn visit_unguarded_type_reference(
  name : String,
  types : Array[NamedType],
  path : Array[String],
  visited : Array[String],
) -> Unit raise SchemaError {
  if contains_string(visited, name) {
    return
  }
  if contains_string(path, name) {
    raise SchemaError::CyclicTypeReference(
      type_reference_cycle_chain(path, name),
    )
  }
  let named_type = match find_named_type(types, name) {
    Some(found) => found
    None => raise SchemaError::UnknownType("unknown type \{name}")
  }
  let next_path : Array[String] = []
  for item in path {
    next_path.push(item)
  }
  next_path.push(name)
  for dependency in referenced_type_names(named_type, false) {
    visit_unguarded_type_reference(dependency, types, next_path, visited)
  }
  visited.push(name)
}

///|
fn type_reference_cycle_chain(path : Array[String], name : String) -> String {
  let mut start = 0
  let mut index = 0
  for item in path {
    if item == name {
      start = index
      break
    }
    index += 1
  }
  let chain = StringBuilder()
  index = 0
  for item in path {
    if index >= start {
      if chain.to_string() != "" {
        chain.write_string(" -> ")
      }
      chain.write_string(item)
    }
    index += 1
  }
  chain.write_string(" -> ")
  chain.write_string(name)
  chain.to_string()
}

///|
fn referenced_type_names(
  named_type : NamedType,
  include_guarded_body_edges : Bool,
) -> Array[String] {
  let names : Array[String] = []
  match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match type_ref {
        TypeRef::Named(name) => names.push(name)
        TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
        TypeRef::NullOrNamed(name) =>
          if include_guarded_body_edges {
            names.push(name)
          }
      }
    TypeBody::List(type_ref) =>
      if include_guarded_body_edges {
        push_named_type_reference(names, type_ref)
      }
    TypeBody::Struct(fields, _) =>
      for field in fields {
        if include_guarded_body_edges ||
          (
            field.occurrence.min_count > 0 &&
            !is_nullable_type_reference(field.type_ref)
          ) {
          push_named_type_reference(names, field.type_ref)
        }
      }
  }
  match named_type.element_type {
    Some(type_ref) if !is_list_body(named_type.body) =>
      push_named_type_reference(names, type_ref)
    Some(_) | None => ()
  }
  match named_type.field_names_type {
    Some(TypeRef::Named(name) | TypeRef::NullOrNamed(name)) => names.push(name)
    Some(TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_)) | None => ()
  }
  match named_type.ordered_elements {
    Some(ordered_elements) =>
      for ordered_element in ordered_elements {
        match ordered_element.type_ref {
          TypeRef::Named(name) | TypeRef::NullOrNamed(name) => names.push(name)
          TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
        }
      }
    None => ()
  }
  for type_ref in named_type.all_of {
    match type_ref {
      TypeRef::Named(name) | TypeRef::NullOrNamed(name) => names.push(name)
      TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
    }
  }
  for branches in named_type.any_of {
    for type_ref in branches {
      match type_ref {
        TypeRef::Named(name) | TypeRef::NullOrNamed(name) => names.push(name)
        TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
      }
    }
  }
  for branches in named_type.one_of {
    for type_ref in branches {
      match type_ref {
        TypeRef::Named(name) | TypeRef::NullOrNamed(name) => names.push(name)
        TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
      }
    }
  }
  for type_ref in named_type.not_constraints {
    match type_ref {
      TypeRef::Named(name) | TypeRef::NullOrNamed(name) => names.push(name)
      TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
    }
  }
  for constraint in named_type.annotation_constraints {
    match constraint.standard_type_ref {
      Some(TypeRef::Named(name) | TypeRef::NullOrNamed(name)) =>
        names.push(name)
      Some(TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_)) | None => ()
    }
    match constraint.standard_ordered_elements {
      Some(ordered_elements) =>
        for ordered_element in ordered_elements {
          match ordered_element.type_ref {
            TypeRef::Named(name) | TypeRef::NullOrNamed(name) =>
              names.push(name)
            TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
          }
        }
      None => ()
    }
  }
  names
}

///|
fn push_named_type_reference(names : Array[String], type_ref : TypeRef) -> Unit {
  match type_ref {
    TypeRef::Named(name) | TypeRef::NullOrNamed(name) => names.push(name)
    TypeRef::Builtin(_) | TypeRef::NullOrBuiltin(_) => ()
  }
}

///|
fn is_nullable_type_reference(type_ref : TypeRef) -> Bool {
  match type_ref {
    TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) => true
    TypeRef::Builtin(_) | TypeRef::Named(_) => false
  }
}

///|
fn is_list_body(body : TypeBody) -> Bool {
  match body {
    TypeBody::List(_) => true
    TypeBody::Scalar(_) | TypeBody::Alias(_) | TypeBody::Struct(_, _) => false
  }
}

///|
fn moonbit_type_for_builtin(
  name : String,
  context : String,
) -> String raise SchemaError {
  match name {
    "bool" => "Bool"
    "int" => "@bigint.BigInt"
    "float" => "Float"
    "decimal" => "@ion_model.IonDecimal"
    "string" => "String"
    "symbol" => "@ion_model.IonSymbol"
    "timestamp" => "@ion_model.IonTimestamp"
    "blob" | "clob" => "Bytes"
    "sexp" => "Array[@ion_model.IonValue]"
    "any" | "$any" | "number" => "@ion_model.IonValue"
    "$null"
    | "$bool"
    | "$int"
    | "$float"
    | "$decimal"
    | "$string"
    | "$symbol"
    | "$timestamp"
    | "$blob"
    | "$clob"
    | "$list"
    | "$sexp"
    | "$struct"
    | "$number"
    | "$text"
    | "$lob" => "@ion_model.IonValue"
    "document" => "Array[@ion_model.IonValue]"
    _ =>
      raise SchemaError::UnsupportedFeature(
        "no MoonBit type mapping for \{name} at \{context}",
      )
  }
}

///|
fn uses_bigint(types : Array[NamedType]) -> Bool raise SchemaError {
  for named_type in types {
    match named_type.ordered_elements {
      Some(ordered_elements) =>
        for ordered_element in ordered_elements {
          let type_ref = ordered_element.type_ref
          if matches_int(resolve_type_ref(types, type_ref)) &&
            !is_raw_ion_value_reference(type_ref, types) {
            return true
          }
        }
      None => ()
    }
    for constraint in named_type.annotation_constraints {
      match constraint.standard_type_ref {
        Some(type_ref) if needs_nullable_type_check(type_ref, types) =>
          return true
        _ => ()
      }
      match constraint.standard_ordered_elements {
        Some(ordered_elements) =>
          for ordered_element in ordered_elements {
            if needs_nullable_type_check(ordered_element.type_ref, types) {
              return true
            }
          }
        None => ()
      }
    }
    match named_type.element_type {
      Some(type_ref) if matches_int(resolve_type_ref(types, type_ref)) &&
        !is_raw_ion_value_reference(type_ref, types) => return true
      _ => ()
    }
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        if matches_int(resolve_type_ref(types, type_ref)) &&
          !is_raw_ion_value_reference(type_ref, types) {
          return true
        }
      TypeBody::Struct(fields, _) =>
        for field in fields {
          if matches_int(resolve_type_ref(types, field.type_ref)) &&
            !is_raw_ion_value_reference(field.type_ref, types) {
            return true
          }
        }
      TypeBody::List(type_ref) =>
        if matches_int(resolve_type_ref(types, type_ref)) &&
          !is_raw_ion_value_reference(type_ref, types) {
          return true
        }
    }
  }
  false
}

///|
fn uses_model_types(types : Array[NamedType]) -> Bool raise SchemaError {
  for named_type in types {
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        if is_raw_ion_value_reference(type_ref, types) ||
          matches_model_type(resolve_type_ref(types, type_ref)) {
          return true
        }
      TypeBody::Struct(_, _) => return true
      TypeBody::List(_) => return true
    }
  }
  false
}

///|
fn has_conversion_types(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.valid_values is Some(_) ||
      named_type.precision_ranges.length() > 0 ||
      named_type.exponent_ranges.length() > 0 ||
      named_type.timestamp_precision_ranges.length() > 0 ||
      named_type.timestamp_offsets.length() > 0 ||
      named_type.ieee754_float_formats.length() > 0 ||
      named_type.regex_constraints.length() > 0 ||
      named_type.annotation_constraints.length() > 0 ||
      named_type.all_of.length() > 0 ||
      named_type.any_of.length() > 0 ||
      named_type.one_of.length() > 0 ||
      named_type.not_constraints.length() > 0 ||
      named_type.container_lengths.length() > 0 ||
      named_type.element_type is Some(_) ||
      has_named_contains_values(named_type) ||
      named_type.field_names_type is Some(_) ||
      named_type.ordered_elements is Some(_) ||
      named_type.codepoint_lengths.length() > 0 ||
      named_type.utf8_byte_lengths.length() > 0 ||
      named_type.byte_lengths.length() > 0 {
      return true
    }
    match named_type.body {
      TypeBody::Struct(_, _) | TypeBody::List(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn has_nested_conversion_types(
  types : Array[NamedType],
) -> Bool raise SchemaError {
  for named_type in types {
    match named_type.ordered_elements {
      Some(ordered_elements) =>
        for ordered_element in ordered_elements {
          match resolve_type_ref(types, ordered_element.type_ref) {
            ResolvedType::Struct(_) | ResolvedType::List(_) => return true
            ResolvedType::Scalar(_) => ()
          }
        }
      None => ()
    }
    match named_type.element_type {
      Some(element_type) =>
        match resolve_type_ref(types, element_type) {
          ResolvedType::Struct(_) | ResolvedType::List(_) => return true
          ResolvedType::Scalar(_) => ()
        }
      None => ()
    }
    match named_type.field_names_type {
      Some(field_names_type) =>
        match resolve_type_ref(types, field_names_type) {
          ResolvedType::Struct(_) | ResolvedType::List(_) => return true
          ResolvedType::Scalar(_) => ()
        }
      None => ()
    }
    match named_type.body {
      TypeBody::Struct(fields, _) =>
        for field in fields {
          match resolve_type_ref(types, field.type_ref) {
            ResolvedType::Struct(_) | ResolvedType::List(_) => return true
            ResolvedType::Scalar(_) => ()
          }
        }
      TypeBody::List(element_type) =>
        match resolve_type_ref(types, element_type) {
          ResolvedType::Struct(_) | ResolvedType::List(_) => return true
          ResolvedType::Scalar(_) => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn matches_int(resolved : ResolvedType) -> Bool {
  match resolved {
    ResolvedType::Scalar("int") => true
    _ => false
  }
}

///|
fn matches_model_type(resolved : ResolvedType) -> Bool {
  match resolved {
    ResolvedType::Scalar(
      "decimal"
      | "symbol"
      | "timestamp"
      | "number"
      | "sexp"
      | "any"
      | "$any"
      | "document"
      | "$null"
      | "$bool"
      | "$int"
      | "$float"
      | "$decimal"
      | "$string"
      | "$symbol"
      | "$timestamp"
      | "$blob"
      | "$clob"
      | "$list"
      | "$sexp"
      | "$struct"
      | "$number"
      | "$text"
      | "$lob"
    ) => true
    _ => false
  }
}

///|
fn moonbit_type_identifier(name : String) -> String raise SchemaError {
  if name == "" {
    raise SchemaError::InvalidIdentifier("empty type name")
  }
  let output = StringBuilder()
  let mut first = true
  let mut capitalize = true
  let mut previous_separator = false
  for character in name {
    if character == '_' || character == '-' {
      if first || previous_separator {
        raise SchemaError::InvalidIdentifier(
          "type name \{name} has a leading or repeated separator",
        )
      }
      capitalize = true
      previous_separator = true
    } else if is_identifier_character(character) {
      if first && character.is_ascii_digit() {
        output.write_string("T_")
      } else if first && !character.is_ascii() {
        output.write_string("T_")
      }
      if capitalize && character.is_ascii_lowercase() {
        output.write_char(character.to_ascii_uppercase())
      } else {
        output.write_char(character)
      }
      first = false
      capitalize = false
      previous_separator = false
    } else {
      raise SchemaError::InvalidIdentifier(
        "type name \{name} contains a character that cannot be represented in a MoonBit identifier",
      )
    }
  }
  if previous_separator {
    raise SchemaError::InvalidIdentifier(
      "type name \{name} ends with a separator",
    )
  }
  output.to_string()
}

///|
fn moonbit_field_identifier(
  name : String,
  context : String,
) -> String raise SchemaError {
  if name == "" {
    raise SchemaError::InvalidIdentifier("\{context} has an empty name")
  }
  let output = StringBuilder()
  let mut first = true
  for character in name {
    if character == '-' {
      output.write_char('_')
      first = false
    } else if is_identifier_character(character) {
      if first && character.is_ascii_digit() {
        output.write_string("field_")
      }
      if first && character.is_ascii_uppercase() {
        output.write_char(character.to_ascii_lowercase())
      } else {
        output.write_char(character)
      }
      first = false
    } else {
      raise SchemaError::InvalidIdentifier(
        "\{context} contains a character that cannot be represented in a MoonBit identifier",
      )
    }
  }
  let result = output.to_string()
  if result == "_" {
    raise SchemaError::InvalidIdentifier(
      "\{context} maps to the reserved wildcard identifier _",
    )
  }
  result
}

///|
fn is_identifier_character(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '_' ||
  is_moonbit_non_ascii_identifier_character(character)
}

///|
fn is_moonbit_non_ascii_identifier_character(character : Char) -> Bool {
  let code = character.to_int()
  code
  is (0x00A1..=0x00AC
  | 0x00AE..=0x02AF
  | 0x1100..=0x11FF
  | 0x1E00..=0x1EFF
  | 0x2070..=0x209F
  | 0x2150..=0x218F
  | 0x2E80..=0x2EFF
  | 0x2FF0..=0x2FFF
  | 0x3001..=0x30FF
  | 0x31C0..=0x9FFF
  | 0xAC00..=0xD7FF
  | 0xF900..=0xFAFF
  | 0xFE00..=0xFE0F
  | 0xFE30..=0xFE4F
  | 0x1F000..=0x1FBFF
  | 0x20000..=0x2A6DF
  | 0x2A700..=0x2EBEF
  | 0x2F800..=0x2FA1F
  | 0x30000..=0x323AF
  | 0xE0100..=0xE01EF)
}

///|
fn is_builtin_output_type(name : String) -> Bool {
  name == "Bool" ||
  name == "Float" ||
  name == "String" ||
  name == "Bytes" ||
  name == "Option"
}

///|
fn is_moonbit_reserved_word(name : String) -> Bool {
  contains_string(
    [
      "as", "else", "extern", "fn", "if", "let", "const", "match", "using", "mut",
      "type", "struct", "enum", "extenum", "trait", "derive", "while", "break", "continue",
      "import", "return", "throw", "raise", "try", "catch", "pub", "priv", "proof_assert",
      "proof_let", "readonly", "true", "false", "test", "loop", "for", "in", "impl",
      "with", "guard", "async", "is", "suberror", "and", "letrec", "enumview", "noraise",
      "nocancel", "defer", "lexscan", "where", "declare", "nobreak", "extend", "try!",
      "guard!", "module", "move", "ref", "static", "super", "unsafe", "use", "await",
      "dyn", "abstract", "do", "final", "macro", "override", "typeof", "virtual",
      "yield", "local", "method", "alias", "assert", "package", "recur", "isnot",
      "define", "downcast", "inherit", "member", "namespace", "upcast", "void", "lazy",
      "include", "mixin", "protected", "sealed", "constructor", "atomic", "volatile",
      "anyframe", "anytype", "asm", "comptime", "errdefer", "export", "opaque", "orelse",
      "resume", "threadlocal", "unreachable", "dynclass", "dynobj", "dynrec", "var",
      "finally", "noasync", "assume",
    ],
    name,
  )
}

///|
fn find_generated_name(
  names : Array[(String, String)],
  generated_name : String,
) -> (String, String)? {
  for item in names {
    if item.1 == generated_name {
      return Some(item)
    }
  }
  None
}
