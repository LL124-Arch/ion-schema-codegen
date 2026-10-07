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
fn ion_schema_codegen_regex_matches(
  value : @ion_model.IonValue,
  pattern : String,
) -> Bool {
  if value.is_null() {
    return false
  }
  let text = match value.without_annotations() {
    @ion_model.IonValue::String(text) => Some(text)
    @ion_model.IonValue::Symbol(symbol) => symbol.text_value()
    _ => None
  }
  match text {
    Some(text) => {
      let regex = @string.Regex(pattern) catch { _ => return false }
      regex.execute(text) is Some(_)
    }
    None => false
  }
}

///|
pub type Digits = String

///|
/// Validate regex constraints for Digits.
pub fn validate_regex_Digits(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "string") {
    raise ConversionError::TypeMismatch(
      path="Digits",
      expected="string",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "[0-9]+") {
    raise ConversionError::InvalidValue(
      path="Digits",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type AnchoredDigits = String

///|
/// Validate regex constraints for AnchoredDigits.
pub fn validate_regex_AnchoredDigits(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "string") {
    raise ConversionError::TypeMismatch(
      path="AnchoredDigits",
      expected="string",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "^[0-9]+$") {
    raise ConversionError::InvalidValue(
      path="AnchoredDigits",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type CaseInsensitive = String

///|
/// Validate regex constraints for CaseInsensitive.
pub fn validate_regex_CaseInsensitive(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "string") {
    raise ConversionError::TypeMismatch(
      path="CaseInsensitive",
      expected="string",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "(?i:ion)") {
    raise ConversionError::InvalidValue(
      path="CaseInsensitive",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type MultilineValue = String

///|
/// Validate regex constraints for MultilineValue.
pub fn validate_regex_MultilineValue(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "string") {
    raise ConversionError::TypeMismatch(
      path="MultilineValue",
      expected="string",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(
      value, "(^|\\n|\\r|\\u2028|\\u2029)value($|\\n|\\r|\\u2028|\\u2029)",
    ) {
    raise ConversionError::InvalidValue(
      path="MultilineValue",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type DotWithoutLineBreak = String

///|
/// Validate regex constraints for DotWithoutLineBreak.
pub fn validate_regex_DotWithoutLineBreak(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "string") {
    raise ConversionError::TypeMismatch(
      path="DotWithoutLineBreak",
      expected="string",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "a[^\\n\\r\\u2028\\u2029]b") {
    raise ConversionError::InvalidValue(
      path="DotWithoutLineBreak",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type SymbolCode = @ion_model.IonSymbol

///|
/// Validate regex constraints for SymbolCode.
pub fn validate_regex_SymbolCode(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "symbol") {
    raise ConversionError::TypeMismatch(
      path="SymbolCode",
      expected="symbol",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "(?i:[a-z]+)") {
    raise ConversionError::InvalidValue(
      path="SymbolCode",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type DigitAlias = Digits

///|
/// Validate regex constraints for DigitAlias.
pub fn validate_regex_DigitAlias(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "string") {
    raise ConversionError::TypeMismatch(
      path="DigitAlias",
      expected="string",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "[0-9]{2,}") {
    raise ConversionError::InvalidValue(
      path="DigitAlias",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "[0-9]+") {
    raise ConversionError::InvalidValue(
      path="DigitAlias",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type RegexArray = Array[AnchoredDigits]

///|
/// Convert an Ion list to RegexArray with element-level diagnostics.
pub fn from_ion_RegexArray(
  value : @ion_model.IonValue,
) -> RegexArray raise ConversionError {
  let type_path = "RegexArray"
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
  let converted : RegexArray = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : AnchoredDigits = match element.without_annotations() {
      @ion_model.IonValue::String(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="string",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    if !ion_schema_codegen_regex_matches(element, "^[0-9]+$") {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="regex",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert RegexArray into an Ion list.
pub fn to_ion_RegexArray(items : RegexArray) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::String(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct RegexRecord {
  code : AnchoredDigits
}

///|
/// Convert an Ion struct to RegexRecord with field-level diagnostics.
pub fn RegexRecord::from_ion(
  value : @ion_model.IonValue,
) -> RegexRecord raise ConversionError {
  let type_path = "RegexRecord"
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
          "code" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="RegexRecord.code")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="RegexRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="RegexRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : AnchoredDigits = match input_field_0 {
    Some(field_value) => {
      let field_path = "RegexRecord.code"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : AnchoredDigits = match
        field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      if !ion_schema_codegen_regex_matches(field_value, "^[0-9]+$") {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="regex",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="RegexRecord.code")
  }
  { code: ion_schema_codegen_value_0, }
}

///|
/// Convert RegexRecord into an Ion struct in schema field order.
pub fn RegexRecord::to_ion(self : RegexRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("code"),
      @ion_model.IonValue::String(self.code),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}
