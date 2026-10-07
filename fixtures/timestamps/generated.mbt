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
fn ion_schema_codegen_timestamp_precision(value : @ion_model.IonValue) -> Int? {
  if value.is_null() {
    return None
  }
  match value.without_annotations() {
    @ion_model.IonValue::Timestamp(timestamp) => {
      if timestamp.year() <= 0 {
        return None
      }
      if timestamp.second() is Some(_) {
        match
          (timestamp.fraction_exponent(), timestamp.fraction_coefficient()) {
          (Some(exponent), Some(_)) if exponent < 0 => Some(12 - exponent)
          (None, None) => Some(12)
          _ => None
        }
      } else if timestamp.minute() is Some(_) {
        Some(9)
      } else if timestamp.day() is Some(_) {
        Some(6)
      } else if timestamp.month() is Some(_) {
        Some(3)
      } else {
        Some(0)
      }
    }
    _ => None
  }
}

///|
pub type TimestampYear = @ion_model.IonTimestamp

///|
/// Validate timestamp_precision constraints for TimestampYear.
pub fn validate_timestamp_precision_TimestampYear(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "timestamp") {
    raise ConversionError::TypeMismatch(
      path="TimestampYear",
      expected="timestamp",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_timestamp_precision(value) {
    Some(actual_length) =>
      if actual_length < 0 || actual_length > 0 {
        raise ConversionError::InvalidValue(
          path="TimestampYear",
          constraint="timestamp_precision",
          actual=actual_length.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="TimestampYear",
        constraint="timestamp_precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type TimestampSecond = @ion_model.IonTimestamp

///|
/// Validate timestamp_precision constraints for TimestampSecond.
pub fn validate_timestamp_precision_TimestampSecond(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "timestamp") {
    raise ConversionError::TypeMismatch(
      path="TimestampSecond",
      expected="timestamp",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_timestamp_precision(value) {
    Some(actual_length) =>
      if actual_length < 12 || actual_length > 12 {
        raise ConversionError::InvalidValue(
          path="TimestampSecond",
          constraint="timestamp_precision",
          actual=actual_length.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="TimestampSecond",
        constraint="timestamp_precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type TimestampMillisecond = @ion_model.IonTimestamp

///|
/// Validate timestamp_precision constraints for TimestampMillisecond.
pub fn validate_timestamp_precision_TimestampMillisecond(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "timestamp") {
    raise ConversionError::TypeMismatch(
      path="TimestampMillisecond",
      expected="timestamp",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_timestamp_precision(value) {
    Some(actual_length) =>
      if actual_length < 15 || actual_length > 15 {
        raise ConversionError::InvalidValue(
          path="TimestampMillisecond",
          constraint="timestamp_precision",
          actual=actual_length.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="TimestampMillisecond",
        constraint="timestamp_precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type TimestampMicrosecond = @ion_model.IonTimestamp

///|
/// Validate timestamp_precision constraints for TimestampMicrosecond.
pub fn validate_timestamp_precision_TimestampMicrosecond(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "timestamp") {
    raise ConversionError::TypeMismatch(
      path="TimestampMicrosecond",
      expected="timestamp",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_timestamp_precision(value) {
    Some(actual_length) =>
      if actual_length < 18 || actual_length > 18 {
        raise ConversionError::InvalidValue(
          path="TimestampMicrosecond",
          constraint="timestamp_precision",
          actual=actual_length.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="TimestampMicrosecond",
        constraint="timestamp_precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type TimestampNanosecond = @ion_model.IonTimestamp

///|
/// Validate timestamp_precision constraints for TimestampNanosecond.
pub fn validate_timestamp_precision_TimestampNanosecond(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "timestamp") {
    raise ConversionError::TypeMismatch(
      path="TimestampNanosecond",
      expected="timestamp",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_timestamp_precision(value) {
    Some(actual_length) =>
      if actual_length < 21 || actual_length > 21 {
        raise ConversionError::InvalidValue(
          path="TimestampNanosecond",
          constraint="timestamp_precision",
          actual=actual_length.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="TimestampNanosecond",
        constraint="timestamp_precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type TimestampAliasYear = TimestampYear

///|
/// Validate timestamp_precision constraints for TimestampAliasYear.
pub fn validate_timestamp_precision_TimestampAliasYear(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "timestamp") {
    raise ConversionError::TypeMismatch(
      path="TimestampAliasYear",
      expected="timestamp",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_timestamp_precision(value) {
    Some(actual_length) =>
      if actual_length < 0 || actual_length > 0 {
        raise ConversionError::InvalidValue(
          path="TimestampAliasYear",
          constraint="timestamp_precision",
          actual=actual_length.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="TimestampAliasYear",
        constraint="timestamp_precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  match ion_schema_codegen_timestamp_precision(value) {
    Some(actual_length) =>
      if actual_length < 0 || actual_length > 0 {
        raise ConversionError::InvalidValue(
          path="TimestampAliasYear",
          constraint="timestamp_precision",
          actual=actual_length.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="TimestampAliasYear",
        constraint="timestamp_precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type TimestampArray = Array[TimestampMillisecond]

///|
/// Convert an Ion list to TimestampArray with element-level diagnostics.
pub fn from_ion_TimestampArray(
  value : @ion_model.IonValue,
) -> TimestampArray raise ConversionError {
  let type_path = "TimestampArray"
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
  let converted : TimestampArray = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : TimestampMillisecond = match element.without_annotations() {
      @ion_model.IonValue::Timestamp(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="timestamp",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    match ion_schema_codegen_timestamp_precision(element) {
      Some(actual_length) =>
        if actual_length < 15 || actual_length > 15 {
          raise ConversionError::InvalidValue(
            path=element_path,
            constraint="timestamp_precision",
            actual=actual_length.to_string(),
          )
        }
      None =>
        raise ConversionError::InvalidValue(
          path=element_path,
          constraint="timestamp_precision",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert TimestampArray into an Ion list.
pub fn to_ion_TimestampArray(items : TimestampArray) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Timestamp(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct TimestampRecord {
  value : TimestampMicrosecond
}

///|
/// Convert an Ion struct to TimestampRecord with field-level diagnostics.
pub fn TimestampRecord::from_ion(
  value : @ion_model.IonValue,
) -> TimestampRecord raise ConversionError {
  let type_path = "TimestampRecord"
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
                  path="TimestampRecord.value",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="TimestampRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="TimestampRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : TimestampMicrosecond = match input_field_0 {
    Some(field_value) => {
      let field_path = "TimestampRecord.value"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : TimestampMicrosecond = match
        field_value.without_annotations() {
        @ion_model.IonValue::Timestamp(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="timestamp",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      match ion_schema_codegen_timestamp_precision(field_value) {
        Some(actual_length) =>
          if actual_length < 18 || actual_length > 18 {
            raise ConversionError::InvalidValue(
              path=field_path,
              constraint="timestamp_precision",
              actual=actual_length.to_string(),
            )
          }
        None =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="timestamp_precision",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="TimestampRecord.value")
  }
  { value: ion_schema_codegen_value_0, }
}

///|
/// Convert TimestampRecord into an Ion struct in schema field order.
pub fn TimestampRecord::to_ion(self : TimestampRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("value"),
      @ion_model.IonValue::Timestamp(self.value),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}
