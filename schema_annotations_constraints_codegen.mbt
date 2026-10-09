///|
fn has_annotation_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.annotation_constraints.length() > 0 {
      return true
    }
  }
  false
}

///|
fn write_annotation_helper(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_annotations_match(\n  value : @ion_model.IonValue,\n  allowed : Array[String],\n  closed : Bool,\n  required : Bool,\n) -> Bool {\n  let annotations = value.annotations()\n  if required {\n    for expected in allowed {\n      let mut found = false\n      for actual in annotations {\n        if actual.text_value() == Some(expected) {\n          found = true\n          break\n        }\n      }\n      if !found {\n        return false\n      }\n    }\n  }\n  if closed {\n    for actual in annotations {\n      let text = match actual.text_value() {\n        Some(text) => text\n        None => return false\n      }\n      let mut allowed_annotation = false\n      for expected in allowed {\n        if expected == text {\n          allowed_annotation = true\n          break\n        }\n      }\n      if !allowed_annotation {\n        return false\n      }\n    }\n  }\n  true\n}\n",
  )
}

///|
fn write_named_annotation_checks(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit raise SchemaError {
  let mut constraint_index = 0
  for constraint in named_type.annotation_constraints {
    match constraint.standard_type_ref {
      Some(type_ref) => {
        let annotations_name = "ion_schema_codegen_annotations_" +
          moonbit_type_identifier(named_type.name) +
          "_" +
          constraint_index.to_string()
        let expression = type_reference_match_expression(
          type_ref,
          "@ion_model.IonValue::List(" + annotations_name + ")",
          types,
        )
        output.write_string(
          indent +
          "let " +
          annotations_name +
          " : Array[@ion_model.IonValue] = []\n" +
          indent +
          "for annotation in " +
          value_expression +
          ".annotations() {\n" +
          indent +
          "  " +
          annotations_name +
          ".push(@ion_model.IonValue::Symbol(annotation))\n" +
          indent +
          "}\n" +
          indent +
          "if !(" +
          expression +
          ") {\n" +
          indent +
          "  raise ConversionError::InvalidValue(\n" +
          indent +
          "    path=" +
          path_expression +
          ",\n" +
          indent +
          "    constraint=\"annotations\",\n" +
          indent +
          "    actual=\"symbol list\",\n" +
          indent +
          "  )\n" +
          indent +
          "}\n",
        )
      }
      None if constraint.standard_inline => {
        if constraint.standard_container_lengths.length() > 0 {
          let annotation_count_name = "ion_schema_codegen_annotation_count_" +
            moonbit_type_identifier(named_type.name) +
            "_" +
            constraint_index.to_string()
          output.write_string(
            indent +
            "let " +
            annotation_count_name +
            " = " +
            value_expression +
            ".annotations().length()\n",
          )
          write_integer_range_checks(
            output,
            constraint.standard_container_lengths,
            annotation_count_name,
            path_expression,
            "annotations",
            indent,
          )
        }
        match constraint.standard_contains_values {
          Some(required) if required.length() > 0 => {
            let allowed = StringBuilder()
            allowed.write_char('[')
            let mut first = true
            for expected in required {
              if !first {
                allowed.write_string(", ")
              }
              first = false
              allowed.write_char('"')
              allowed.write_string(moonbit_string_literal(expected))
              allowed.write_char('"')
            }
            allowed.write_char(']')
            output.write_string(
              indent +
              "if !ion_schema_codegen_annotations_match(" +
              value_expression +
              ", " +
              allowed.to_string() +
              ", false, true) {\n" +
              indent +
              "  raise ConversionError::InvalidValue(\n" +
              indent +
              "    path=" +
              path_expression +
              ",\n" +
              indent +
              "    constraint=\"annotations\",\n" +
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
          _ => ()
        }
      }
      None => {
        let allowed = StringBuilder()
        allowed.write_char('[')
        let mut first = true
        for annotation in constraint.allowed {
          if !first {
            allowed.write_string(", ")
          }
          first = false
          allowed.write_char('"')
          allowed.write_string(moonbit_string_literal(annotation))
          allowed.write_char('"')
        }
        allowed.write_char(']')
        output.write_string(
          indent +
          "if !ion_schema_codegen_annotations_match(" +
          value_expression +
          ", " +
          allowed.to_string() +
          ", " +
          constraint.closed.to_string() +
          ", " +
          constraint.required.to_string() +
          ") {\n" +
          indent +
          "  raise ConversionError::InvalidValue(\n" +
          indent +
          "    path=" +
          path_expression +
          ",\n" +
          indent +
          "    constraint=\"annotations\",\n" +
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
    constraint_index += 1
  }
}

///|
fn write_named_annotations_validator(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  if named_type.annotation_constraints.length() == 0 {
    return
  }
  let type_ref = match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return
  }
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar("document") => return
    _ => ()
  }
  let generated_name = moonbit_type_identifier(named_type.name)
  output.write_string("///|\n/// Validate annotations for ")
  output.write_string(generated_name)
  output.write_string(
    ".\npub fn validate_annotations_" +
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
  write_named_annotation_checks(
    output,
    named_type,
    types,
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
fn write_document_annotations_failure(
  output : StringBuilder,
  named_type : NamedType,
  path_expression : String,
  indent : String,
) -> Unit {
  if named_type.annotation_constraints.length() == 0 {
    return
  }
  output.write_string(
    indent +
    "raise ConversionError::InvalidValue(\n" +
    indent +
    "  path=" +
    path_expression +
    ",\n" +
    indent +
    "  constraint=\"annotations\",\n" +
    indent +
    "  actual=\"document\",\n" +
    indent +
    ")\n",
  )
}
