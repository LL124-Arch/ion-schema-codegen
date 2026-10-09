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
pub type IntegerOrText = @ion_model.IonValue

///|
/// Validate the type algebra constraints for IntegerOrText.
pub fn validate_type_IntegerOrText(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="IntegerOrText",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let mut ion_schema_codegen_one_of_match_count_IntegerOrText_0 = 0
  if ion_schema_codegen_matches_type(value, "int") {
    ion_schema_codegen_one_of_match_count_IntegerOrText_0 += 1
  }
  if ion_schema_codegen_matches_type(value, "string") {
    ion_schema_codegen_one_of_match_count_IntegerOrText_0 += 1
  }
  if ion_schema_codegen_one_of_match_count_IntegerOrText_0 != 1 {
    raise ConversionError::InvalidValue(
      path="IntegerOrText",
      constraint="one_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type OverlappingNumeric = @ion_model.IonValue

///|
/// Validate the type algebra constraints for OverlappingNumeric.
pub fn validate_type_OverlappingNumeric(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="OverlappingNumeric",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let mut ion_schema_codegen_one_of_match_count_OverlappingNumeric_0 = 0
  if ion_schema_codegen_matches_type(value, "float") {
    ion_schema_codegen_one_of_match_count_OverlappingNumeric_0 += 1
  }
  if ion_schema_codegen_matches_type(value, "number") {
    ion_schema_codegen_one_of_match_count_OverlappingNumeric_0 += 1
  }
  if ion_schema_codegen_one_of_match_count_OverlappingNumeric_0 != 1 {
    raise ConversionError::InvalidValue(
      path="OverlappingNumeric",
      constraint="one_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type RepeatedFloat = @ion_model.IonValue

///|
/// Validate the type algebra constraints for RepeatedFloat.
pub fn validate_type_RepeatedFloat(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="RepeatedFloat",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let mut ion_schema_codegen_one_of_match_count_RepeatedFloat_0 = 0
  if ion_schema_codegen_matches_type(value, "float") {
    ion_schema_codegen_one_of_match_count_RepeatedFloat_0 += 1
  }
  if ion_schema_codegen_matches_type(value, "float") {
    ion_schema_codegen_one_of_match_count_RepeatedFloat_0 += 1
  }
  if ion_schema_codegen_one_of_match_count_RepeatedFloat_0 != 1 {
    raise ConversionError::InvalidValue(
      path="RepeatedFloat",
      constraint="one_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type NullableOverlap = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NullableOverlap.
pub fn validate_type_NullableOverlap(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NullableOverlap",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let mut ion_schema_codegen_one_of_match_count_NullableOverlap_0 = 0
  if ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_type(value, "int") {
    ion_schema_codegen_one_of_match_count_NullableOverlap_0 += 1
  }
  if ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_type(value, "float") {
    ion_schema_codegen_one_of_match_count_NullableOverlap_0 += 1
  }
  if ion_schema_codegen_one_of_match_count_NullableOverlap_0 != 1 {
    raise ConversionError::InvalidValue(
      path="NullableOverlap",
      constraint="one_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type NullableTypedInt = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NullableTypedInt.
pub fn validate_type_NullableTypedInt(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NullableTypedInt",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let mut ion_schema_codegen_one_of_match_count_NullableTypedInt_0 = 0
  if ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_type(value, "$int") {
    ion_schema_codegen_one_of_match_count_NullableTypedInt_0 += 1
  }
  if ion_schema_codegen_matches_type(value, "string") {
    ion_schema_codegen_one_of_match_count_NullableTypedInt_0 += 1
  }
  if ion_schema_codegen_one_of_match_count_NullableTypedInt_0 != 1 {
    raise ConversionError::InvalidValue(
      path="NullableTypedInt",
      constraint="one_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type IntegerOrTextAlias = IntegerOrText

///|
pub type ChoiceList = Array[IntegerOrTextAlias]

///|
/// Convert an Ion list to ChoiceList with element-level diagnostics.
pub fn from_ion_ChoiceList(
  value : @ion_model.IonValue,
) -> ChoiceList raise ConversionError {
  let type_path = "ChoiceList"
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
  let converted : ChoiceList = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    let item : IntegerOrTextAlias = element
    let mut ion_schema_codegen_one_of_match_count_IntegerOrText_0 = 0
    if ion_schema_codegen_matches_type(element, "int") {
      ion_schema_codegen_one_of_match_count_IntegerOrText_0 += 1
    }
    if ion_schema_codegen_matches_type(element, "string") {
      ion_schema_codegen_one_of_match_count_IntegerOrText_0 += 1
    }
    if ion_schema_codegen_one_of_match_count_IntegerOrText_0 != 1 {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="one_of",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert ChoiceList into an Ion list.
pub fn to_ion_ChoiceList(items : ChoiceList) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct ChoiceRecord {
  value : IntegerOrTextAlias
}

///|
/// Convert an Ion struct to ChoiceRecord with field-level diagnostics.
pub fn ChoiceRecord::from_ion(
  value : @ion_model.IonValue,
) -> ChoiceRecord raise ConversionError {
  let type_path = "ChoiceRecord"
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
                raise ConversionError::DuplicateField(path="ChoiceRecord.value")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="ChoiceRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="ChoiceRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : IntegerOrTextAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "ChoiceRecord.value"
      let field_item : IntegerOrTextAlias = field_value
      let mut ion_schema_codegen_one_of_match_count_IntegerOrText_0 = 0
      if ion_schema_codegen_matches_type(field_value, "int") {
        ion_schema_codegen_one_of_match_count_IntegerOrText_0 += 1
      }
      if ion_schema_codegen_matches_type(field_value, "string") {
        ion_schema_codegen_one_of_match_count_IntegerOrText_0 += 1
      }
      if ion_schema_codegen_one_of_match_count_IntegerOrText_0 != 1 {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="one_of",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="ChoiceRecord.value")
  }
  { value: ion_schema_codegen_value_0, }
}

///|
/// Convert ChoiceRecord into an Ion struct in schema field order.
pub fn ChoiceRecord::to_ion(self : ChoiceRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("value"), self.value))
  @ion_model.IonValue::Struct(output_fields)
}
