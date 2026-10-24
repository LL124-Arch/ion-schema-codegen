///|
priv struct SchemaUserFields {
  header : Array[String]
  types : Array[String]
  footer : Array[String]
}

///|
fn isl_keyword(name : String) -> Bool {
  [
    "all_of", "annotations", "any_of", "as", "byte_length", "codepoint_length", "container_length",
    "contains", "element", "exponent", "field_names", "fields", "id", "ieee754_float",
    "imports", "name", "not", "occurs", "one_of", "ordered_elements", "precision",
    "regex", "schema_footer", "schema_header", "timestamp_offset", "timestamp_precision",
    "type", "user_reserved_fields", "utf8_byte_length", "valid_values",
  ].contains(name)
}

///|
fn isl_reserved_symbol(name : String) -> Bool {
  if name == "$ion_schema" || name.has_prefix("$ion_schema_") {
    return true
  }
  let chars = name.to_array()
  if chars.length() == 0 || chars[0] < 'a' || chars[0] > 'z' {
    return false
  }
  let mut underscore = false
  for ch in chars {
    if ch == '_' {
      if underscore {
        return false
      }
      underscore = true
    } else if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      underscore = false
    } else {
      return false
    }
  }
  !underscore
}

///|
fn isl_version_marker(value : @model.IonValue) -> String? {
  match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(name) if name.has_prefix("$ion_schema_") => {
          let chars = name.to_array()
          if chars.length() > 12 && chars[12] >= '0' && chars[12] <= '9' {
            Some(name)
          } else {
            None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn schema_user_fields(
  header : @model.IonValue,
) -> SchemaUserFields raise SchemaError {
  let policy : SchemaUserFields = { header: [], types: [], footer: [], }
  let declarations = header.get_fields("user_reserved_fields")
  if declarations.length() > 1 {
    raise SchemaError::InvalidSchema(
      "duplicate user_reserved_fields declaration",
    )
  }
  for declaration in declarations {
    if declaration.annotations().length() != 0 {
      raise SchemaError::InvalidSchema(
        "user_reserved_fields must be unannotated",
      )
    }
    let entries = match declaration {
      @model.IonValue::Struct(entries) => entries
      _ =>
        raise SchemaError::InvalidSchema(
          "user_reserved_fields must be a struct",
        )
    }
    let seen : Array[String] = []
    for (symbol, value) in entries {
      let scope = symbol.text_value().unwrap_or("")
      let target = match scope {
        "schema_header" => policy.header
        "type" => policy.types
        "schema_footer" => policy.footer
        _ =>
          raise SchemaError::InvalidSchema("invalid user_reserved_fields scope")
      }
      if seen.contains(scope) || value.annotations().length() != 0 {
        raise SchemaError::InvalidSchema(
          "duplicate scope or annotated user field list",
        )
      }
      seen.push(scope)
      let names = match value {
        @model.IonValue::List(names) => names
        _ =>
          raise SchemaError::InvalidSchema(
            "user field declaration must be a list",
          )
      }
      for item in names {
        if item.annotations().length() != 0 {
          raise SchemaError::InvalidSchema(
            "declared user field must be unannotated",
          )
        }
        let name = symbol_text(item, "user_reserved_fields")
        if isl_keyword(name) {
          raise SchemaError::InvalidSchema(
            "ISL keyword cannot be declared as user field: " + name,
          )
        }
        if !target.contains(name) {
          target.push(name)
        }
      }
    }
  }
  policy
}

///|
fn schema_clean_argument(
  value : @model.IonValue,
  policy : SchemaUserFields,
) -> @model.IonValue raise SchemaError {
  match value.without_annotations() {
    @model.IonValue::Struct(_) if value.get_fields("id").length() == 0 =>
      schema_clean_fields(value, "type", policy, true)
    _ => value
  }
}

///|
fn schema_clean_fields(
  value : @model.IonValue,
  scope : String,
  policy : SchemaUserFields,
  inline_argument : Bool,
) -> @model.IonValue raise SchemaError {
  let fields = match value.without_annotations() {
    @model.IonValue::Struct(fields) => fields
    _ => raise SchemaError::InvalidSchema(scope + " must be a struct")
  }
  let declared = match scope {
    "schema_header" => policy.header
    "schema_footer" => policy.footer
    _ => policy.types
  }
  let output : Array[(@model.IonSymbol, @model.IonValue)] = []
  for (symbol, item) in fields {
    let name = match symbol.text_value() {
      Some(name) => name
      None =>
        raise SchemaError::UnsupportedFeature("unresolved schema field name")
    }
    let meaningful = match scope {
      "schema_header" => name == "imports" || name == "user_reserved_fields"
      "schema_footer" => false
      _ =>
        isl_keyword(name) &&
        name != "imports" &&
        name != "schema_header" &&
        name != "schema_footer" &&
        name != "user_reserved_fields" &&
        name != "id" &&
        name != "as" &&
        (inline_argument || name != "occurs")
    }
    if !meaningful {
      if isl_keyword(name) ||
        (isl_reserved_symbol(name) && !declared.contains(name)) {
        raise SchemaError::UnsupportedFeature(
          "unsupported or undeclared reserved field " + name + " in " + scope,
        )
      }
      continue
    }
    if name == "user_reserved_fields" {
      continue
    }
    let cleaned = if scope == "type" {
      match name {
        "type" | "element" | "field_names" | "not" | "annotations" =>
          schema_clean_argument(item, policy)
        "all_of" | "any_of" | "one_of" | "ordered_elements" =>
          match item.without_annotations() {
            @model.IonValue::List(items) => {
              let arguments : Array[@model.IonValue] = []
              for argument in items {
                arguments.push(schema_clean_argument(argument, policy))
              }
              @model.IonValue::List(arguments).with_annotations(
                item.annotations(),
              )
            }
            _ => item
          }
        "fields" =>
          match item.without_annotations() {
            @model.IonValue::Struct(entries) => {
              let cleaned_entries : Array[(@model.IonSymbol, @model.IonValue)] = []
              for (key, argument) in entries {
                cleaned_entries.push(
                  (key, schema_clean_argument(argument, policy)),
                )
              }
              @model.IonValue::Struct(cleaned_entries).with_annotations(
                item.annotations(),
              )
            }
            _ => item
          }
        _ => item
      }
    } else {
      item
    }
    output.push((symbol, cleaned))
  }
  @model.IonValue::Struct(output).with_annotations(value.annotations())
}

///|
/// Validate ISL 2.0 document framing and user-field declarations, then discard
/// open content for code generation. Imports remain unresolved. Each imported
/// document must be prepared separately so declarations never leak across files.
/// Literal values in contains/valid_values are preserved without traversal.
pub fn prepare_schema_document(
  values : Array[@model.IonValue],
) -> Array[@model.IonValue] raise SchemaError {
  let output : Array[@model.IonValue] = []
  let mut started = false
  let mut saw_type = false
  let mut saw_header = false
  let mut finished = false
  let mut policy : SchemaUserFields = { header: [], types: [], footer: [], }
  for value in values {
    match isl_version_marker(value) {
      Some(version) => {
        if started {
          raise SchemaError::InvalidSchema(
            "duplicate or misplaced Ion Schema version marker",
          )
        }
        if version != "$ion_schema_2_0" {
          raise SchemaError::UnsupportedVersion(
            "expected $ion_schema_2_0, found " + version,
          )
        }
        if value.annotations().length() != 0 {
          raise SchemaError::InvalidSchema("version marker must be unannotated")
        }
        started = true
        output.push(value)
        continue
      }
      None => ()
    }
    let scope = if has_annotation(value, "schema_header") {
      "schema_header"
    } else if has_annotation(value, "schema_footer") {
      "schema_footer"
    } else if has_annotation(value, "type") {
      "type"
    } else {
      if !started || finished {
        continue
      }
      for symbol in value.annotations() {
        match symbol.text_value() {
          Some(name) if !isl_reserved_symbol(name) => ()
          _ =>
            raise SchemaError::InvalidSchema(
              "reserved or unresolved annotation on open content",
            )
        }
      }
      continue
    }
    if !started {
      raise SchemaError::UnsupportedVersion(
        "ISL declarations require a preceding $ion_schema_2_0 marker",
      )
    }
    if finished {
      raise SchemaError::InvalidSchema("ISL declaration after schema_footer")
    }
    validate_single_annotation(value, scope)
    if scope == "schema_header" {
      if saw_header || saw_type {
        raise SchemaError::InvalidSchema("duplicate or late schema_header")
      }
      saw_header = true
      policy = schema_user_fields(value)
    } else if scope == "schema_footer" {
      finished = true
    } else {
      saw_type = true
    }
    output.push(schema_clean_fields(value, scope, policy, false))
  }
  if !started {
    raise SchemaError::UnsupportedVersion(
      "missing $ion_schema_2_0 version marker",
    )
  }
  output
}
