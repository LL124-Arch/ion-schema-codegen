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
fn has_annotation_ordered_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    for constraint in named_type.annotation_constraints {
      if constraint.standard_ordered_elements is Some(_) {
        return true
      }
    }
  }
  false
}

///|
fn write_annotation_ordered_helper(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_check_ordered_annotations(\n  matches : Array[Array[Bool]],\n  value_count : Int,\n  minimums : Array[Int],\n  maximums : Array[Int?],\n  path : String,\n) -> Unit raise ConversionError {\n  let spec_count = minimums.length()\n  let possible : Array[Array[Bool]] = []\n  let mut row_index = 0\n  while row_index <= spec_count {\n    let row : Array[Bool] = []\n    let mut column_index = 0\n    while column_index <= value_count {\n      row.push(false)\n      column_index += 1\n    }\n    possible.push(row)\n    row_index += 1\n  }\n  possible[spec_count][value_count] = true\n  let mut spec_index = spec_count\n  while spec_index > 0 {\n    spec_index -= 1\n    let mut start = 0\n    while start <= value_count {\n      let mut count = minimums[spec_index]\n      let maximum = maximums[spec_index].unwrap_or(value_count)\n      let mut found = false\n      let mut prefix_matches = true\n      while count <= maximum && count <= value_count - start && prefix_matches {\n        if count > 0 && !matches[spec_index][start + count - 1] {\n          prefix_matches = false\n        }\n        if prefix_matches && possible[spec_index + 1][start + count] {\n          found = true\n        }\n        count += 1\n      }\n      possible[spec_index][start] = found\n      start += 1\n    }\n  }\n  if !possible[0][0] {\n    raise ConversionError::InvalidValue(\n      path=path,\n      constraint=\"annotations\",\n      actual=\"ordered_elements\",\n    )\n  }\n}\n",
  )
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
        match constraint.standard_element_valid_values {
          Some(allowed_values) => {
            let allowed = StringBuilder()
            allowed.write_char('[')
            let mut first = true
            for expected in allowed_values {
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
              ", true, false) {\n" +
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
          None => ()
        }
        for regex in constraint.standard_element_regexes {
          let symbol_value = "@ion_model.IonValue::Symbol(annotation)"
          output.write_string(
            indent +
            "for annotation in " +
            value_expression +
            ".annotations() {\n" +
            indent +
            "  if !ion_schema_codegen_regex_matches(" +
            symbol_value +
            ", \"" +
            moonbit_string_literal(regex.pattern) +
            "\") {\n" +
            indent +
            "    raise ConversionError::InvalidValue(\n" +
            indent +
            "      path=" +
            path_expression +
            ",\n" +
            indent +
            "      constraint=\"annotations\",\n" +
            indent +
            "      actual=\"symbol\",\n" +
            indent +
            "    )\n" +
            indent +
            "  }\n" +
            indent +
            "}\n",
          )
        }
        let annotation_symbol_value = "@ion_model.IonValue::Symbol(annotation)"
        write_annotation_token_length_checks(
          output,
          constraint.standard_element_codepoint_lengths,
          value_expression + ".annotations()",
          annotation_symbol_value,
          path_expression,
          "ion_schema_codegen_codepoint_length",
          indent,
        )
        write_annotation_token_length_checks(
          output,
          constraint.standard_element_utf8_byte_lengths,
          value_expression + ".annotations()",
          annotation_symbol_value,
          path_expression,
          "ion_schema_codegen_utf8_byte_length",
          indent,
        )
        match constraint.standard_ordered_elements {
          Some(ordered_elements) =>
            write_ordered_annotation_checks(
              output, named_type, types, ordered_elements, value_expression, path_expression,
              constraint_index, indent,
            )
          None => ()
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
fn write_annotation_token_length_checks(
  output : StringBuilder,
  ranges : Array[IntegerRange],
  annotations_expression : String,
  symbol_value_expression : String,
  path_expression : String,
  measure_function : String,
  indent : String,
) -> Unit {
  if ranges.length() == 0 {
    return
  }
  output.write_string(
    indent + "for annotation in " + annotations_expression + " {\n",
  )
  write_ion_value_integer_range_checks(
    output,
    ranges,
    symbol_value_expression,
    path_expression,
    "annotations",
    measure_function,
    indent + "  ",
  )
  output.write_string(indent + "}\n")
}

///|
fn write_ordered_annotation_checks(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
  ordered_elements : Array[OrderedElementSpec],
  value_expression : String,
  path_expression : String,
  constraint_index : Int,
  indent : String,
) -> Unit raise SchemaError {
  let name = "ion_schema_codegen_annotation_ordered_" +
    moonbit_type_identifier(named_type.name) +
    "_" +
    constraint_index.to_string()
  let annotations_name = name + "_values"
  let matrix_name = name + "_matches"
  let token_name = name + "_token"
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
    "let " +
    matrix_name +
    " : Array[Array[Bool]] = []\n",
  )
  let minimums = StringBuilder()
  let maximums = StringBuilder()
  minimums.write_char('[')
  maximums.write_char('[')
  let mut first = true
  let mut index = 0
  for ordered_element in ordered_elements {
    if !first {
      minimums.write_string(", ")
      maximums.write_string(", ")
    }
    first = false
    minimums.write_string(ordered_element.occurrence.min_count.to_string())
    match ordered_element.occurrence.max_count {
      Some(maximum) =>
        maximums.write_string("Some(" + maximum.to_string() + ")")
      None => maximums.write_string("None")
    }
    let row_name = name + "_row_" + index.to_string()
    let expression = type_reference_match_expression(
      ordered_element.type_ref,
      token_name,
      types,
    )
    output.write_string(
      indent +
      "let " +
      row_name +
      " : Array[Bool] = []\n" +
      indent +
      "for " +
      token_name +
      " in " +
      annotations_name +
      " {\n" +
      indent +
      "  " +
      row_name +
      ".push(" +
      expression +
      ")\n" +
      indent +
      "}\n" +
      indent +
      matrix_name +
      ".push(" +
      row_name +
      ")\n",
    )
    index += 1
  }
  minimums.write_char(']')
  maximums.write_char(']')
  output.write_string(
    indent +
    "ion_schema_codegen_check_ordered_annotations(" +
    matrix_name +
    ", " +
    annotations_name +
    ".length(), " +
    minimums.to_string() +
    ", " +
    maximums.to_string() +
    ", " +
    path_expression +
    ")\n",
  )
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
