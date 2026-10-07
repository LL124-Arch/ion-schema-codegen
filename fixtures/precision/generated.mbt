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
fn ion_schema_codegen_decimal_precision(value : @ion_model.IonValue) -> Int? {
  if value.is_null() {
    return None
  }
  match value.without_annotations() {
    @ion_model.IonValue::Decimal(decimal) => {
      let coefficient : @bigint.BigInt = decimal.coefficient()
      let digits = coefficient.to_string().length()
      let sign_digits = if coefficient.compare_int(0) < 0 { 1 } else { 0 }
      Some(digits - sign_digits)
    }
    _ => None
  }
}

///|
fn ion_schema_codegen_prefix_error(
  error : ConversionError,
  prefix : String,
) -> ConversionError {
  match error {
    ConversionError::TypeMismatch(path~, expected~, actual~) =>
      ConversionError::TypeMismatch(path=prefix + path, expected~, actual~)
    ConversionError::InvalidValue(path~, constraint~, actual~) =>
      ConversionError::InvalidValue(path=prefix + path, constraint~, actual~)
    ConversionError::MissingRequiredField(path~) =>
      ConversionError::MissingRequiredField(path=prefix + path)
    ConversionError::DuplicateField(path~) =>
      ConversionError::DuplicateField(path=prefix + path)
    ConversionError::FieldOccurrenceMismatch(path~, expected~, actual~) =>
      ConversionError::FieldOccurrenceMismatch(
        path=prefix + path,
        expected~,
        actual~,
      )
    ConversionError::UnknownField(path~) =>
      ConversionError::UnknownField(path=prefix + path)
    ConversionError::UnknownSymbol(path~, sid~) =>
      ConversionError::UnknownSymbol(path=prefix + path, sid~)
    ConversionError::NullNotAllowed(path~) =>
      ConversionError::NullNotAllowed(path=prefix + path)
    ConversionError::AnnotatedValueNotSupported(path~) =>
      ConversionError::AnnotatedValueNotSupported(path=prefix + path)
  }
}

///|
pub type PrecisionFour = @ion_model.IonDecimal

///|
/// Validate Decimal precision and exponent constraints for PrecisionFour.
pub fn validate_decimal_constraints_PrecisionFour(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "decimal") {
    raise ConversionError::TypeMismatch(
      path="PrecisionFour",
      expected="decimal",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_decimal_precision(value) {
    Some(ion_schema_codegen_precision_value) =>
      if ion_schema_codegen_precision_value < 4 ||
        ion_schema_codegen_precision_value > 4 {
        raise ConversionError::InvalidValue(
          path="PrecisionFour",
          constraint="precision",
          actual=ion_schema_codegen_precision_value.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="PrecisionFour",
        constraint="precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type PrecisionRange = @ion_model.IonDecimal

///|
/// Validate Decimal precision and exponent constraints for PrecisionRange.
pub fn validate_decimal_constraints_PrecisionRange(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "decimal") {
    raise ConversionError::TypeMismatch(
      path="PrecisionRange",
      expected="decimal",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_decimal_precision(value) {
    Some(ion_schema_codegen_precision_value) =>
      if ion_schema_codegen_precision_value < 2 ||
        ion_schema_codegen_precision_value > 4 {
        raise ConversionError::InvalidValue(
          path="PrecisionRange",
          constraint="precision",
          actual=ion_schema_codegen_precision_value.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="PrecisionRange",
        constraint="precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type BasePrecision = @ion_model.IonDecimal

///|
/// Validate Decimal precision and exponent constraints for BasePrecision.
pub fn validate_decimal_constraints_BasePrecision(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "decimal") {
    raise ConversionError::TypeMismatch(
      path="BasePrecision",
      expected="decimal",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_decimal_precision(value) {
    Some(ion_schema_codegen_precision_value) =>
      if ion_schema_codegen_precision_value < 2 {
        raise ConversionError::InvalidValue(
          path="BasePrecision",
          constraint="precision",
          actual=ion_schema_codegen_precision_value.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="BasePrecision",
        constraint="precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type AliasPrecision = BasePrecision

///|
/// Validate Decimal precision and exponent constraints for AliasPrecision.
pub fn validate_decimal_constraints_AliasPrecision(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "decimal") {
    raise ConversionError::TypeMismatch(
      path="AliasPrecision",
      expected="decimal",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_decimal_precision(value) {
    Some(ion_schema_codegen_precision_value) =>
      if ion_schema_codegen_precision_value < 4 ||
        ion_schema_codegen_precision_value > 4 {
        raise ConversionError::InvalidValue(
          path="AliasPrecision",
          constraint="precision",
          actual=ion_schema_codegen_precision_value.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="AliasPrecision",
        constraint="precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  match ion_schema_codegen_decimal_precision(value) {
    Some(ion_schema_codegen_precision_value) =>
      if ion_schema_codegen_precision_value < 2 {
        raise ConversionError::InvalidValue(
          path="AliasPrecision",
          constraint="precision",
          actual=ion_schema_codegen_precision_value.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="AliasPrecision",
        constraint="precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type NullablePrecision = @ion_model.IonValue

///|
/// Validate Decimal precision and exponent constraints for NullablePrecision.
pub fn validate_decimal_constraints_NullablePrecision(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$decimal") {
    raise ConversionError::TypeMismatch(
      path="NullablePrecision",
      expected="$decimal",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  match ion_schema_codegen_decimal_precision(value) {
    Some(ion_schema_codegen_precision_value) =>
      if ion_schema_codegen_precision_value < 1 ||
        ion_schema_codegen_precision_value > 4 {
        raise ConversionError::InvalidValue(
          path="NullablePrecision",
          constraint="precision",
          actual=ion_schema_codegen_precision_value.to_string(),
        )
      }
    None =>
      raise ConversionError::InvalidValue(
        path="NullablePrecision",
        constraint="precision",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
}

///|
pub type PrecisionValues = Array[PrecisionRange]

///|
/// Convert an Ion list to PrecisionValues with element-level diagnostics.
pub fn from_ion_PrecisionValues(
  value : @ion_model.IonValue,
) -> PrecisionValues raise ConversionError {
  let type_path = "PrecisionValues"
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
  let converted : PrecisionValues = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : PrecisionRange = match element.without_annotations() {
      @ion_model.IonValue::Decimal(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="decimal",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    match ion_schema_codegen_decimal_precision(element) {
      Some(ion_schema_codegen_precision_value) =>
        if ion_schema_codegen_precision_value < 2 ||
          ion_schema_codegen_precision_value > 4 {
          raise ConversionError::InvalidValue(
            path=element_path,
            constraint="precision",
            actual=ion_schema_codegen_precision_value.to_string(),
          )
        }
      None =>
        raise ConversionError::InvalidValue(
          path=element_path,
          constraint="precision",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert PrecisionValues into an Ion list.
pub fn to_ion_PrecisionValues(items : PrecisionValues) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Decimal(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct PrecisionRecord {
  exact : AliasPrecision
  values : PrecisionValues
}

///|
/// Convert an Ion struct to PrecisionRecord with field-level diagnostics.
pub fn PrecisionRecord::from_ion(
  value : @ion_model.IonValue,
) -> PrecisionRecord raise ConversionError {
  let type_path = "PrecisionRecord"
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
  let mut input_field_1 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "exact" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="PrecisionRecord.exact",
                )
              None => Some(field_value)
            }
          "values" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="PrecisionRecord.values",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="PrecisionRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="PrecisionRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : AliasPrecision = match input_field_0 {
    Some(field_value) => {
      let field_path = "PrecisionRecord.exact"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : AliasPrecision = match
        field_value.without_annotations() {
        @ion_model.IonValue::Decimal(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="decimal",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      match ion_schema_codegen_decimal_precision(field_value) {
        Some(ion_schema_codegen_precision_value) =>
          if ion_schema_codegen_precision_value < 4 ||
            ion_schema_codegen_precision_value > 4 {
            raise ConversionError::InvalidValue(
              path=field_path,
              constraint="precision",
              actual=ion_schema_codegen_precision_value.to_string(),
            )
          }
        None =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="precision",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      match ion_schema_codegen_decimal_precision(field_value) {
        Some(ion_schema_codegen_precision_value) =>
          if ion_schema_codegen_precision_value < 2 {
            raise ConversionError::InvalidValue(
              path=field_path,
              constraint="precision",
              actual=ion_schema_codegen_precision_value.to_string(),
            )
          }
        None =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="precision",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="PrecisionRecord.exact")
  }
  let ion_schema_codegen_value_1 : PrecisionValues = match input_field_1 {
    Some(field_value) => {
      let field_path = "PrecisionRecord.values"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : PrecisionValues = from_ion_PrecisionValues(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="PrecisionRecord.values")
  }
  { exact: ion_schema_codegen_value_0, values: ion_schema_codegen_value_1, }
}

///|
/// Convert PrecisionRecord into an Ion struct in schema field order.
pub fn PrecisionRecord::to_ion(self : PrecisionRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("exact"),
      @ion_model.IonValue::Decimal(self.exact),
    ),
  )
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("values"),
      to_ion_PrecisionValues(self.values),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}
