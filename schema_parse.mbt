///|
/// Check an ISL 2.0 document against the supported code-generation subset.
///
/// This validates syntax and references only. It does not validate Ion values
/// against the schema or generate MoonBit source.
pub fn check_schema(source : String) -> Unit raise SchemaError {
  let schema = parse_schema(source)
  validate_type_references(schema.types)
}

///|
fn parse_schema(source : String) -> Schema raise SchemaError {
  let values = @ion.parse_text(source) catch {
    error => raise SchemaError::IonParse(error.summary())
  }
  let rest = match values {
    [first, .. rest] =>
      match first.without_annotations() {
        @model.IonValue::Symbol(symbol) =>
          match symbol.text_value() {
            Some("$ion_schema_2_0") => rest
            Some(version) if version.has_prefix("$ion_schema_") =>
              raise SchemaError::UnsupportedVersion(
                "expected $ion_schema_2_0, found \{version}",
              )
            _ if has_late_schema_version(rest) =>
              raise SchemaError::InvalidSchema(
                "the Ion Schema version marker must be the first value",
              )
            _ =>
              raise SchemaError::UnsupportedVersion(
                "missing $ion_schema_2_0 version marker",
              )
          }
        _ if has_late_schema_version(rest) =>
          raise SchemaError::InvalidSchema(
            "the Ion Schema version marker must be the first value",
          )
        _ =>
          raise SchemaError::UnsupportedVersion(
            "missing $ion_schema_2_0 version marker",
          )
      }
    [] =>
      raise SchemaError::UnsupportedVersion(
        "missing $ion_schema_2_0 version marker",
      )
  }

  let types : Array[NamedType] = []
  let mut saw_header = false
  let mut saw_type = false
  let mut saw_footer = false
  for value in rest {
    if saw_footer {
      raise SchemaError::InvalidSchema(
        "schema_footer must be the final schema value",
      )
    }
    match value.without_annotations() {
      @model.IonValue::Symbol(symbol) if is_schema_version_symbol(symbol) =>
        raise SchemaError::InvalidSchema(
          "the Ion Schema version marker must be the first value",
        )
      _ => ()
    }
    if has_annotation(value, "schema_header") {
      if saw_header {
        raise SchemaError::InvalidSchema("schema_header may appear only once")
      }
      if saw_type {
        raise SchemaError::InvalidSchema(
          "schema_header must appear before type definitions",
        )
      }
      saw_header = true
      validate_schema_header(value)
    } else if has_annotation(value, "schema_footer") {
      saw_footer = true
      validate_schema_footer(value)
    } else if has_annotation(value, "type") {
      saw_type = true
      validate_type_annotations(value)
      let named_type = parse_named_type(value)
      if is_known_builtin(named_type.name) {
        raise SchemaError::InvalidSchema(
          "type name conflicts with a built-in type: \{named_type.name}",
        )
      }
      if contains_type(types, named_type.name) {
        raise SchemaError::DuplicateType(named_type.name)
      }
      types.push(named_type)
    } else {
      raise SchemaError::UnsupportedFeature(
        "top-level values must be type definitions, schema_header, or schema_footer",
      )
    }
  }

  { types, }
}

///|
fn parse_named_type(value : @model.IonValue) -> NamedType raise SchemaError {
  let name_value = required_single_field(value, "name", "type definition")
  let name = symbol_text(name_value, "type name")
  if name == "" {
    raise SchemaError::InvalidSchema("type name must not be empty")
  }

  let type_value = required_single_field(value, "type", "type \{name}")
  let base_name = type_symbol_name(type_value, "type \{name}")
  let fields = value.get_fields("fields")
  let elements = value.get_fields("element")
  validate_type_definition_fields(
    value,
    name,
    fields.length(),
    elements.length(),
  )

  let body = match base_name {
    "struct" => {
      if fields.length() != 1 {
        raise SchemaError::InvalidSchema(
          "type \{name} must declare exactly one closed fields constraint",
        )
      }
      if elements.length() != 0 {
        raise SchemaError::InvalidSchema(
          "type \{name} cannot use element with struct",
        )
      }
      TypeBody::Struct(parse_fields(name, fields[0]))
    }
    "list" => {
      if elements.length() != 1 {
        raise SchemaError::InvalidSchema(
          "type \{name} must declare exactly one element constraint",
        )
      }
      if fields.length() != 0 {
        raise SchemaError::InvalidSchema(
          "type \{name} cannot use fields with list",
        )
      }
      TypeBody::List(parse_element_type(elements[0], "element of \{name}"))
    }
    _ => {
      if fields.length() != 0 || elements.length() != 0 {
        raise SchemaError::InvalidSchema(
          "scalar or alias type \{name} cannot use fields or element",
        )
      }
      let reference = parse_type_reference(type_value, "type \{name}")
      match reference {
        TypeRef::Builtin(_) => TypeBody::Scalar(reference)
        TypeRef::Named(_) => TypeBody::Alias(reference)
      }
    }
  }
  { name, body, }
}

///|
fn parse_fields(
  type_name : String,
  fields_value : @model.IonValue,
) -> Array[FieldSpec] raise SchemaError {
  match fields_value.annotations() {
    [annotation] if annotation.text_value() == Some("closed") => ()
    [] =>
      raise SchemaError::UnsupportedFeature(
        "open fields are not supported for type \{type_name}; use closed::{...}",
      )
    _ =>
      raise SchemaError::UnsupportedFeature(
        "fields annotations must contain only closed for type \{type_name}",
      )
  }

  let fields = match fields_value.without_annotations() {
    @model.IonValue::Struct(fields) => fields
    _ =>
      raise SchemaError::InvalidSchema(
        "fields constraint for type \{type_name} must be a struct",
      )
  }

  let result : Array[FieldSpec] = []
  for (symbol, value) in fields {
    let field_name = match symbol.text_value() {
      Some(text) => text
      None =>
        raise SchemaError::UnsupportedFeature(
          "unresolved field name in type \{type_name}",
        )
    }
    if field_name == "" {
      raise SchemaError::InvalidSchema(
        "field name in type \{type_name} must not be empty",
      )
    }
    if contains_field(result, field_name) {
      raise SchemaError::DuplicateField(type_name~, field_name~)
    }
    let (type_ref, occurrence) = parse_type_argument(
      value,
      "field \{type_name}.\{field_name}",
    )
    result.push({ name: field_name, type_ref, occurrence, })
  }
  result
}

///|
fn parse_type_argument(
  value : @model.IonValue,
  context : String,
) -> (TypeRef, FieldOccurrence) raise SchemaError {
  if value.annotations().length() != 0 {
    raise SchemaError::UnsupportedFeature(
      "annotated or nullable type arguments are not supported at \{context}",
    )
  }
  match value {
    @model.IonValue::Struct(_) => {
      validate_allowed_fields(value, ["type", "occurs"], context)
      let type_value = required_single_field(value, "type", context)
      let type_ref = parse_type_reference(type_value, context)
      let occurrence_values = value.get_fields("occurs")
      let occurrence = match occurrence_values {
        [] => FieldOccurrence::Optional
        [occurs_value] => parse_occurs(occurs_value, context)
        _ =>
          raise SchemaError::InvalidOccurs(
            "occurs may appear at most once at \{context}",
          )
      }
      (type_ref, occurrence)
    }
    _ => (parse_type_reference(value, context), FieldOccurrence::Optional)
  }
}

///|
fn parse_element_type(
  value : @model.IonValue,
  context : String,
) -> TypeRef raise SchemaError {
  if value.annotations().length() != 0 {
    raise SchemaError::UnsupportedFeature(
      "annotated or inline element types are not supported at \{context}",
    )
  }
  parse_type_reference(value, context)
}

///|
fn parse_occurs(
  value : @model.IonValue,
  context : String,
) -> FieldOccurrence raise SchemaError {
  if value.annotations().length() != 0 {
    raise SchemaError::InvalidOccurs(
      "occurs must be an unannotated symbol at \{context}",
    )
  }
  let name = match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(text) => text
        None =>
          raise SchemaError::InvalidOccurs(
            "occurs must be a resolved symbol at \{context}",
          )
      }
    _ =>
      raise SchemaError::InvalidOccurs(
        "only required and optional are supported at \{context}",
      )
  }
  match name {
    "required" => FieldOccurrence::Required
    "optional" => FieldOccurrence::Optional
    _ =>
      raise SchemaError::InvalidOccurs(
        "only required and optional are supported at \{context}; found \{name}",
      )
  }
}

///|
fn parse_type_reference(
  value : @model.IonValue,
  context : String,
) -> TypeRef raise SchemaError {
  if value.annotations().length() != 0 {
    raise SchemaError::UnsupportedFeature(
      "annotated or nullable type arguments are not supported at \{context}",
    )
  }
  let name = symbol_text(value, context)
  if is_supported_scalar(name) {
    TypeRef::Builtin(name)
  } else if name == "struct" || name == "list" {
    raise SchemaError::InvalidSchema(
      "\{name} requires its matching fields or element constraint at \{context}",
    )
  } else if is_known_builtin(name) {
    raise SchemaError::UnsupportedFeature(
      "built-in type \{name} is not supported at \{context}",
    )
  } else {
    TypeRef::Named(name)
  }
}

///|
fn type_symbol_name(
  value : @model.IonValue,
  context : String,
) -> String raise SchemaError {
  if value.annotations().length() != 0 {
    raise SchemaError::UnsupportedFeature(
      "annotated type names are not supported at \{context}",
    )
  }
  symbol_text(value, context)
}

///|
fn symbol_text(
  value : @model.IonValue,
  context : String,
) -> String raise SchemaError {
  match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(text) => text
        None =>
          raise SchemaError::UnsupportedFeature(
            "unresolved symbol at \{context}",
          )
      }
    _ =>
      raise SchemaError::InvalidSchema("expected an Ion symbol at \{context}")
  }
}

///|
fn required_single_field(
  value : @model.IonValue,
  name : String,
  context : String,
) -> @model.IonValue raise SchemaError {
  match value.get_fields(name) {
    [field] => field
    [] =>
      raise SchemaError::InvalidSchema("missing \{name} field at \{context}")
    _ =>
      raise SchemaError::InvalidSchema("duplicate \{name} field at \{context}")
  }
}

///|
fn validate_type_definition_fields(
  value : @model.IonValue,
  type_name : String,
  fields_count : Int,
  elements_count : Int,
) -> Unit raise SchemaError {
  validate_allowed_fields(
    value,
    ["name", "type", "fields", "element"],
    "type \{type_name}",
  )
  if fields_count > 1 || elements_count > 1 {
    raise SchemaError::InvalidSchema(
      "duplicate fields or element constraint at type \{type_name}",
    )
  }
}

///|
fn validate_allowed_fields(
  value : @model.IonValue,
  allowed : Array[String],
  context : String,
) -> Unit raise SchemaError {
  for (symbol, _) in value.fields() {
    let name = match symbol.text_value() {
      Some(text) => text
      None =>
        raise SchemaError::UnsupportedFeature(
          "unresolved field symbol at \{context}",
        )
    }
    if !contains_string(allowed, name) {
      raise SchemaError::UnsupportedFeature(
        "unsupported field or constraint \{name} at \{context}",
      )
    }
  }
}

///|
fn validate_schema_header(value : @model.IonValue) -> Unit raise SchemaError {
  validate_single_annotation(value, "schema_header")
  for (symbol, _) in value.fields() {
    match symbol.text_value() {
      Some("imports") =>
        raise SchemaError::UnsupportedFeature(
          "Schema imports are not supported",
        )
      Some(name) =>
        raise SchemaError::UnsupportedFeature(
          "schema_header field \{name} is not supported",
        )
      None =>
        raise SchemaError::UnsupportedFeature(
          "unresolved schema_header field name",
        )
    }
  }
  match value.without_annotations() {
    @model.IonValue::Struct(_) => ()
    _ => raise SchemaError::InvalidSchema("schema_header must be a struct")
  }
}

///|
fn validate_schema_footer(value : @model.IonValue) -> Unit raise SchemaError {
  validate_single_annotation(value, "schema_footer")
  match value.without_annotations() {
    @model.IonValue::Struct([]) => ()
    @model.IonValue::Struct(_) =>
      raise SchemaError::UnsupportedFeature(
        "schema_footer fields are not supported",
      )
    _ => raise SchemaError::InvalidSchema("schema_footer must be a struct")
  }
}

///|
fn validate_type_annotations(value : @model.IonValue) -> Unit raise SchemaError {
  validate_single_annotation(value, "type")
  match value.without_annotations() {
    @model.IonValue::Struct(_) => ()
    _ => raise SchemaError::InvalidSchema("type definition must be a struct")
  }
}

///|
fn validate_single_annotation(
  value : @model.IonValue,
  expected : String,
) -> Unit raise SchemaError {
  match value.annotations() {
    [annotation] if annotation.text_value() == Some(expected) => ()
    _ =>
      raise SchemaError::InvalidSchema(
        "expected only the \{expected} annotation",
      )
  }
}

///|
fn has_annotation(value : @model.IonValue, expected : String) -> Bool {
  for annotation in value.annotations() {
    if annotation.text_value() == Some(expected) {
      return true
    }
  }
  false
}

///|
fn is_schema_version_symbol(symbol : @model.IonSymbol) -> Bool {
  match symbol.text_value() {
    Some(text) => text.has_prefix("$ion_schema_")
    None => false
  }
}

///|
fn has_late_schema_version(values : ArrayView[@model.IonValue]) -> Bool {
  for value in values {
    match value.without_annotations() {
      @model.IonValue::Symbol(symbol) if is_schema_version_symbol(symbol) =>
        return true
      _ => ()
    }
  }
  false
}

///|
fn validate_type_references(types : Array[NamedType]) -> Unit raise SchemaError {
  for named_type in types {
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        validate_type_reference(types, type_ref, named_type.name)
      TypeBody::List(type_ref) =>
        validate_type_reference(
          types,
          type_ref,
          "element of \{named_type.name}",
        )
      TypeBody::Struct(fields) =>
        for field in fields {
          let occurrence = match field.occurrence {
            FieldOccurrence::Required => "required"
            FieldOccurrence::Optional => "optional"
          }
          validate_type_reference(
            types,
            field.type_ref,
            "\{occurrence} field \{named_type.name}.\{field.name}",
          )
        }
    }
  }
}

///|
fn validate_type_reference(
  types : Array[NamedType],
  type_ref : TypeRef,
  context : String,
) -> Unit raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) =>
      if !is_supported_scalar(name) {
        raise SchemaError::UnsupportedFeature(
          "unsupported built-in type \{name} at \{context}",
        )
      }
    TypeRef::Named(name) if contains_type(types, name) => ()
    TypeRef::Named(name) =>
      raise SchemaError::UnknownType("unknown type \{name} at \{context}")
  }
}

///|
fn is_supported_scalar(name : String) -> Bool {
  contains_string(
    [
      "bool", "int", "float", "decimal", "string", "symbol", "timestamp", "blob",
      "clob", "sexp", "any",
    ],
    name,
  )
}

///|
fn is_known_builtin(name : String) -> Bool {
  contains_string(
    [
      "any", "$any", "null", "$null", "nothing", "lob", "$lob", "number", "$number",
      "text", "$text", "sexp", "$sexp", "document", "$document", "$blob", "$bool",
      "$clob", "$decimal", "$float", "$int", "$string", "$symbol", "$timestamp",
      "$list", "$struct",
    ],
    name,
  ) ||
  is_supported_scalar(name) ||
  name == "struct" ||
  name == "list"
}

///|
fn contains_type(types : Array[NamedType], name : String) -> Bool {
  for named_type in types {
    if named_type.name == name {
      return true
    }
  }
  false
}

///|
fn contains_field(fields : Array[FieldSpec], name : String) -> Bool {
  for field in fields {
    if field.name == name {
      return true
    }
  }
  false
}

///|
fn contains_string(values : Array[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}
