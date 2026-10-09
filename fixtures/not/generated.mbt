///|
pub(all) suberror ConversionError {
  TypeMismatch(path~ : String, expected~ : String, actual~ : String)
  InvalidValue(path~ : String, constraint~ : String, actual~ : String)
  MissingRequiredField(path~ : String)
  DuplicateField(path~ : String)
  FieldOccurrenceMismatch(path~ : String, expected~ : String, actual~ : Int)
  UnknownField(path~ : String)
  UnknownSymbol(path~ : String, sid~ : Int)
  NullNotAllowed(path~ : String)
  AnnotatedValueNotSupported(path~ : String)
}

///|
fn ion_schema_codegen_kind_name(kind : @ion_model.IonNull) -> String {
  match kind {
    @ion_model.IonNull::Null => "null"
    @ion_model.IonNull::Bool => "bool"
    @ion_model.IonNull::Int => "int"
    @ion_model.IonNull::Float => "float"
    @ion_model.IonNull::Decimal => "decimal"
    @ion_model.IonNull::Timestamp => "timestamp"
    @ion_model.IonNull::Symbol => "symbol"
    @ion_model.IonNull::String => "string"
    @ion_model.IonNull::Blob => "blob"
    @ion_model.IonNull::Clob => "clob"
    @ion_model.IonNull::List => "list"
    @ion_model.IonNull::Sexp => "sexp"
    @ion_model.IonNull::Struct => "struct"
  }
}

///|
fn ion_schema_codegen_actual_type(value : @ion_model.IonValue) -> String {
  let kind = value.kind()
  match (value.is_null(), kind) {
    (true, @ion_model.IonNull::Null) => "null"
    (true, typed_kind) => "null.\{ion_schema_codegen_kind_name(typed_kind)}"
    (false, actual_kind) => ion_schema_codegen_kind_name(actual_kind)
  }
}

///|
fn ion_schema_codegen_matches_type(
  value : @ion_model.IonValue,
  expected : String,
) -> Bool {
  let kind = value.kind()
  let is_null = value.is_null()
  match expected {
    "any" => !is_null
    "$any" => true
    "$null" => is_null && kind == @ion_model.IonNull::Null
    "bool" => !is_null && kind == @ion_model.IonNull::Bool
    "$bool" => kind == @ion_model.IonNull::Bool
    "int" => !is_null && kind == @ion_model.IonNull::Int
    "$int" => kind == @ion_model.IonNull::Int
    "float" => !is_null && kind == @ion_model.IonNull::Float
    "$float" => kind == @ion_model.IonNull::Float
    "decimal" => !is_null && kind == @ion_model.IonNull::Decimal
    "$decimal" => kind == @ion_model.IonNull::Decimal
    "string" => !is_null && kind == @ion_model.IonNull::String
    "$string" => kind == @ion_model.IonNull::String
    "symbol" => !is_null && kind == @ion_model.IonNull::Symbol
    "$symbol" => kind == @ion_model.IonNull::Symbol
    "timestamp" => !is_null && kind == @ion_model.IonNull::Timestamp
    "$timestamp" => kind == @ion_model.IonNull::Timestamp
    "blob" => !is_null && kind == @ion_model.IonNull::Blob
    "$blob" => kind == @ion_model.IonNull::Blob
    "clob" => !is_null && kind == @ion_model.IonNull::Clob
    "$clob" => kind == @ion_model.IonNull::Clob
    "list" => !is_null && kind == @ion_model.IonNull::List
    "$list" => kind == @ion_model.IonNull::List
    "sexp" => !is_null && kind == @ion_model.IonNull::Sexp
    "$sexp" => kind == @ion_model.IonNull::Sexp
    "struct" => !is_null && kind == @ion_model.IonNull::Struct
    "$struct" => kind == @ion_model.IonNull::Struct
    "number" | "$number" =>
      (
        kind == @ion_model.IonNull::Int ||
        kind == @ion_model.IonNull::Float ||
        kind == @ion_model.IonNull::Decimal
      ) &&
      (expected == "$number" || !is_null)
    "text" | "$text" =>
      (kind == @ion_model.IonNull::String || kind == @ion_model.IonNull::Symbol) &&
      (expected == "$text" || !is_null)
    "lob" | "$lob" =>
      (kind == @ion_model.IonNull::Blob || kind == @ion_model.IonNull::Clob) &&
      (expected == "$lob" || !is_null)
    _ => false
  }
}

///|
pub type NotNumber = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NotNumber.
pub fn validate_type_NotNumber(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NotNumber",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if ion_schema_codegen_matches_type(value, "number") {
    raise ConversionError::InvalidValue(
      path="NotNumber",
      constraint="not",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type NotNumberAlias = NotNumber

///|
pub type NamedChoice = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NamedChoice.
pub fn validate_type_NamedChoice(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NamedChoice",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_type(value, "int") ||
    ion_schema_codegen_matches_type(value, "string")) {
    raise ConversionError::InvalidValue(
      path="NamedChoice",
      constraint="any_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_NamedChoice(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$any") {
      raise ConversionError::TypeMismatch(
        path="NamedChoice",
        expected="$any",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !(ion_schema_codegen_matches_type(value, "int") ||
      ion_schema_codegen_matches_type(value, "string")) {
      raise ConversionError::InvalidValue(
        path="NamedChoice",
        constraint="any_of",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type NotNamedChoice = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NotNamedChoice.
pub fn validate_type_NotNamedChoice(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NotNamedChoice",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if ion_schema_codegen_matches_named_NamedChoice(value) {
    raise ConversionError::InvalidValue(
      path="NotNamedChoice",
      constraint="not",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type NotNamedChoiceAlias = NotNamedChoice

///|
pub type NotNullableInt = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NotNullableInt.
pub fn validate_type_NotNullableInt(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NotNullableInt",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_type(value, "int") {
    raise ConversionError::InvalidValue(
      path="NotNullableInt",
      constraint="not",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type NotNumberList = Array[NotNumberAlias]

///|
/// Convert an Ion list to NotNumberList with element-level diagnostics.
pub fn from_ion_NotNumberList(
  value : @ion_model.IonValue,
) -> NotNumberList raise ConversionError {
  let type_path = "NotNumberList"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_elements = match value.without_annotations() {
    @ion_model.IonValue::List(elements) => elements
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="list",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let converted : NotNumberList = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    let item : NotNumberAlias = element
    if ion_schema_codegen_matches_type(element, "number") {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="not",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert NotNumberList into an Ion list.
pub fn to_ion_NotNumberList(items : NotNumberList) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct NotNumberRecord {
  value : NotNumberAlias
}

///|
/// Convert an Ion struct to NotNumberRecord with field-level diagnostics.
pub fn NotNumberRecord::from_ion(
  value : @ion_model.IonValue,
) -> NotNumberRecord raise ConversionError {
  let type_path = "NotNumberRecord"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_fields = match value.without_annotations() {
    @ion_model.IonValue::Struct(fields) => fields
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="struct",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "value" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NotNumberRecord.value",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="NotNumberRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="NotNumberRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : NotNumberAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "NotNumberRecord.value"
      let field_item : NotNumberAlias = field_value
      if ion_schema_codegen_matches_type(field_value, "number") {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="not",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="NotNumberRecord.value")
  }
  { value: ion_schema_codegen_value_0, }
}

///|
/// Convert NotNumberRecord into an Ion struct in schema field order.
pub fn NotNumberRecord::to_ion(self : NotNumberRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("value"), self.value))
  @ion_model.IonValue::Struct(output_fields)
}
