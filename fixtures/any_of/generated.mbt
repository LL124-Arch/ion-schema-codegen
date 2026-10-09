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
fn ion_schema_codegen_valid_values_equal(
  left : @ion_model.IonValue,
  right : @ion_model.IonValue,
) -> Bool {
  let left = left.without_annotations()
  let right = right.without_annotations()
  match (left, right) {
    (@ion_model.IonValue::Float(left), @ion_model.IonValue::Float(right)) =>
      left == right || (left.is_nan() && right.is_nan())
    _ => left.equal(right)
  }
}

///|
fn ion_schema_codegen_has_annotation(
  value : @ion_model.IonValue,
  expected : String,
) -> Bool {
  for annotation in value.annotations() {
    if annotation.text_value() == Some(expected) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_is_minimum(value : @ion_model.IonValue) -> Bool {
  match value.without_annotations() {
    @ion_model.IonValue::Symbol(symbol) => symbol.text_value() == Some("min")
    _ => false
  }
}

///|
fn ion_schema_codegen_is_maximum(value : @ion_model.IonValue) -> Bool {
  match value.without_annotations() {
    @ion_model.IonValue::Symbol(symbol) => symbol.text_value() == Some("max")
    _ => false
  }
}

///|
fn ion_schema_codegen_valid_values_match(
  value : @ion_model.IonValue,
  candidate : @ion_model.IonValue,
) -> Bool {
  if ion_schema_codegen_has_annotation(candidate, "range") {
    ion_schema_codegen_range_contains(value, candidate)
  } else {
    ion_schema_codegen_valid_values_equal(value, candidate)
  }
}

///|
fn ion_schema_codegen_range_contains(
  value : @ion_model.IonValue,
  range : @ion_model.IonValue,
) -> Bool {
  if value.is_null() {
    return false
  }
  match range.without_annotations() {
    @ion_model.IonValue::List([minimum, maximum]) => {
      let minimum_matches = if ion_schema_codegen_is_minimum(minimum) {
        true
      } else {
        match ion_schema_codegen_compare_values(value, minimum) {
          Some(order) =>
            order > 0 ||
            (
              order == 0 &&
              !ion_schema_codegen_has_annotation(minimum, "exclusive")
            )
          None => false
        }
      }
      let maximum_matches = if ion_schema_codegen_is_maximum(maximum) {
        true
      } else {
        match ion_schema_codegen_compare_values(value, maximum) {
          Some(order) =>
            order < 0 ||
            (
              order == 0 &&
              !ion_schema_codegen_has_annotation(maximum, "exclusive")
            )
          None => false
        }
      }
      minimum_matches && maximum_matches
    }
    _ => false
  }
}

///|
fn ion_schema_codegen_compare_values(
  left : @ion_model.IonValue,
  right : @ion_model.IonValue,
) -> Int? {
  match
    (
      ion_schema_codegen_number_parts(left),
      ion_schema_codegen_number_parts(right),
    ) {
    (
      Some((left_coefficient, left_exponent)),
      Some((right_coefficient, right_exponent)),
    ) =>
      Some(
        ion_schema_codegen_compare_decimal_parts(
          left_coefficient, left_exponent, right_coefficient, right_exponent,
        ),
      )
    _ =>
      match (left.without_annotations(), right.without_annotations()) {
        (
          @ion_model.IonValue::Timestamp(left),
          @ion_model.IonValue::Timestamp(right),
        ) => Some(ion_schema_codegen_compare_timestamps(left, right))
        _ => None
      }
  }
}

///|
fn ion_schema_codegen_power(base : Int, exponent : Int) -> @bigint.BigInt {
  @bigint.BigInt::pow(
    @bigint.BigInt::from_int(base),
    @bigint.BigInt::from_int(exponent),
  )
}

///|
fn ion_schema_codegen_number_parts(
  value : @ion_model.IonValue,
) -> (@bigint.BigInt, Int)? {
  match value.without_annotations() {
    @ion_model.IonValue::Int(value) => Some((value, 0))
    @ion_model.IonValue::Decimal(value) =>
      Some((value.coefficient(), value.exponent()))
    @ion_model.IonValue::Float(value) => ion_schema_codegen_float_parts(value)
    _ => None
  }
}

///|
fn ion_schema_codegen_float_parts(value : Float) -> (@bigint.BigInt, Int)? {
  let bits = value.reinterpret_as_uint()
  let exponent_bits = ((bits >> 23) & 0xFF).reinterpret_as_int()
  let fraction_bits = (bits & 0x7FFFFF).reinterpret_as_int()
  if exponent_bits == 0xFF {
    return None
  }
  let significand = if exponent_bits == 0 {
    fraction_bits
  } else {
    fraction_bits + 0x800000
  }
  let binary_exponent = if exponent_bits == 0 {
    -149
  } else {
    exponent_bits - 127 - 23
  }
  let mut coefficient = @bigint.BigInt::from_int(significand)
  let decimal_exponent = if binary_exponent >= 0 {
    coefficient = coefficient * ion_schema_codegen_power(2, binary_exponent)
    0
  } else {
    coefficient = coefficient * ion_schema_codegen_power(5, -binary_exponent)
    binary_exponent
  }
  if (bits & 0x80000000) != 0 {
    coefficient = coefficient.neg()
  }
  Some((coefficient, decimal_exponent))
}

///|
fn ion_schema_codegen_compare_decimal_parts(
  left_coefficient : @bigint.BigInt,
  left_exponent : Int,
  right_coefficient : @bigint.BigInt,
  right_exponent : Int,
) -> Int {
  let left_sign = left_coefficient.compare_int(0)
  let right_sign = right_coefficient.compare_int(0)
  if left_sign != right_sign {
    return if left_sign < right_sign { -1 } else { 1 }
  }
  if left_sign == 0 {
    return 0
  }
  let left_order = @bigint.BigInt::from_int(
      left_coefficient.to_string().length(),
    ) +
    @bigint.BigInt::from_int(left_exponent)
  let right_order = @bigint.BigInt::from_int(
      right_coefficient.to_string().length(),
    ) +
    @bigint.BigInt::from_int(right_exponent)
  let order = left_order.compare(right_order)
  if order != 0 {
    return if left_sign < 0 { -order } else { order }
  }
  let common_exponent = if left_exponent < right_exponent {
    left_exponent
  } else {
    right_exponent
  }
  let left_scaled = left_coefficient *
    ion_schema_codegen_power(10, left_exponent - common_exponent)
  let right_scaled = right_coefficient *
    ion_schema_codegen_power(10, right_exponent - common_exponent)
  left_scaled.compare(right_scaled)
}

///|
fn ion_schema_codegen_is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn ion_schema_codegen_days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if ion_schema_codegen_is_leap_year(year) { 29 } else { 28 }
    _ => 30
  }
}

///|
fn ion_schema_codegen_timestamp_seconds(
  timestamp : @ion_model.IonTimestamp,
) -> @bigint.BigInt {
  let previous_year = @bigint.BigInt::from_int(timestamp.year()) -
    @bigint.BigInt::from_int(1)
  let mut days = previous_year * @bigint.BigInt::from_int(365) +
    previous_year / @bigint.BigInt::from_int(4) -
    previous_year / @bigint.BigInt::from_int(100) +
    previous_year / @bigint.BigInt::from_int(400)
  let month = timestamp.month().unwrap_or(1)
  for prior_month in 1..<month {
    days = days +
      @bigint.BigInt::from_int(
        ion_schema_codegen_days_in_month(timestamp.year(), prior_month),
      )
  }
  if month > 2 && ion_schema_codegen_is_leap_year(timestamp.year()) {
    days = days + @bigint.BigInt::from_int(1)
  }
  days = days + @bigint.BigInt::from_int(timestamp.day().unwrap_or(1) - 1)
  let local_seconds = timestamp.hour().unwrap_or(0) * 3600 +
    timestamp.minute().unwrap_or(0) * 60 +
    timestamp.second().unwrap_or(0)
  days * @bigint.BigInt::from_int(86400) +
  @bigint.BigInt::from_int(local_seconds) -
  @bigint.BigInt::from_int(timestamp.offset_minutes().unwrap_or(0) * 60)
}

///|
fn ion_schema_codegen_compare_timestamps(
  left : @ion_model.IonTimestamp,
  right : @ion_model.IonTimestamp,
) -> Int {
  let seconds_order = ion_schema_codegen_timestamp_seconds(left).compare(
    ion_schema_codegen_timestamp_seconds(right),
  )
  if seconds_order != 0 {
    return seconds_order
  }
  let left_fraction = left
    .fraction_coefficient()
    .unwrap_or(@bigint.BigInt::from_int(0))
  let left_exponent = left.fraction_exponent().unwrap_or(0)
  let right_fraction = right
    .fraction_coefficient()
    .unwrap_or(@bigint.BigInt::from_int(0))
  let right_exponent = right.fraction_exponent().unwrap_or(0)
  ion_schema_codegen_compare_decimal_parts(
    left_fraction, left_exponent, right_fraction, right_exponent,
  )
}

///|
pub type NumberOrText = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NumberOrText.
pub fn validate_type_NumberOrText(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NumberOrText",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_type(value, "number") ||
    ion_schema_codegen_matches_type(value, "text")) {
    raise ConversionError::InvalidValue(
      path="NumberOrText",
      constraint="any_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type NonNegativeSmall = @bigint.BigInt

///|
/// Test whether an Ion value satisfies valid_values for NonNegativeSmall.
pub fn is_valid_values_NonNegativeSmall(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("range::[0, 9]") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for NonNegativeSmall.
pub fn validate_NonNegativeSmall(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "int") {
    raise ConversionError::TypeMismatch(
      path="NonNegativeSmall",
      expected="int",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_NonNegativeSmall(value) {
    raise ConversionError::InvalidValue(
      path="NonNegativeSmall",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_NonNegativeSmall(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="NonNegativeSmall",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_NonNegativeSmall(value) {
      raise ConversionError::InvalidValue(
        path="NonNegativeSmall",
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type NegativeSmall = @bigint.BigInt

///|
/// Test whether an Ion value satisfies valid_values for NegativeSmall.
pub fn is_valid_values_NegativeSmall(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("range::[-9, -1]") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for NegativeSmall.
pub fn validate_NegativeSmall(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "int") {
    raise ConversionError::TypeMismatch(
      path="NegativeSmall",
      expected="int",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_NegativeSmall(value) {
    raise ConversionError::InvalidValue(
      path="NegativeSmall",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_NegativeSmall(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="NegativeSmall",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_NegativeSmall(value) {
      raise ConversionError::InvalidValue(
        path="NegativeSmall",
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type SignedSmall = @ion_model.IonValue

///|
/// Validate the type algebra constraints for SignedSmall.
pub fn validate_type_SignedSmall(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="SignedSmall",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_named_NonNegativeSmall(value) ||
    ion_schema_codegen_matches_named_NegativeSmall(value)) {
    raise ConversionError::InvalidValue(
      path="SignedSmall",
      constraint="any_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type Overlapping = @ion_model.IonValue

///|
/// Validate the type algebra constraints for Overlapping.
pub fn validate_type_Overlapping(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="Overlapping",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_type(value, "int") ||
    ion_schema_codegen_matches_type(value, "number")) {
    raise ConversionError::InvalidValue(
      path="Overlapping",
      constraint="any_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type MaybeInt = @ion_model.IonValue

///|
/// Validate the type algebra constraints for MaybeInt.
pub fn validate_type_MaybeInt(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="MaybeInt",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !((
      ion_schema_codegen_matches_type(value, "$null") ||
      ion_schema_codegen_matches_type(value, "int")
    ) ||
    ion_schema_codegen_matches_type(value, "string")) {
    raise ConversionError::InvalidValue(
      path="MaybeInt",
      constraint="any_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type NumberOrTextAlias = NumberOrText

///|
pub type ChoiceList = Array[NumberOrTextAlias]

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
    let item : NumberOrTextAlias = element
    if !(ion_schema_codegen_matches_type(element, "number") ||
      ion_schema_codegen_matches_type(element, "text")) {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="any_of",
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
  value : NumberOrTextAlias
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
  let ion_schema_codegen_value_0 : NumberOrTextAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "ChoiceRecord.value"
      let field_item : NumberOrTextAlias = field_value
      if !(ion_schema_codegen_matches_type(field_value, "number") ||
        ion_schema_codegen_matches_type(field_value, "text")) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="any_of",
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

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline9.
fn is_valid_values_IonSchemaCodegenInternalInline9(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("2\n4") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline9(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_9",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline9(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_9",
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type InlineNumberOrText = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineNumberOrText.
pub fn validate_type_InlineNumberOrText(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineNumberOrText",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline9(value) ||
    ion_schema_codegen_matches_type(value, "string")) {
    raise ConversionError::InvalidValue(
      path="InlineNumberOrText",
      constraint="any_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline11(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "string") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_11",
        expected="string",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_regex_matches(value, "^ion$") {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_11",
        constraint="regex",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type InlinePatternOrInt = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlinePatternOrInt.
pub fn validate_type_InlinePatternOrInt(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlinePatternOrInt",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline11(value) ||
    ion_schema_codegen_matches_type(value, "int")) {
    raise ConversionError::InvalidValue(
      path="InlinePatternOrInt",
      constraint="any_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}
