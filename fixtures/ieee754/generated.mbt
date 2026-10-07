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
fn ion_schema_codegen_binary16_float_compatible(value : Float) -> Bool {
  let bits = value.reinterpret_as_uint()
  let exponent_bits = ((bits >> 23) & 0xFFU).reinterpret_as_int()
  let fraction_bits = bits & 0x7FFFFFU
  if exponent_bits == 0xFF {
    true
  } else if exponent_bits == 0 {
    fraction_bits == 0U
  } else {
    let exponent = exponent_bits - 127
    let significand = fraction_bits | 0x800000U
    if exponent > 15 {
      false
    } else if exponent >= -14 {
      (significand & 0x1FFFU) == 0U
    } else if exponent < -24 {
      false
    } else {
      let discarded_bits = -exponent - 1
      let mask = (1U << discarded_bits) - 1U
      (significand & mask) == 0U
    }
  }
}

///|
fn ion_schema_codegen_ieee754_float_compatible(
  value : @ion_model.IonValue,
  format : String,
) -> Bool {
  if value.is_null() {
    return false
  }
  match value.without_annotations() {
    @ion_model.IonValue::Float(float) =>
      match format {
        "binary16" => ion_schema_codegen_binary16_float_compatible(float)
        "binary32" | "binary64" => true
        _ => false
      }
    _ => false
  }
}

///|
pub type HalfFloat = Float

///|
/// Validate ieee754_float constraints for HalfFloat.
pub fn validate_ieee754_float_HalfFloat(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "float") {
    raise ConversionError::TypeMismatch(
      path="HalfFloat",
      expected="float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_ieee754_float_compatible(value, "binary16") {
    raise ConversionError::InvalidValue(
      path="HalfFloat",
      constraint="ieee754_float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type SingleFloat = Float

///|
/// Validate ieee754_float constraints for SingleFloat.
pub fn validate_ieee754_float_SingleFloat(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "float") {
    raise ConversionError::TypeMismatch(
      path="SingleFloat",
      expected="float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_ieee754_float_compatible(value, "binary32") {
    raise ConversionError::InvalidValue(
      path="SingleFloat",
      constraint="ieee754_float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type DoubleFloat = Float

///|
/// Validate ieee754_float constraints for DoubleFloat.
pub fn validate_ieee754_float_DoubleFloat(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "float") {
    raise ConversionError::TypeMismatch(
      path="DoubleFloat",
      expected="float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_ieee754_float_compatible(value, "binary64") {
    raise ConversionError::InvalidValue(
      path="DoubleFloat",
      constraint="ieee754_float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type HalfFloatAlias = HalfFloat

///|
/// Validate ieee754_float constraints for HalfFloatAlias.
pub fn validate_ieee754_float_HalfFloatAlias(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "float") {
    raise ConversionError::TypeMismatch(
      path="HalfFloatAlias",
      expected="float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_ieee754_float_compatible(value, "binary16") {
    raise ConversionError::InvalidValue(
      path="HalfFloatAlias",
      constraint="ieee754_float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_ieee754_float_compatible(value, "binary16") {
    raise ConversionError::InvalidValue(
      path="HalfFloatAlias",
      constraint="ieee754_float",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type FloatArray = Array[HalfFloatAlias]

///|
/// Convert an Ion list to FloatArray with element-level diagnostics.
pub fn from_ion_FloatArray(
  value : @ion_model.IonValue,
) -> FloatArray raise ConversionError {
  let type_path = "FloatArray"
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
  let converted : FloatArray = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : HalfFloatAlias = match element.without_annotations() {
      @ion_model.IonValue::Float(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="float",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    if !ion_schema_codegen_ieee754_float_compatible(element, "binary16") {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="ieee754_float",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    if !ion_schema_codegen_ieee754_float_compatible(element, "binary16") {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="ieee754_float",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert FloatArray into an Ion list.
pub fn to_ion_FloatArray(items : FloatArray) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Float(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct FloatRecord {
  measurement : HalfFloatAlias
}

///|
/// Convert an Ion struct to FloatRecord with field-level diagnostics.
pub fn FloatRecord::from_ion(
  value : @ion_model.IonValue,
) -> FloatRecord raise ConversionError {
  let type_path = "FloatRecord"
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
          "measurement" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="FloatRecord.measurement",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="FloatRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="FloatRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : HalfFloatAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "FloatRecord.measurement"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : HalfFloatAlias = match
        field_value.without_annotations() {
        @ion_model.IonValue::Float(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="float",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      if !ion_schema_codegen_ieee754_float_compatible(field_value, "binary16") {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="ieee754_float",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      if !ion_schema_codegen_ieee754_float_compatible(field_value, "binary16") {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="ieee754_float",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="FloatRecord.measurement",
      )
  }
  { measurement: ion_schema_codegen_value_0, }
}

///|
/// Convert FloatRecord into an Ion struct in schema field order.
pub fn FloatRecord::to_ion(self : FloatRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("measurement"),
      @ion_model.IonValue::Float(self.measurement),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}
