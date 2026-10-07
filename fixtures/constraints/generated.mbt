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
fn ion_schema_codegen_symbols_equal(
  left : @ion_model.IonSymbol,
  right : @ion_model.IonSymbol,
) -> Bool {
  match (left.text_value(), right.text_value()) {
    (Some(left_text), Some(right_text)) => left_text == right_text
    (None, None) => left.sid_value() == right.sid_value()
    _ => false
  }
}

///|
fn ion_schema_codegen_annotations_equal(
  left : Array[@ion_model.IonSymbol],
  right : Array[@ion_model.IonSymbol],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if !ion_schema_codegen_symbols_equal(left[index], right[index]) {
      return false
    }
  }
  true
}

///|
fn ion_schema_codegen_values_equal(
  left : @ion_model.IonValue,
  right : @ion_model.IonValue,
) -> Bool {
  match (left, right) {
    (
      @ion_model.IonValue::Annotated(left_annotations, left_value),
      @ion_model.IonValue::Annotated(right_annotations, right_value),
    ) =>
      ion_schema_codegen_annotations_equal(left_annotations, right_annotations) &&
      ion_schema_codegen_values_equal(left_value, right_value)
    (@ion_model.IonValue::Annotated(_, _), _)
    | (_, @ion_model.IonValue::Annotated(_, _)) => false
    (@ion_model.IonValue::Null(left), @ion_model.IonValue::Null(right)) =>
      left == right
    (@ion_model.IonValue::Bool(left), @ion_model.IonValue::Bool(right)) =>
      left == right
    (@ion_model.IonValue::Int(left), @ion_model.IonValue::Int(right)) =>
      left == right
    (@ion_model.IonValue::Float(left), @ion_model.IonValue::Float(right)) =>
      left == right || (left.is_nan() && right.is_nan())
    (@ion_model.IonValue::Decimal(left), @ion_model.IonValue::Decimal(right)) =>
      left.coefficient() == right.coefficient() &&
      left.exponent() == right.exponent()
    (@ion_model.IonValue::Timestamp(left), @ion_model.IonValue::Timestamp(right)
    ) => left == right
    (@ion_model.IonValue::Symbol(left), @ion_model.IonValue::Symbol(right)) =>
      ion_schema_codegen_symbols_equal(left, right)
    (@ion_model.IonValue::String(left), @ion_model.IonValue::String(right)) =>
      left == right
    (@ion_model.IonValue::Blob(left), @ion_model.IonValue::Blob(right)) =>
      left == right
    (@ion_model.IonValue::Clob(left), @ion_model.IonValue::Clob(right)) =>
      left == right
    (@ion_model.IonValue::List(left), @ion_model.IonValue::List(right))
    | (@ion_model.IonValue::Sexp(left), @ion_model.IonValue::Sexp(right)) =>
      ion_schema_codegen_sequences_equal(left, right)
    (@ion_model.IonValue::Struct(left), @ion_model.IonValue::Struct(right)) =>
      ion_schema_codegen_structs_equal(left, right)
    _ => false
  }
}

///|
fn ion_schema_codegen_sequences_equal(
  left : Array[@ion_model.IonValue],
  right : Array[@ion_model.IonValue],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if !ion_schema_codegen_values_equal(left[index], right[index]) {
      return false
    }
  }
  true
}

///|
fn ion_schema_codegen_structs_equal(
  left : Array[(@ion_model.IonSymbol, @ion_model.IonValue)],
  right : Array[(@ion_model.IonSymbol, @ion_model.IonValue)],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  let matched : Array[Bool] = []
  for _ in right {
    matched.push(false)
  }
  for (left_symbol, left_value) in left {
    let mut index = 0
    let mut found = false
    for (right_symbol, right_value) in right {
      if !matched[index] &&
        ion_schema_codegen_symbols_equal(left_symbol, right_symbol) &&
        ion_schema_codegen_values_equal(left_value, right_value) {
        matched[index] = true
        found = true
        break
      }
      index += 1
    }
    if !found {
      return false
    }
  }
  true
}

///|
fn ion_schema_codegen_check_distinct(
  values : Array[@ion_model.IonValue],
  path : String,
) -> Unit raise ConversionError {
  let previous : Array[@ion_model.IonValue] = []
  let mut index = 0
  for value in values {
    for prior in previous {
      if ion_schema_codegen_values_equal(prior, value) {
        raise ConversionError::InvalidValue(
          path=path + "[" + index.to_string() + "]",
          constraint="distinct::element",
          actual=ion_schema_codegen_actual_type(value),
        )
      }
    }
    previous.push(value)
    index += 1
  }
}

///|
fn ion_schema_codegen_check_distinct_symbols(
  symbols : Array[@ion_model.IonSymbol],
  path : String,
) -> Unit raise ConversionError {
  let previous : Array[@ion_model.IonSymbol] = []
  let mut index = 0
  for symbol in symbols {
    for prior in previous {
      if ion_schema_codegen_symbols_equal(prior, symbol) {
        raise ConversionError::InvalidValue(
          path=path +
            "." +
            symbol.text_value().unwrap_or("<field>") +
            "[" +
            index.to_string() +
            "]",
          constraint="distinct::field_names",
          actual="symbol",
        )
      }
    }
    previous.push(symbol)
    index += 1
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
pub type UniqueInts = Array[@bigint.BigInt]

///|
/// Convert an Ion list to UniqueInts with element-level diagnostics.
pub fn from_ion_UniqueInts(
  value : @ion_model.IonValue,
) -> UniqueInts raise ConversionError {
  let type_path = "UniqueInts"
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
  ion_schema_codegen_check_distinct(input_elements, type_path)
  let converted : UniqueInts = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : @bigint.BigInt = match element.without_annotations() {
      @ion_model.IonValue::Int(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="int",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert UniqueInts into an Ion list.
pub fn to_ion_UniqueInts(items : UniqueInts) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Int(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type UniqueValues = Array[@ion_model.IonValue]

///|
/// Convert an Ion list to UniqueValues with element-level diagnostics.
pub fn from_ion_UniqueValues(
  value : @ion_model.IonValue,
) -> UniqueValues raise ConversionError {
  let type_path = "UniqueValues"
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
  ion_schema_codegen_check_distinct(input_elements, type_path)
  let converted : UniqueValues = []
  for element in input_elements {
    let item : @ion_model.IonValue = element
    converted.push(item)
  }
  converted
}

///|
/// Convert UniqueValues into an Ion list.
pub fn to_ion_UniqueValues(items : UniqueValues) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type NullableUniqueValues = Array[@ion_model.IonValue]

///|
/// Convert an Ion list to NullableUniqueValues with element-level diagnostics.
pub fn from_ion_NullableUniqueValues(
  value : @ion_model.IonValue,
) -> NullableUniqueValues raise ConversionError {
  let type_path = "NullableUniqueValues"
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
  ion_schema_codegen_check_distinct(input_elements, type_path)
  let converted : NullableUniqueValues = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    let item : @ion_model.IonValue = if ion_schema_codegen_matches_type(
        element, "$null",
      ) {
      element
    } else {
      if !ion_schema_codegen_matches_type(element, "int") {
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="int",
          actual=ion_schema_codegen_actual_type(element),
        )
      }
      element
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert NullableUniqueValues into an Ion list.
pub fn to_ion_NullableUniqueValues(
  items : NullableUniqueValues,
) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type UniqueExpression = Array[@ion_model.IonValue]

///|
pub(all) struct UniqueExpressionRecord {
  expression : UniqueExpression
}

///|
/// Convert an Ion struct to UniqueExpressionRecord with field-level diagnostics.
pub fn UniqueExpressionRecord::from_ion(
  value : @ion_model.IonValue,
) -> UniqueExpressionRecord raise ConversionError {
  let type_path = "UniqueExpressionRecord"
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
          "expression" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="UniqueExpressionRecord.expression",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="UniqueExpressionRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="UniqueExpressionRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : UniqueExpression = match input_field_0 {
    Some(field_value) => {
      let field_path = "UniqueExpressionRecord.expression"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : UniqueExpression = match
        field_value.without_annotations() {
        @ion_model.IonValue::Sexp(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="sexp",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      let ion_schema_codegen_sexp_elements = match
        field_value.without_annotations() {
        @ion_model.IonValue::Sexp(elements) => elements
        _ =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="element",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      let mut ion_schema_codegen_sexp_element_index = 0
      for
        ion_schema_codegen_sexp_element_value in ion_schema_codegen_sexp_elements {
        let ion_schema_codegen_sexp_element_path = field_path +
          "[" +
          ion_schema_codegen_sexp_element_index.to_string() +
          "]"
        if !ion_schema_codegen_matches_type(
            ion_schema_codegen_sexp_element_value, "$any",
          ) {
          raise ConversionError::TypeMismatch(
            path=ion_schema_codegen_sexp_element_path,
            expected="$any",
            actual=ion_schema_codegen_actual_type(
              ion_schema_codegen_sexp_element_value,
            ),
          )
        }
        ion_schema_codegen_sexp_element_index += 1
      }
      ion_schema_codegen_check_distinct(
        ion_schema_codegen_sexp_elements, field_path,
      )
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="UniqueExpressionRecord.expression",
      )
  }
  { expression: ion_schema_codegen_value_0, }
}

///|
/// Convert UniqueExpressionRecord into an Ion struct in schema field order.
pub fn UniqueExpressionRecord::to_ion(
  self : UniqueExpressionRecord,
) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("expression"),
      @ion_model.IonValue::Sexp(self.expression),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct UniqueRecord {
  ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ]
}

///|
/// Convert an Ion struct to UniqueRecord with field-level diagnostics.
pub fn UniqueRecord::from_ion(
  value : @ion_model.IonValue,
) -> UniqueRecord raise ConversionError {
  let type_path = "UniqueRecord"
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
  let mut ion_schema_codegen_struct_element_index = 0
  for
    (
      ion_schema_codegen_struct_element_symbol,
      ion_schema_codegen_struct_element_value,
    ) in input_fields {
    let ion_schema_codegen_struct_element_path = type_path +
      "." +
      ion_schema_codegen_struct_element_symbol.text_value().unwrap_or("<field>") +
      "[" +
      ion_schema_codegen_struct_element_index.to_string() +
      "]"
    if !ion_schema_codegen_matches_type(
        ion_schema_codegen_struct_element_value, "$any",
      ) {
      raise ConversionError::TypeMismatch(
        path=ion_schema_codegen_struct_element_path,
        expected="$any",
        actual=ion_schema_codegen_actual_type(
          ion_schema_codegen_struct_element_value,
        ),
      )
    }
    ion_schema_codegen_struct_element_index += 1
  }
  let ion_schema_codegen_distinct_UniqueRecord : Array[@ion_model.IonValue] = []
  for (_, ion_schema_codegen_distinct_value) in input_fields {
    ion_schema_codegen_distinct_UniqueRecord.push(
      ion_schema_codegen_distinct_value,
    )
  }
  ion_schema_codegen_check_distinct(
    ion_schema_codegen_distinct_UniqueRecord, type_path,
  )
  let ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ] = []
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          _ => ion_schema_codegen_open_content.push((field_symbol, field_value))
        }
      None => ion_schema_codegen_open_content.push((field_symbol, field_value))
    }
  }
  { ion_schema_codegen_open_content, }
}

///|
/// Convert UniqueRecord into an Ion struct in schema field order.
pub fn UniqueRecord::to_ion(self : UniqueRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  for (field_symbol, field_value) in self.ion_schema_codegen_open_content {
    output_fields.push((field_symbol, field_value))
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type UniqueStream = Array[@ion_model.IonValue]

///|
/// Convert an Ion document stream to UniqueStream.
pub fn from_ion_document_UniqueStream(
  values : Array[@ion_model.IonValue],
) -> UniqueStream raise ConversionError {
  let type_path = "UniqueStream"
  ion_schema_codegen_check_distinct(values, type_path)
  let mut ion_schema_codegen_document_index_13 = 0
  for ion_schema_codegen_document_value_13 in values {
    let ion_schema_codegen_document_path_13 = type_path +
      "[" +
      ion_schema_codegen_document_index_13.to_string() +
      "]"
    if !ion_schema_codegen_matches_type(
        ion_schema_codegen_document_value_13, "$any",
      ) {
      raise ConversionError::TypeMismatch(
        path=ion_schema_codegen_document_path_13,
        expected="$any",
        actual=ion_schema_codegen_actual_type(
          ion_schema_codegen_document_value_13,
        ),
      )
    }
    ion_schema_codegen_document_index_13 += 1
  }
  values
}

///|
/// Convert UniqueStream to an Ion document stream.
pub fn to_ion_document_UniqueStream(
  values : UniqueStream,
) -> Array[@ion_model.IonValue] {
  values
}

///|
pub type AllowedNames = @ion_model.IonSymbol

///|
/// Test whether an Ion value satisfies valid_values for AllowedNames.
pub fn is_valid_values_AllowedNames(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("alpha\nbeta") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for AllowedNames.
pub fn validate_AllowedNames(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "symbol") {
    raise ConversionError::TypeMismatch(
      path="AllowedNames",
      expected="symbol",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_AllowedNames(value) {
    raise ConversionError::InvalidValue(
      path="AllowedNames",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub(all) struct NamedFields {
  ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ]
}

///|
/// Convert an Ion struct to NamedFields with field-level diagnostics.
pub fn NamedFields::from_ion(
  value : @ion_model.IonValue,
) -> NamedFields raise ConversionError {
  let type_path = "NamedFields"
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
  let mut ion_schema_codegen_field_name_index_NamedFields = 0
  for (ion_schema_codegen_field_name_symbol_NamedFields, _) in input_fields {
    let ion_schema_codegen_field_name_path_NamedFields = type_path +
      "." +
      ion_schema_codegen_field_name_symbol_NamedFields
      .text_value()
      .unwrap_or("<field>") +
      "[" +
      ion_schema_codegen_field_name_index_NamedFields.to_string() +
      "]"
    if @ion_model.IonValue::Symbol(
        ion_schema_codegen_field_name_symbol_NamedFields,
      ).is_null() {
      raise ConversionError::NullNotAllowed(
        path=ion_schema_codegen_field_name_path_NamedFields,
      )
    }
    if !ion_schema_codegen_matches_type(
        @ion_model.IonValue::Symbol(
          ion_schema_codegen_field_name_symbol_NamedFields,
        ),
        "symbol",
      ) {
      raise ConversionError::TypeMismatch(
        path=ion_schema_codegen_field_name_path_NamedFields,
        expected="symbol",
        actual=ion_schema_codegen_actual_type(
          @ion_model.IonValue::Symbol(
            ion_schema_codegen_field_name_symbol_NamedFields,
          ),
        ),
      )
    }
    if !is_valid_values_AllowedNames(
        @ion_model.IonValue::Symbol(
          ion_schema_codegen_field_name_symbol_NamedFields,
        ),
      ) {
      raise ConversionError::InvalidValue(
        path=ion_schema_codegen_field_name_path_NamedFields,
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(
          @ion_model.IonValue::Symbol(
            ion_schema_codegen_field_name_symbol_NamedFields,
          ),
        ),
      )
    }
    ion_schema_codegen_field_name_index_NamedFields += 1
  }
  let ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ] = []
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          _ => ion_schema_codegen_open_content.push((field_symbol, field_value))
        }
      None => ion_schema_codegen_open_content.push((field_symbol, field_value))
    }
  }
  { ion_schema_codegen_open_content, }
}

///|
/// Convert NamedFields into an Ion struct in schema field order.
pub fn NamedFields::to_ion(self : NamedFields) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  for (field_symbol, field_value) in self.ion_schema_codegen_open_content {
    output_fields.push((field_symbol, field_value))
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct UniqueFields {
  ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ]
}

///|
/// Convert an Ion struct to UniqueFields with field-level diagnostics.
pub fn UniqueFields::from_ion(
  value : @ion_model.IonValue,
) -> UniqueFields raise ConversionError {
  let type_path = "UniqueFields"
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
  let mut ion_schema_codegen_field_name_index_UniqueFields = 0
  for (ion_schema_codegen_field_name_symbol_UniqueFields, _) in input_fields {
    let ion_schema_codegen_field_name_path_UniqueFields = type_path +
      "." +
      ion_schema_codegen_field_name_symbol_UniqueFields
      .text_value()
      .unwrap_or("<field>") +
      "[" +
      ion_schema_codegen_field_name_index_UniqueFields.to_string() +
      "]"
    if @ion_model.IonValue::Symbol(
        ion_schema_codegen_field_name_symbol_UniqueFields,
      ).is_null() {
      raise ConversionError::NullNotAllowed(
        path=ion_schema_codegen_field_name_path_UniqueFields,
      )
    }
    if !ion_schema_codegen_matches_type(
        @ion_model.IonValue::Symbol(
          ion_schema_codegen_field_name_symbol_UniqueFields,
        ),
        "symbol",
      ) {
      raise ConversionError::TypeMismatch(
        path=ion_schema_codegen_field_name_path_UniqueFields,
        expected="symbol",
        actual=ion_schema_codegen_actual_type(
          @ion_model.IonValue::Symbol(
            ion_schema_codegen_field_name_symbol_UniqueFields,
          ),
        ),
      )
    }
    if !is_valid_values_AllowedNames(
        @ion_model.IonValue::Symbol(
          ion_schema_codegen_field_name_symbol_UniqueFields,
        ),
      ) {
      raise ConversionError::InvalidValue(
        path=ion_schema_codegen_field_name_path_UniqueFields,
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(
          @ion_model.IonValue::Symbol(
            ion_schema_codegen_field_name_symbol_UniqueFields,
          ),
        ),
      )
    }
    ion_schema_codegen_field_name_index_UniqueFields += 1
  }
  let ion_schema_codegen_field_names_UniqueFields : Array[@ion_model.IonSymbol] = []
  for (ion_schema_codegen_field_name, _) in input_fields {
    ion_schema_codegen_field_names_UniqueFields.push(
      ion_schema_codegen_field_name,
    )
  }
  ion_schema_codegen_check_distinct_symbols(
    ion_schema_codegen_field_names_UniqueFields, type_path,
  )
  let ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ] = []
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          _ => ion_schema_codegen_open_content.push((field_symbol, field_value))
        }
      None => ion_schema_codegen_open_content.push((field_symbol, field_value))
    }
  }
  { ion_schema_codegen_open_content, }
}

///|
/// Convert UniqueFields into an Ion struct in schema field order.
pub fn UniqueFields::to_ion(self : UniqueFields) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  for (field_symbol, field_value) in self.ion_schema_codegen_open_content {
    output_fields.push((field_symbol, field_value))
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct BaseFields {
  ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ]
}

///|
/// Convert an Ion struct to BaseFields with field-level diagnostics.
pub fn BaseFields::from_ion(
  value : @ion_model.IonValue,
) -> BaseFields raise ConversionError {
  let type_path = "BaseFields"
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
  let ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ] = []
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          _ => ion_schema_codegen_open_content.push((field_symbol, field_value))
        }
      None => ion_schema_codegen_open_content.push((field_symbol, field_value))
    }
  }
  { ion_schema_codegen_open_content, }
}

///|
/// Convert BaseFields into an Ion struct in schema field order.
pub fn BaseFields::to_ion(self : BaseFields) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  for (field_symbol, field_value) in self.ion_schema_codegen_open_content {
    output_fields.push((field_symbol, field_value))
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type UniqueFieldAlias = BaseFields

///|
pub(all) struct FieldAliasHolder {
  record : UniqueFieldAlias
}

///|
/// Convert an Ion struct to FieldAliasHolder with field-level diagnostics.
pub fn FieldAliasHolder::from_ion(
  value : @ion_model.IonValue,
) -> FieldAliasHolder raise ConversionError {
  let type_path = "FieldAliasHolder"
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
          "record" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="FieldAliasHolder.record",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="FieldAliasHolder." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="FieldAliasHolder.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : UniqueFieldAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "FieldAliasHolder.record"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : UniqueFieldAlias = BaseFields::from_ion(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      let ion_schema_codegen_field_name_fields_UniqueFieldAlias = match
        field_value.without_annotations() {
        @ion_model.IonValue::Struct(fields) => fields
        _ =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="field_names",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      let mut ion_schema_codegen_field_name_index_UniqueFieldAlias = 0
      for
        (ion_schema_codegen_field_name_symbol_UniqueFieldAlias, _) in ion_schema_codegen_field_name_fields_UniqueFieldAlias {
        let ion_schema_codegen_field_name_path_UniqueFieldAlias = field_path +
          "." +
          ion_schema_codegen_field_name_symbol_UniqueFieldAlias
          .text_value()
          .unwrap_or("<field>") +
          "[" +
          ion_schema_codegen_field_name_index_UniqueFieldAlias.to_string() +
          "]"
        if @ion_model.IonValue::Symbol(
            ion_schema_codegen_field_name_symbol_UniqueFieldAlias,
          ).is_null() {
          raise ConversionError::NullNotAllowed(
            path=ion_schema_codegen_field_name_path_UniqueFieldAlias,
          )
        }
        if !ion_schema_codegen_matches_type(
            @ion_model.IonValue::Symbol(
              ion_schema_codegen_field_name_symbol_UniqueFieldAlias,
            ),
            "symbol",
          ) {
          raise ConversionError::TypeMismatch(
            path=ion_schema_codegen_field_name_path_UniqueFieldAlias,
            expected="symbol",
            actual=ion_schema_codegen_actual_type(
              @ion_model.IonValue::Symbol(
                ion_schema_codegen_field_name_symbol_UniqueFieldAlias,
              ),
            ),
          )
        }
        if !is_valid_values_AllowedNames(
            @ion_model.IonValue::Symbol(
              ion_schema_codegen_field_name_symbol_UniqueFieldAlias,
            ),
          ) {
          raise ConversionError::InvalidValue(
            path=ion_schema_codegen_field_name_path_UniqueFieldAlias,
            constraint="valid_values",
            actual=ion_schema_codegen_actual_type(
              @ion_model.IonValue::Symbol(
                ion_schema_codegen_field_name_symbol_UniqueFieldAlias,
              ),
            ),
          )
        }
        ion_schema_codegen_field_name_index_UniqueFieldAlias += 1
      }
      let ion_schema_codegen_field_names_UniqueFieldAlias : Array[
        @ion_model.IonSymbol,
      ] = []
      for
        (ion_schema_codegen_field_name, _) in ion_schema_codegen_field_name_fields_UniqueFieldAlias {
        ion_schema_codegen_field_names_UniqueFieldAlias.push(
          ion_schema_codegen_field_name,
        )
      }
      ion_schema_codegen_check_distinct_symbols(
        ion_schema_codegen_field_names_UniqueFieldAlias, field_path,
      )
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="FieldAliasHolder.record",
      )
  }
  { record: ion_schema_codegen_value_0, }
}

///|
/// Convert FieldAliasHolder into an Ion struct in schema field order.
pub fn FieldAliasHolder::to_ion(self : FieldAliasHolder) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("record"), BaseFields::to_ion(self.record)),
  )
  @ion_model.IonValue::Struct(output_fields)
}
