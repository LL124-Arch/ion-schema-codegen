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
  let valid_values_fields = value.get_fields("valid_values")
  let container_length_fields = value.get_fields("container_length")
  let codepoint_length_fields = value.get_fields("codepoint_length")
  let utf8_byte_length_fields = value.get_fields("utf8_byte_length")
  let byte_length_fields = value.get_fields("byte_length")
  if elements.length() > 1 {
    raise SchemaError::InvalidSchema(
      "element may appear at most once at type " + name,
    )
  }
  let element_type = match elements {
    [] => None
    [element] => Some(parse_element_type(element, "element of " + name))
    _ => None
  }
  validate_type_definition_fields(
    value,
    name,
    fields.length(),
    elements.length(),
    valid_values_fields.length(),
  )
  let valid_values = match valid_values_fields {
    [] => None
    [valid_values_value] =>
      Some(parse_valid_values(valid_values_value, "type \{name}"))
    _ =>
      raise SchemaError::InvalidSchema(
        "valid_values may appear at most once at type \{name}",
      )
  }
  let container_lengths : Array[IntegerRange] = []
  for container_length in container_length_fields {
    container_lengths.push(
      parse_integer_constraint_range(
        container_length,
        "container_length at type " + name,
      ),
    )
  }
  let codepoint_lengths = parse_integer_constraint_fields(
    codepoint_length_fields, "codepoint_length", name,
  )
  let utf8_byte_lengths = parse_integer_constraint_fields(
    utf8_byte_length_fields, "utf8_byte_length", name,
  )
  let byte_lengths = parse_integer_constraint_fields(
    byte_length_fields, "byte_length", name,
  )

  let body = match base_name {
    "struct" => {
      if valid_values is Some(_) {
        raise SchemaError::UnsupportedFeature(
          "valid_values is only supported on scalar types at type \{name}",
        )
      }
      if fields.length() > 1 {
        raise SchemaError::InvalidSchema(
          "type \{name} may declare at most one fields constraint",
        )
      }
      let (parsed_fields, is_open) = match fields {
        [] => ([], true)
        [field_constraint] => parse_fields(name, field_constraint)
        _ => ([], true)
      }
      TypeBody::Struct(parsed_fields, is_open)
    }
    "list" => {
      if valid_values is Some(_) {
        raise SchemaError::UnsupportedFeature(
          "valid_values is only supported on scalar types at type \{name}",
        )
      }
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
      if fields.length() != 0 {
        raise SchemaError::InvalidSchema(
          "scalar or alias type \{name} cannot use fields",
        )
      }
      let reference = parse_type_reference(type_value, "type \{name}")
      match reference {
        TypeRef::Builtin(_) => TypeBody::Scalar(reference)
        TypeRef::Named(_) => TypeBody::Alias(reference)
        TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) =>
          raise SchemaError::UnsupportedFeature(
            "$null_or cannot annotate a top-level named type",
          )
      }
    }
  }
  {
    name,
    body,
    element_type,
    valid_values,
    container_lengths,
    codepoint_lengths,
    utf8_byte_lengths,
    byte_lengths,
  }
}

///|
fn parse_integer_constraint_fields(
  values : Array[@model.IonValue],
  constraint : String,
  type_name : String,
) -> Array[IntegerRange] raise SchemaError {
  let ranges : Array[IntegerRange] = []
  for value in values {
    ranges.push(
      parse_integer_constraint_range(
        value,
        constraint + " at type " + type_name,
      ),
    )
  }
  ranges
}

///|
fn parse_integer_constraint_range(
  value : @model.IonValue,
  context : String,
) -> IntegerRange raise SchemaError {
  let occurrence = match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::Int(_) =>
          parse_occurs(value, context) catch {
            SchemaError::InvalidOccurs(_) =>
              raise SchemaError::InvalidSchema(
                "invalid integer range at " + context,
              )
            error => raise error
          }
        _ =>
          raise SchemaError::InvalidSchema(
            "expected a non-negative integer or range:: value at " + context,
          )
      }
    [annotation] if annotation.text_value() == Some("range") =>
      parse_occurs(value, context) catch {
        SchemaError::InvalidOccurs(_) =>
          raise SchemaError::InvalidSchema(
            "invalid integer range at " + context,
          )
        error => raise error
      }
    _ =>
      raise SchemaError::InvalidSchema(
        "expected an unannotated integer or range:: value at " + context,
      )
  }
  { minimum: occurrence.min_count, maximum: occurrence.max_count, }
}

///|
fn parse_valid_values(
  value : @model.IonValue,
  context : String,
) -> Array[@model.IonValue] raise SchemaError {
  match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::List(values) => values
        _ =>
          raise SchemaError::InvalidSchema(
            "valid_values must be an Ion list at \{context}",
          )
      }
    [annotation] if annotation.text_value() == Some("range") =>
      match value.without_annotations() {
        @model.IonValue::List(_) => [value]
        _ =>
          raise SchemaError::InvalidSchema(
            "valid_values range must be a two-bound Ion list at \{context}",
          )
      }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "annotated valid_values sets are not supported at \{context}",
      )
  }
}

///|
fn parse_fields(
  type_name : String,
  fields_value : @model.IonValue,
) -> (Array[FieldSpec], Bool) raise SchemaError {
  let is_open = match fields_value.annotations() {
    [annotation] if annotation.text_value() == Some("closed") => false
    [] => true
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
  (result, is_open)
}

///|
fn parse_type_argument(
  value : @model.IonValue,
  context : String,
) -> (TypeRef, FieldOccurrence) raise SchemaError {
  match value {
    @model.IonValue::Struct(_) => {
      if value.annotations().length() != 0 {
        raise SchemaError::UnsupportedFeature(
          "annotated inline type arguments are not supported at \{context}",
        )
      }
      validate_allowed_fields(value, ["type", "occurs"], context)
      let type_value = required_single_field(value, "type", context)
      let type_ref = parse_type_argument_reference(type_value, context)
      let occurrence_values = value.get_fields("occurs")
      let occurrence = match occurrence_values {
        [] => { min_count: 0, max_count: Some(1), }
        [occurs_value] => {
          let occurs = parse_occurs(occurs_value, context)
          if is_null_or_reference(type_ref) {
            raise SchemaError::InvalidOccurs(
              "$null_or cannot be combined with explicit occurs at \{context}",
            )
          }
          occurs
        }
        _ =>
          raise SchemaError::InvalidOccurs(
            "occurs may appear at most once at \{context}",
          )
      }
      (type_ref, occurrence)
    }
    _ =>
      (
        parse_type_argument_reference(value, context),
        { min_count: 0, max_count: Some(1), },
      )
  }
}

///|
fn parse_type_argument_reference(
  value : @model.IonValue,
  context : String,
) -> TypeRef raise SchemaError {
  match value.annotations() {
    [] => parse_type_reference(value, context)
    [annotation] if annotation.text_value() == Some("$null_or") => {
      let inner = parse_type_reference(value.without_annotations(), context)
      match inner {
        TypeRef::Builtin(name) => TypeRef::NullOrBuiltin(name)
        TypeRef::Named(name) => TypeRef::NullOrNamed(name)
        TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) =>
          raise SchemaError::UnsupportedFeature(
            "nested $null_or annotations are not supported at \{context}",
          )
      }
    }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "only $null_or annotated type arguments are supported at \{context}",
      )
  }
}

///|
fn parse_element_type(
  value : @model.IonValue,
  context : String,
) -> TypeRef raise SchemaError {
  parse_type_argument_reference(value, context)
}

///|
fn parse_occurs(
  value : @model.IonValue,
  context : String,
) -> FieldOccurrence raise SchemaError {
  match value.annotations() {
    [annotation] if annotation.text_value() == Some("range") =>
      parse_occurs_range(value, context)
    [] =>
      match value.without_annotations() {
        @model.IonValue::Symbol(symbol) =>
          match symbol.text_value() {
            Some("required") => { min_count: 1, max_count: Some(1), }
            Some("optional") => { min_count: 0, max_count: Some(1), }
            Some(name) =>
              raise SchemaError::InvalidOccurs(
                "expected required, optional, a non-negative integer, or range at \{context}; found \{name}",
              )
            None =>
              raise SchemaError::InvalidOccurs(
                "occurs must be a resolved symbol at \{context}",
              )
          }
        @model.IonValue::Int(count) => {
          let exact = parse_occurs_count(count, context)
          { min_count: exact, max_count: Some(exact), }
        }
        _ =>
          raise SchemaError::InvalidOccurs(
            "expected required, optional, a non-negative integer, or range at \{context}",
          )
      }
    _ =>
      raise SchemaError::InvalidOccurs(
        "occurs must be an unannotated symbol, integer, or range:: list at \{context}",
      )
  }
}

///|
fn parse_occurs_range(
  value : @model.IonValue,
  context : String,
) -> FieldOccurrence raise SchemaError {
  let (minimum, maximum) = match value.without_annotations() {
    @model.IonValue::List([minimum, maximum]) => (minimum, maximum)
    _ =>
      raise SchemaError::InvalidOccurs(
        "occurs range must contain exactly two bounds at \{context}",
      )
  }
  let (minimum_value, minimum_exclusive) = parse_occurs_endpoint(
    minimum, true, context,
  )
  let (maximum_value, maximum_exclusive) = parse_occurs_endpoint(
    maximum, false, context,
  )
  if minimum_value is None && maximum_value is None {
    raise SchemaError::InvalidOccurs(
      "occurs range cannot use both min and max at \{context}",
    )
  }
  if minimum_exclusive && minimum_value == Some(2147483647) {
    raise SchemaError::InvalidOccurs(
      "exclusive occurs minimum exceeds the maximum supported MoonBit array length at \{context}",
    )
  }
  let min_count = match minimum_value {
    Some(count) => count + (if minimum_exclusive { 1 } else { 0 })
    None => 0
  }
  let max_count = match maximum_value {
    Some(count) => Some(count - (if maximum_exclusive { 1 } else { 0 }))
    None => None
  }
  match max_count {
    Some(maximum_count) if maximum_count < min_count =>
      raise SchemaError::InvalidOccurs(
        "occurs range has no non-negative integer values at \{context}",
      )
    _ => ()
  }
  { min_count, max_count, }
}

///|
fn parse_occurs_endpoint(
  value : @model.IonValue,
  is_minimum : Bool,
  context : String,
) -> (Int?, Bool) raise SchemaError {
  let exclusive = match value.annotations() {
    [] => false
    [annotation] if annotation.text_value() == Some("exclusive") => true
    _ =>
      raise SchemaError::InvalidOccurs(
        "range bounds may only use the exclusive annotation at \{context}",
      )
  }
  match value.without_annotations() {
    @model.IonValue::Symbol(symbol) => {
      let expected = if is_minimum { "min" } else { "max" }
      if exclusive || symbol.text_value() != Some(expected) {
        raise SchemaError::InvalidOccurs(
          "occurs range must use min as its lower bound and max as its upper bound at \{context}",
        )
      }
      (None, false)
    }
    @model.IonValue::Int(count) =>
      (Some(parse_occurs_count(count, context)), exclusive)
    _ =>
      raise SchemaError::InvalidOccurs(
        "occurs range bounds must be non-negative integers or min/max at \{context}",
      )
  }
}

///|
fn parse_occurs_count(
  count : @bigint.BigInt,
  context : String,
) -> Int raise SchemaError {
  if count.compare_int(0) < 0 {
    raise SchemaError::InvalidOccurs(
      "occurs counts must be non-negative at \{context}",
    )
  }
  if count.compare_int(2147483647) > 0 {
    raise SchemaError::InvalidOccurs(
      "occurs count exceeds the maximum supported MoonBit array length at \{context}",
    )
  }
  count.to_int()
}

///|
fn is_null_or_reference(type_ref : TypeRef) -> Bool {
  match type_ref {
    TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) => true
    _ => false
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
  valid_values_count : Int,
) -> Unit raise SchemaError {
  validate_allowed_fields(
    value,
    [
      "name", "type", "fields", "element", "valid_values", "container_length", "codepoint_length",
      "utf8_byte_length", "byte_length",
    ],
    "type \{type_name}",
  )
  if fields_count > 1 || elements_count > 1 || valid_values_count > 1 {
    raise SchemaError::InvalidSchema(
      "duplicate fields or constraints at type \{type_name}",
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
fn supports_container_length(
  types : Array[NamedType],
  body : TypeBody,
) -> Bool raise SchemaError {
  match body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => true
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Struct(_) | ResolvedType::List(_) => true
        ResolvedType::Scalar(name) =>
          contains_string(
            ["sexp", "document", "$list", "$sexp", "$struct"],
            name,
          )
      }
  }
}

///|
fn supports_integer_content_length(
  types : Array[NamedType],
  body : TypeBody,
  allowed_types : Array[String],
) -> Bool raise SchemaError {
  match body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => false
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar(name) => contains_string(allowed_types, name)
        ResolvedType::Struct(_) | ResolvedType::List(_) => false
      }
  }
}

///|
fn supports_element_constraint(
  types : Array[NamedType],
  named_type : NamedType,
) -> Bool raise SchemaError {
  match named_type.body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => true
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Struct(_) | ResolvedType::List(_) => true
        ResolvedType::Scalar(name) =>
          contains_string(["sexp", "$sexp", "document"], name)
      }
  }
}

///|
fn validate_type_references(types : Array[NamedType]) -> Unit raise SchemaError {
  for named_type in types {
    match named_type.element_type {
      Some(element_type) => {
        if !supports_element_constraint(types, named_type) {
          raise SchemaError::UnsupportedFeature(
            "element applies only to list, sexp, struct, or document values at type " +
            named_type.name,
          )
        }
        validate_type_reference(
          types,
          element_type,
          "element of " + named_type.name,
        )
      }
      None => ()
    }
    if named_type.container_lengths.length() > 0 &&
      !supports_container_length(types, named_type.body) {
      raise SchemaError::UnsupportedFeature(
        "container_length applies only to list, sexp, struct, or document at type " +
        named_type.name,
      )
    }
    if (
        named_type.codepoint_lengths.length() > 0 ||
        named_type.utf8_byte_lengths.length() > 0
      ) &&
      !supports_integer_content_length(types, named_type.body, [
        "string", "symbol", "$string", "$symbol",
      ]) {
      raise SchemaError::UnsupportedFeature(
        "codepoint_length and utf8_byte_length apply only to string or symbol values at type " +
        named_type.name,
      )
    }
    if named_type.byte_lengths.length() > 0 &&
      !supports_integer_content_length(types, named_type.body, [
        "blob", "clob", "$blob", "$clob",
      ]) {
      raise SchemaError::UnsupportedFeature(
        "byte_length applies only to blob or clob values at type " +
        named_type.name,
      )
    }
    if named_type.valid_values is Some(valid_values) {
      match named_type.body {
        TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
          if !is_valid_values_target(types, type_ref) {
            raise SchemaError::UnsupportedFeature(
              "valid_values is supported only for scalar Ion types at type \{named_type.name}",
            )
          }
        TypeBody::Struct(_, _) | TypeBody::List(_) =>
          raise SchemaError::UnsupportedFeature(
            "valid_values is supported only for scalar Ion types at type \{named_type.name}",
          )
      }
      match named_type.body {
        TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
          for candidate in valid_values {
            match candidate.annotations() {
              [] => ()
              [annotation] if annotation.text_value() == Some("range") =>
                validate_valid_values_range(
                  types,
                  type_ref,
                  candidate,
                  "type \{named_type.name}",
                )
              _ =>
                raise SchemaError::UnsupportedFeature(
                  "valid_values entries must be unannotated values or range:: constraints at type \{named_type.name}",
                )
            }
          }
        TypeBody::Struct(_, _) | TypeBody::List(_) => ()
      }
    }
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        validate_type_reference(types, type_ref, named_type.name)
      TypeBody::List(type_ref) =>
        validate_type_reference(
          types,
          type_ref,
          "element of \{named_type.name}",
        )
      TypeBody::Struct(fields, _) =>
        for field in fields {
          let occurrence = if field.occurrence.min_count == 1 &&
            field.occurrence.max_count == Some(1) {
            "required"
          } else if field.occurrence.min_count == 0 &&
            field.occurrence.max_count == Some(1) {
            "optional"
          } else {
            "repeated"
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
fn is_valid_values_target(types : Array[NamedType], type_ref : TypeRef) -> Bool {
  is_valid_values_target_with_depth(types, type_ref, types.length())
}

///|
fn is_valid_values_target_with_depth(
  types : Array[NamedType],
  type_ref : TypeRef,
  remaining : Int,
) -> Bool {
  if remaining < 0 {
    return false
  }
  match type_ref {
    TypeRef::Builtin(name) => is_valid_values_scalar_name(name)
    TypeRef::Named(name) =>
      match find_named_type(types, name) {
        Some(named_type) =>
          match named_type.body {
            TypeBody::Scalar(inner) | TypeBody::Alias(inner) =>
              is_valid_values_target_with_depth(types, inner, remaining - 1)
            TypeBody::Struct(_, _) | TypeBody::List(_) => false
          }
        None => false
      }
    TypeRef::NullOrBuiltin(name) => is_valid_values_scalar_name(name)
    TypeRef::NullOrNamed(name) =>
      match find_named_type(types, name) {
        Some(named_type) =>
          match named_type.body {
            TypeBody::Scalar(inner) | TypeBody::Alias(inner) =>
              is_valid_values_target_with_depth(types, inner, remaining - 1)
            TypeBody::Struct(_, _) | TypeBody::List(_) => false
          }
        None => false
      }
  }
}

///|
fn is_valid_values_scalar_name(name : String) -> Bool {
  contains_string(
    [
      "bool", "int", "float", "decimal", "string", "symbol", "timestamp", "blob",
      "number", "clob", "$null", "$bool", "$int", "$float", "$decimal", "$string",
      "$symbol", "$timestamp", "$blob", "$clob", "$number", "$text", "$lob",
    ],
    name,
  )
}

///|
fn validate_valid_values_range(
  types : Array[NamedType],
  type_ref : TypeRef,
  range : @model.IonValue,
  context : String,
) -> Unit raise SchemaError {
  match range.without_annotations() {
    @model.IonValue::List([minimum, maximum]) => {
      let (minimum_kind, _) = parse_range_endpoint(minimum, true, context)
      let (maximum_kind, _) = parse_range_endpoint(maximum, false, context)
      if minimum_kind == "min" && maximum_kind == "max" {
        raise SchemaError::InvalidSchema(
          "a valid_values range cannot use both min and max at " + context,
        )
      }
      let range_kind = if minimum_kind == "min" {
        maximum_kind
      } else if maximum_kind == "max" {
        minimum_kind
      } else if minimum_kind == maximum_kind {
        minimum_kind
      } else {
        raise SchemaError::InvalidSchema(
          "valid_values range bounds must have the same Ion type at " + context,
        )
      }
      if !valid_values_range_type(types, type_ref, range_kind) {
        raise SchemaError::InvalidSchema(
          "a " +
          range_kind +
          " valid_values range does not apply to the declared type at " +
          context,
        )
      }
    }
    _ =>
      raise SchemaError::InvalidSchema(
        "valid_values range must contain exactly two bounds at " + context,
      )
  }
}

///|
fn parse_range_endpoint(
  value : @model.IonValue,
  is_minimum : Bool,
  context : String,
) -> (String, Bool) raise SchemaError {
  let exclusive = match value.annotations() {
    [] => false
    [annotation] if annotation.text_value() == Some("exclusive") => true
    _ =>
      raise SchemaError::UnsupportedFeature(
        "range bounds may only use the exclusive annotation at " + context,
      )
  }
  let kind = match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some("min") => "min"
        Some("max") => "max"
        _ =>
          raise SchemaError::InvalidSchema(
            "range symbol bounds must be min or max at " + context,
          )
      }
    @model.IonValue::Int(_) => "int"
    @model.IonValue::Decimal(_) => "decimal"
    @model.IonValue::Float(number) =>
      if number.is_nan() || number.is_inf() {
        raise SchemaError::InvalidSchema(
          "range bounds must be finite numbers at " + context,
        )
      } else {
        "float"
      }
    @model.IonValue::Timestamp(_) => "timestamp"
    _ =>
      raise SchemaError::InvalidSchema(
        "range bounds must be numbers, timestamps, min, or max at " + context,
      )
  }
  if kind == "min" && !is_minimum {
    raise SchemaError::InvalidSchema(
      "min is only valid as the first range bound at " + context,
    )
  }
  if kind == "max" && is_minimum {
    raise SchemaError::InvalidSchema(
      "max is only valid as the second range bound at " + context,
    )
  }
  if (kind == "min" || kind == "max") && exclusive {
    raise SchemaError::InvalidSchema(
      "min and max cannot use the exclusive annotation at " + context,
    )
  }
  (kind, exclusive)
}

///|
fn valid_values_range_type(
  types : Array[NamedType],
  type_ref : TypeRef,
  range_kind : String,
) -> Bool raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar(name) =>
      if contains_string(["int", "float", "decimal"], range_kind) {
        contains_string(
          [
            "int", "float", "decimal", "number", "$int", "$float", "$decimal", "$number",
          ],
          name,
        )
      } else {
        name == "timestamp" || name == "$timestamp"
      }
    ResolvedType::Struct(_) | ResolvedType::List(_) => false
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
    TypeRef::NullOrBuiltin(name) =>
      if !is_supported_scalar(name) {
        raise SchemaError::UnsupportedFeature(
          "unsupported nullable built-in type \{name} at \{context}",
        )
      }
    TypeRef::NullOrNamed(name) if contains_type(types, name) => ()
    TypeRef::NullOrNamed(name) =>
      raise SchemaError::UnknownType("unknown type \{name} at \{context}")
  }
}

///|
fn is_supported_scalar(name : String) -> Bool {
  contains_string(
    [
      "bool", "int", "float", "decimal", "string", "symbol", "timestamp", "blob",
      "clob", "sexp", "any", "$any", "number", "document", "$null", "$bool", "$int",
      "$float", "$decimal", "$string", "$symbol", "$timestamp", "$blob", "$clob",
      "$list", "$sexp", "$struct", "$number", "$text", "$lob",
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
