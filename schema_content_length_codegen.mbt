///|
fn has_content_length_constraints(types : Array[NamedType]) -> Bool {
  for named_type in types {
    if named_type.codepoint_lengths.length() > 0 ||
      named_type.utf8_byte_lengths.length() > 0 ||
      named_type.byte_lengths.length() > 0 {
      return true
    }
    for constraint in named_type.annotation_constraints {
      if constraint.standard_element_codepoint_lengths.length() > 0 ||
        constraint.standard_element_utf8_byte_lengths.length() > 0 {
        return true
      }
    }
  }
  false
}

///|
fn write_content_length_helpers(
  output : StringBuilder,
  types : Array[NamedType],
) -> Unit {
  let mut needs_codepoint_length = false
  let mut needs_utf8_byte_length = false
  let mut needs_byte_length = false
  for named_type in types {
    if named_type.codepoint_lengths.length() > 0 {
      needs_codepoint_length = true
    }
    if named_type.utf8_byte_lengths.length() > 0 {
      needs_utf8_byte_length = true
    }
    if named_type.byte_lengths.length() > 0 {
      needs_byte_length = true
    }
    for constraint in named_type.annotation_constraints {
      if constraint.standard_element_codepoint_lengths.length() > 0 {
        needs_codepoint_length = true
      }
      if constraint.standard_element_utf8_byte_lengths.length() > 0 {
        needs_utf8_byte_length = true
      }
    }
  }
  if needs_codepoint_length {
    output.write_string(
      "///|\nfn ion_schema_codegen_codepoint_length(\n  value : @ion_model.IonValue,\n) -> Int? {\n  match value.without_annotations() {\n    @ion_model.IonValue::String(text) => Some(text.char_length())\n    @ion_model.IonValue::Symbol(symbol) =>\n      match symbol.text_value() {\n        Some(text) => Some(text.char_length())\n        None => None\n      }\n    _ => None\n  }\n}\n",
    )
    if needs_utf8_byte_length {
      output.write_string("\n")
    }
  }
  if needs_utf8_byte_length {
    output.write_string(
      "///|\nfn ion_schema_codegen_utf8_byte_length(\n  value : @ion_model.IonValue,\n) -> Int? {\n  let text = match value.without_annotations() {\n    @ion_model.IonValue::String(text) => Some(text)\n    @ion_model.IonValue::Symbol(symbol) => symbol.text_value()\n    _ => None\n  }\n  match text {\n    Some(text) => {\n      let mut byte_count = 0\n      for character in text {\n        let codepoint = character.to_int()\n        byte_count += if codepoint <= 0x7F {\n          1\n        } else if codepoint <= 0x7FF {\n          2\n        } else if codepoint <= 0xFFFF {\n          3\n        } else {\n          4\n        }\n      }\n      Some(byte_count)\n    }\n    None => None\n  }\n}\n",
    )
    if needs_byte_length {
      output.write_string("\n")
    }
  }
  if needs_byte_length {
    output.write_string(
      "///|\nfn ion_schema_codegen_byte_length(\n  value : @ion_model.IonValue,\n) -> Int? {\n  match value.without_annotations() {\n    @ion_model.IonValue::Blob(bytes) => Some(bytes.length())\n    @ion_model.IonValue::Clob(bytes) => Some(bytes.length())\n    _ => None\n  }\n}\n",
    )
  }
}

///|
fn write_content_length_value_checks(
  output : StringBuilder,
  named_type : NamedType,
  value_expression : String,
  path_expression : String,
  indent : String,
) -> Unit {
  write_ion_value_integer_range_checks(
    output,
    named_type.codepoint_lengths,
    value_expression,
    path_expression,
    "codepoint_length",
    "ion_schema_codegen_codepoint_length",
    indent,
  )
  write_ion_value_integer_range_checks(
    output,
    named_type.utf8_byte_lengths,
    value_expression,
    path_expression,
    "utf8_byte_length",
    "ion_schema_codegen_utf8_byte_length",
    indent,
  )
  write_ion_value_integer_range_checks(
    output,
    named_type.byte_lengths,
    value_expression,
    path_expression,
    "byte_length",
    "ion_schema_codegen_byte_length",
    indent,
  )
}
