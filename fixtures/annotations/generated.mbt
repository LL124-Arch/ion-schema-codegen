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
fn ion_schema_codegen_container_length(value : @ion_model.IonValue) -> Int? {
  match value.without_annotations() {
    @ion_model.IonValue::List(elements) => Some(elements.length())
    @ion_model.IonValue::Sexp(elements) => Some(elements.length())
    @ion_model.IonValue::Struct(fields) => Some(fields.length())
    _ => None
  }
}

///|
fn ion_schema_codegen_codepoint_length(value : @ion_model.IonValue) -> Int? {
  match value.without_annotations() {
    @ion_model.IonValue::String(text) => Some(text.char_length())
    @ion_model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(text) => Some(text.char_length())
        None => None
      }
    _ => None
  }
}

///|
fn ion_schema_codegen_utf8_byte_length(value : @ion_model.IonValue) -> Int? {
  let text = match value.without_annotations() {
    @ion_model.IonValue::String(text) => Some(text)
    @ion_model.IonValue::Symbol(symbol) => symbol.text_value()
    _ => None
  }
  match text {
    Some(text) => {
      let mut byte_count = 0
      for character in text {
        let codepoint = character.to_int()
        byte_count += if codepoint <= 0x7F {
          1
        } else if codepoint <= 0x7FF {
          2
        } else if codepoint <= 0xFFFF {
          3
        } else {
          4
        }
      }
      Some(byte_count)
    }
    None => None
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
fn ion_schema_codegen_annotations_match(
  value : @ion_model.IonValue,
  allowed : Array[String],
  closed : Bool,
  required : Bool,
) -> Bool {
  let annotations = value.annotations()
  if required {
    for expected in allowed {
      let mut found = false
      for actual in annotations {
        if actual.text_value() == Some(expected) {
          found = true
          break
        }
      }
      if !found {
        return false
      }
    }
  }
  if closed {
    for actual in annotations {
      let text = match actual.text_value() {
        Some(text) => text
        None => return false
      }
      let mut allowed_annotation = false
      for expected in allowed {
        if expected == text {
          allowed_annotation = true
          break
        }
      }
      if !allowed_annotation {
        return false
      }
    }
  }
  true
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
      left.reinterpret_as_uint() == right.reinterpret_as_uint() ||
      (left.is_nan() && right.is_nan())
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
fn ion_schema_codegen_contains_missing(
  values : Array[@ion_model.IonValue],
  required : Array[@ion_model.IonValue],
) -> @ion_model.IonValue? {
  for expected in required {
    let mut found = false
    for value in values {
      if ion_schema_codegen_values_equal(expected, value) {
        found = true
        break
      }
    }
    if !found {
      return Some(expected)
    }
  }
  None
}

///|
fn ion_schema_codegen_check_contains(
  values : Array[@ion_model.IonValue],
  encoded_required : String,
  path : String,
) -> Unit raise ConversionError {
  let required = @ion.parse_text(encoded_required) catch { _ => [] }
  match ion_schema_codegen_contains_missing(values, required) {
    Some(missing) =>
      raise ConversionError::InvalidValue(
        path~,
        constraint="contains",
        actual=@ion.encode_value_text(missing) catch {
          _ => "<unencodable Ion value>"
        },
      )
    None => ()
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
      left.reinterpret_as_uint() == right.reinterpret_as_uint() ||
      (left.is_nan() && right.is_nan())
    (@ion_model.IonValue::Symbol(left), @ion_model.IonValue::Symbol(right)) =>
      match (left.text_value(), right.text_value()) {
        (Some(a), Some(b)) => a == b
        (None, None) => left.sid_value() == right.sid_value()
        _ => false
      }
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
fn ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline22_0(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if value.is_null() {
      raise ConversionError::NullNotAllowed(path="ordered_elements")
    }
    if !ion_schema_codegen_matches_type(value, "symbol") {
      raise ConversionError::TypeMismatch(
        path="ordered_elements",
        expected="symbol",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_RecordToken(value) {
      raise ConversionError::InvalidValue(
        path="ordered_elements",
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
fn ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline22_1(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$symbol") {
      raise ConversionError::TypeMismatch(
        path="ordered_elements",
        expected="$symbol",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_matches_named_VersionToken(value) {
      raise ConversionError::InvalidValue(
        path="ordered_elements",
        constraint="all_of",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
fn ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline22(
  values : Array[@ion_model.IonValue],
  path : String,
) -> Unit raise ConversionError {
  let value_count = values.length()
  let possible : Array[Array[Bool]] = []
  let mut row_index = 0
  while row_index <= 2 {
    let row : Array[Bool] = []
    let mut column_index = 0
    while column_index <= value_count {
      row.push(false)
      column_index += 1
    }
    possible.push(row)
    row_index += 1
  }
  possible[2][value_count] = true
  let mut ordered_start_1 = 0
  while ordered_start_1 <= value_count {
    let mut ordered_count_1 = 0
    let mut ordered_found_1 = false
    let mut ordered_prefix_matches_1 = true
    while ordered_count_1 <= value_count - ordered_start_1 &&
          ordered_count_1 <= 2 &&
          ordered_prefix_matches_1 {
      if ordered_count_1 > 0 &&
        !ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline22_1(
          values[ordered_start_1 + ordered_count_1 - 1],
        ) {
        ordered_prefix_matches_1 = false
      }
      if ordered_count_1 >= 0 &&
        ordered_prefix_matches_1 &&
        possible[2][ordered_start_1 + ordered_count_1] {
        ordered_found_1 = true
      }
      ordered_count_1 += 1
    }
    possible[1][ordered_start_1] = ordered_found_1
    ordered_start_1 += 1
  }
  let mut ordered_start_0 = 0
  while ordered_start_0 <= value_count {
    let mut ordered_count_0 = 0
    let mut ordered_found_0 = false
    let mut ordered_prefix_matches_0 = true
    while ordered_count_0 <= value_count - ordered_start_0 &&
          ordered_count_0 <= 1 &&
          ordered_prefix_matches_0 {
      if ordered_count_0 > 0 &&
        !ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline22_0(
          values[ordered_start_0 + ordered_count_0 - 1],
        ) {
        ordered_prefix_matches_0 = false
      }
      if ordered_count_0 >= 1 &&
        ordered_prefix_matches_0 &&
        possible[1][ordered_start_0 + ordered_count_0] {
        ordered_found_0 = true
      }
      ordered_count_0 += 1
    }
    possible[0][ordered_start_0] = ordered_found_0
    ordered_start_0 += 1
  }
  if !possible[0][0] {
    let mut failure_index = value_count
    let mut probe_index = 0
    while probe_index < value_count {
      let mut recognized = false
      if !recognized &&
        ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline22_0(
          values[probe_index],
        ) {
        recognized = true
      }
      if !recognized &&
        ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline22_1(
          values[probe_index],
        ) {
        recognized = true
      }
      if !recognized && failure_index == value_count {
        failure_index = probe_index
      }
      probe_index += 1
    }
    let actual = if failure_index < value_count {
      ion_schema_codegen_actual_type(values[failure_index])
    } else {
      "sequence length " + value_count.to_string()
    }
    raise ConversionError::InvalidValue(
      path=path + "[" + failure_index.to_string() + "]",
      constraint="ordered_elements",
      actual~,
    )
  }
}

///|
pub type Tagged = @ion_model.IonValue

///|
/// Validate annotations for Tagged.
pub fn validate_annotations_Tagged(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="Tagged",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_annotations_match(value, ["record", "v1"], true, true) {
    raise ConversionError::InvalidValue(
      path="Tagged",
      constraint="annotations",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type TaggedAlias = Tagged

///|
pub type OpenTagged = @ion_model.IonValue

///|
/// Validate annotations for OpenTagged.
pub fn validate_annotations_OpenTagged(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="OpenTagged",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_annotations_match(value, ["message"], false, true) {
    raise ConversionError::InvalidValue(
      path="OpenTagged",
      constraint="annotations",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type TwoAnnotationSymbols = @ion_model.IonValue

///|
fn ion_schema_codegen_matches_named_TwoAnnotationSymbols(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="TwoAnnotationSymbols",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    match ion_schema_codegen_container_length(value) {
      Some(actual_length) =>
        if actual_length < 2 || actual_length > 2 {
          raise ConversionError::InvalidValue(
            path="TwoAnnotationSymbols",
            constraint="container_length",
            actual=actual_length.to_string(),
          )
        }
      None =>
        raise ConversionError::InvalidValue(
          path="TwoAnnotationSymbols",
          constraint="container_length",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type ExactlyTwoTagged = @ion_model.IonValue

///|
/// Validate annotations for ExactlyTwoTagged.
pub fn validate_annotations_ExactlyTwoTagged(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="ExactlyTwoTagged",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_ExactlyTwoTagged_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_ExactlyTwoTagged_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_TwoAnnotationSymbols(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_ExactlyTwoTagged_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="ExactlyTwoTagged",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline5(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_5",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    match ion_schema_codegen_container_length(value) {
      Some(actual_length) =>
        if actual_length < 1 || actual_length > 2 {
          raise ConversionError::InvalidValue(
            path="ion_schema_codegen_internal_inline_5",
            constraint="container_length",
            actual=actual_length.to_string(),
          )
        }
      None =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_5",
          constraint="container_length",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type OneOrTwoAnnotations = @ion_model.IonValue

///|
/// Validate annotations for OneOrTwoAnnotations.
pub fn validate_annotations_OneOrTwoAnnotations(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="OneOrTwoAnnotations",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_OneOrTwoAnnotations_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_OneOrTwoAnnotations_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline5(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_OneOrTwoAnnotations_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="OneOrTwoAnnotations",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline7(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_7",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline7 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_7",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline7, "record\nrecord\nv1",
      "ion_schema_codegen_internal_inline_7",
    )
    true
  } catch {
    _ => false
  }
}

///|
pub type ContainsRecordAndVersion = @ion_model.IonValue

///|
/// Validate annotations for ContainsRecordAndVersion.
pub fn validate_annotations_ContainsRecordAndVersion(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="ContainsRecordAndVersion",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_ContainsRecordAndVersion_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_ContainsRecordAndVersion_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline7(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_ContainsRecordAndVersion_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="ContainsRecordAndVersion",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
pub(all) struct ContainsRecordField {
  payload : ContainsRecordAndVersion
}

///|
/// Convert an Ion struct to ContainsRecordField with field-level diagnostics.
pub fn ContainsRecordField::from_ion(
  value : @ion_model.IonValue,
) -> ContainsRecordField raise ConversionError {
  let type_path = "ContainsRecordField"
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
          "payload" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ContainsRecordField.payload",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="ContainsRecordField." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="ContainsRecordField.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : ContainsRecordAndVersion = match
    input_field_0 {
    Some(field_value) => {
      let field_path = "ContainsRecordField.payload"
      let field_item : ContainsRecordAndVersion = field_value
      let ion_schema_codegen_annotations_ContainsRecordAndVersion_0 : Array[
        @ion_model.IonValue,
      ] = []
      for annotation in field_value.annotations() {
        ion_schema_codegen_annotations_ContainsRecordAndVersion_0.push(
          @ion_model.IonValue::Symbol(annotation),
        )
      }
      if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline7(
          @ion_model.IonValue::List(
            ion_schema_codegen_annotations_ContainsRecordAndVersion_0,
          ),
        ) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="annotations",
          actual="symbol list",
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="ContainsRecordField.payload",
      )
  }
  { payload: ion_schema_codegen_value_0, }
}

///|
/// Convert ContainsRecordField into an Ion struct in schema field order.
pub fn ContainsRecordField::to_ion(
  self : ContainsRecordField,
) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("payload"), self.payload))
  @ion_model.IonValue::Struct(output_fields)
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline11.
fn is_valid_values_IonSchemaCodegenInternalInline11(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("record\nv1\nrecord") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline10(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_10",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_10",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_10" +
        "[" +
        ion_schema_codegen_nullable_list_element_index.to_string() +
        "]"
      if !ion_schema_codegen_matches_type(
          ion_schema_codegen_nullable_list_element_value, "$symbol",
        ) {
        raise ConversionError::TypeMismatch(
          path=ion_schema_codegen_nullable_list_element_path,
          expected="$symbol",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      if !is_valid_values_IonSchemaCodegenInternalInline11(
          ion_schema_codegen_nullable_list_element_value,
        ) {
        raise ConversionError::InvalidValue(
          path=ion_schema_codegen_nullable_list_element_path,
          constraint="valid_values",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      ion_schema_codegen_nullable_list_element_index += 1
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type AllowedAnnotationTokens = @ion_model.IonValue

///|
/// Validate annotations for AllowedAnnotationTokens.
pub fn validate_annotations_AllowedAnnotationTokens(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="AllowedAnnotationTokens",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_AllowedAnnotationTokens_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_AllowedAnnotationTokens_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline10(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_AllowedAnnotationTokens_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="AllowedAnnotationTokens",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
pub(all) struct AllowedAnnotationField {
  payload : AllowedAnnotationTokens
}

///|
/// Convert an Ion struct to AllowedAnnotationField with field-level diagnostics.
pub fn AllowedAnnotationField::from_ion(
  value : @ion_model.IonValue,
) -> AllowedAnnotationField raise ConversionError {
  let type_path = "AllowedAnnotationField"
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
          "payload" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="AllowedAnnotationField.payload",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="AllowedAnnotationField." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="AllowedAnnotationField.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : AllowedAnnotationTokens = match
    input_field_0 {
    Some(field_value) => {
      let field_path = "AllowedAnnotationField.payload"
      let field_item : AllowedAnnotationTokens = field_value
      let ion_schema_codegen_annotations_AllowedAnnotationTokens_0 : Array[
        @ion_model.IonValue,
      ] = []
      for annotation in field_value.annotations() {
        ion_schema_codegen_annotations_AllowedAnnotationTokens_0.push(
          @ion_model.IonValue::Symbol(annotation),
        )
      }
      if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline10(
          @ion_model.IonValue::List(
            ion_schema_codegen_annotations_AllowedAnnotationTokens_0,
          ),
        ) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="annotations",
          actual="symbol list",
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="AllowedAnnotationField.payload",
      )
  }
  { payload: ion_schema_codegen_value_0, }
}

///|
/// Convert AllowedAnnotationField into an Ion struct in schema field order.
pub fn AllowedAnnotationField::to_ion(
  self : AllowedAnnotationField,
) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("payload"), self.payload))
  @ion_model.IonValue::Struct(output_fields)
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline14(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_14",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_14",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_14" +
        "[" +
        ion_schema_codegen_nullable_list_element_index.to_string() +
        "]"
      if !ion_schema_codegen_matches_type(
          ion_schema_codegen_nullable_list_element_value, "$symbol",
        ) {
        raise ConversionError::TypeMismatch(
          path=ion_schema_codegen_nullable_list_element_path,
          expected="$symbol",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      if !ion_schema_codegen_regex_matches(
          ion_schema_codegen_nullable_list_element_value, "^v[0-9]+$",
        ) {
        raise ConversionError::InvalidValue(
          path=ion_schema_codegen_nullable_list_element_path,
          constraint="regex",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      ion_schema_codegen_nullable_list_element_index += 1
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type VersionAnnotationTokens = @ion_model.IonValue

///|
/// Validate annotations for VersionAnnotationTokens.
pub fn validate_annotations_VersionAnnotationTokens(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="VersionAnnotationTokens",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_VersionAnnotationTokens_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_VersionAnnotationTokens_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline14(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_VersionAnnotationTokens_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="VersionAnnotationTokens",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline17(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_17",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_17",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_17" +
        "[" +
        ion_schema_codegen_nullable_list_element_index.to_string() +
        "]"
      if !ion_schema_codegen_matches_type(
          ion_schema_codegen_nullable_list_element_value, "$symbol",
        ) {
        raise ConversionError::TypeMismatch(
          path=ion_schema_codegen_nullable_list_element_path,
          expected="$symbol",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      match
        ion_schema_codegen_codepoint_length(
          ion_schema_codegen_nullable_list_element_value,
        ) {
        Some(actual_length) =>
          if actual_length < 2 || actual_length > 2 {
            raise ConversionError::InvalidValue(
              path=ion_schema_codegen_nullable_list_element_path,
              constraint="codepoint_length",
              actual=actual_length.to_string(),
            )
          }
        None =>
          raise ConversionError::InvalidValue(
            path=ion_schema_codegen_nullable_list_element_path,
            constraint="codepoint_length",
            actual=ion_schema_codegen_actual_type(
              ion_schema_codegen_nullable_list_element_value,
            ),
          )
      }
      match
        ion_schema_codegen_utf8_byte_length(
          ion_schema_codegen_nullable_list_element_value,
        ) {
        Some(actual_length) =>
          if actual_length < 3 || actual_length > 3 {
            raise ConversionError::InvalidValue(
              path=ion_schema_codegen_nullable_list_element_path,
              constraint="utf8_byte_length",
              actual=actual_length.to_string(),
            )
          }
        None =>
          raise ConversionError::InvalidValue(
            path=ion_schema_codegen_nullable_list_element_path,
            constraint="utf8_byte_length",
            actual=ion_schema_codegen_actual_type(
              ion_schema_codegen_nullable_list_element_value,
            ),
          )
      }
      ion_schema_codegen_nullable_list_element_index += 1
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type UnicodeAnnotationLength = @ion_model.IonValue

///|
/// Validate annotations for UnicodeAnnotationLength.
pub fn validate_annotations_UnicodeAnnotationLength(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="UnicodeAnnotationLength",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_UnicodeAnnotationLength_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_UnicodeAnnotationLength_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline17(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_UnicodeAnnotationLength_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="UnicodeAnnotationLength",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
pub type RecordToken = @ion_model.IonSymbol

///|
/// Test whether an Ion value satisfies valid_values for RecordToken.
pub fn is_valid_values_RecordToken(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("record") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for RecordToken.
pub fn validate_RecordToken(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "symbol") {
    raise ConversionError::TypeMismatch(
      path="RecordToken",
      expected="symbol",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_RecordToken(value) {
    raise ConversionError::InvalidValue(
      path="RecordToken",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type VersionToken = @ion_model.IonSymbol

///|
/// Test whether an Ion value satisfies valid_values for VersionToken.
pub fn is_valid_values_VersionToken(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("v1") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for VersionToken.
pub fn validate_VersionToken(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "symbol") {
    raise ConversionError::TypeMismatch(
      path="VersionToken",
      expected="symbol",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_VersionToken(value) {
    raise ConversionError::InvalidValue(
      path="VersionToken",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_VersionToken(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "symbol") {
      raise ConversionError::TypeMismatch(
        path="VersionToken",
        expected="symbol",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_VersionToken(value) {
      raise ConversionError::InvalidValue(
        path="VersionToken",
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
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline22(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_22",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_ordered_sexp_IonSchemaCodegenInternalInline22 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_22",
          constraint="ordered_elements",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline22(
      ion_schema_codegen_ordered_sexp_IonSchemaCodegenInternalInline22, "ion_schema_codegen_internal_inline_22",
    )
    true
  } catch {
    _ => false
  }
}

///|
pub type OrderedAnnotationTokens = @ion_model.IonValue

///|
/// Validate annotations for OrderedAnnotationTokens.
pub fn validate_annotations_OrderedAnnotationTokens(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="OrderedAnnotationTokens",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_OrderedAnnotationTokens_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_OrderedAnnotationTokens_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline22(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_OrderedAnnotationTokens_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="OrderedAnnotationTokens",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
pub type TagList = Array[TaggedAlias]

///|
/// Convert an Ion list to TagList with element-level diagnostics.
pub fn from_ion_TagList(
  value : @ion_model.IonValue,
) -> TagList raise ConversionError {
  let type_path = "TagList"
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
  let converted : TagList = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    let item : TaggedAlias = element
    if !ion_schema_codegen_annotations_match(
        element,
        ["record", "v1"],
        true,
        true,
      ) {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="annotations",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert TagList into an Ion list.
pub fn to_ion_TagList(items : TagList) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct TagRecord {
  payload : TaggedAlias
}

///|
/// Convert an Ion struct to TagRecord with field-level diagnostics.
pub fn TagRecord::from_ion(
  value : @ion_model.IonValue,
) -> TagRecord raise ConversionError {
  let type_path = "TagRecord"
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
          "payload" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="TagRecord.payload")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(path="TagRecord." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="TagRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : TaggedAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "TagRecord.payload"
      let field_item : TaggedAlias = field_value
      if !ion_schema_codegen_annotations_match(
          field_value,
          ["record", "v1"],
          true,
          true,
        ) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="annotations",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="TagRecord.payload")
  }
  { payload: ion_schema_codegen_value_0, }
}

///|
/// Convert TagRecord into an Ion struct in schema field order.
pub fn TagRecord::to_ion(self : TagRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("payload"), self.payload))
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type Stream = Array[@ion_model.IonValue]

///|
/// Convert an Ion document stream to Stream.
pub fn from_ion_document_Stream(
  values : Array[@ion_model.IonValue],
) -> Stream raise ConversionError {
  let type_path = "Stream"
  raise ConversionError::InvalidValue(
    path=type_path,
    constraint="annotations",
    actual="document",
  )
  values
}

///|
/// Convert Stream to an Ion document stream.
pub fn to_ion_document_Stream(values : Stream) -> Array[@ion_model.IonValue] {
  values
}
