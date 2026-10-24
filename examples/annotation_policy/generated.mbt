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
fn ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline7_0(
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
    if !is_valid_values_IonSchemaCodegenInternalInline10(value) {
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
fn ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline7_1(
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
    if !ion_schema_codegen_matches_type(value, "any") {
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
fn ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline7(
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
          ordered_count_1 <= 3 &&
          ordered_prefix_matches_1 {
      if ordered_count_1 > 0 &&
        !ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline7_1(
          values[ordered_start_1 + ordered_count_1 - 1],
        ) {
        ordered_prefix_matches_1 = false
      }
      if ordered_count_1 >= 1 &&
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
        !ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline7_0(
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
        ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline7_0(
          values[probe_index],
        ) {
        recognized = true
      }
      if !recognized &&
        ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline7_1(
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
fn ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline27_0(
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
    if !is_valid_values_IonSchemaCodegenInternalInline28(value) {
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
fn ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline27(
  values : Array[@ion_model.IonValue],
  path : String,
) -> Unit raise ConversionError {
  let value_count = values.length()
  let possible : Array[Array[Bool]] = []
  let mut row_index = 0
  while row_index <= 1 {
    let row : Array[Bool] = []
    let mut column_index = 0
    while column_index <= value_count {
      row.push(false)
      column_index += 1
    }
    possible.push(row)
    row_index += 1
  }
  possible[1][value_count] = true
  let mut ordered_start_0 = 0
  while ordered_start_0 <= value_count {
    let mut ordered_count_0 = 0
    let mut ordered_found_0 = false
    let mut ordered_prefix_matches_0 = true
    while ordered_count_0 <= value_count - ordered_start_0 &&
          ordered_count_0 <= 2 &&
          ordered_prefix_matches_0 {
      if ordered_count_0 > 0 &&
        !ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline27_0(
          values[ordered_start_0 + ordered_count_0 - 1],
        ) {
        ordered_prefix_matches_0 = false
      }
      if ordered_count_0 >= 2 &&
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
        ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline27_0(
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
pub type Imported1StageToken = @ion_model.IonSymbol

///|
/// Test whether an Ion value satisfies valid_values for Imported1StageToken.
pub fn is_valid_values_Imported1StageToken(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("approved\ndraft") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for Imported1StageToken.
pub fn validate_Imported1StageToken(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "symbol") {
    raise ConversionError::TypeMismatch(
      path="Imported1_StageToken",
      expected="symbol",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_Imported1StageToken(value) {
    raise ConversionError::InvalidValue(
      path="Imported1_StageToken",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_Imported1StageToken(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "symbol") {
      raise ConversionError::TypeMismatch(
        path="Imported1_StageToken",
        expected="symbol",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_Imported1StageToken(value) {
      raise ConversionError::InvalidValue(
        path="Imported1_StageToken",
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
pub type Imported1VersionToken = @ion_model.IonSymbol

///|
/// Validate regex constraints for Imported1VersionToken.
pub fn validate_regex_Imported1VersionToken(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "symbol") {
    raise ConversionError::TypeMismatch(
      path="Imported1_VersionToken",
      expected="symbol",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_regex_matches(value, "^v[0-9]+$") {
    raise ConversionError::InvalidValue(
      path="Imported1_VersionToken",
      constraint="regex",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_Imported1VersionToken(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "symbol") {
      raise ConversionError::TypeMismatch(
        path="Imported1_VersionToken",
        expected="symbol",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_regex_matches(value, "^v[0-9]+$") {
      raise ConversionError::InvalidValue(
        path="Imported1_VersionToken",
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
pub type Imported1BasePolicy = @ion_model.IonValue

///|
fn ion_schema_codegen_matches_named_Imported1BasePolicy(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="Imported1_BasePolicy",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    match ion_schema_codegen_container_length(value) {
      Some(actual_length) =>
        if actual_length < 2 || actual_length > 4 {
          raise ConversionError::InvalidValue(
            path="Imported1_BasePolicy",
            constraint="container_length",
            actual=actual_length.to_string(),
          )
        }
      None =>
        raise ConversionError::InvalidValue(
          path="Imported1_BasePolicy",
          constraint="container_length",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="Imported1_BasePolicy",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "Imported1_BasePolicy" +
        "[" +
        ion_schema_codegen_nullable_list_element_index.to_string() +
        "]"
      if ion_schema_codegen_nullable_list_element_value.annotations().length() >
        0 {
        raise ConversionError::AnnotatedValueNotSupported(
          path=ion_schema_codegen_nullable_list_element_path,
        )
      }
      if ion_schema_codegen_nullable_list_element_value.is_null() {
        raise ConversionError::NullNotAllowed(
          path=ion_schema_codegen_nullable_list_element_path,
        )
      }
      if !ion_schema_codegen_matches_type(
          ion_schema_codegen_nullable_list_element_value, "symbol",
        ) {
        raise ConversionError::TypeMismatch(
          path=ion_schema_codegen_nullable_list_element_path,
          expected="symbol",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      ion_schema_codegen_nullable_list_element_index += 1
    }
    let ion_schema_codegen_contains_values_Imported1BasePolicy = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="Imported1_BasePolicy",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_Imported1BasePolicy, "record", "Imported1_BasePolicy",
    )
    true
  } catch {
    _ => false
  }
}

///|
pub type Imported1LocalName = @ion_model.IonSymbol

///|
/// Test whether an Ion value satisfies valid_values for Imported1LocalName.
pub fn is_valid_values_Imported1LocalName(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("record") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for Imported1LocalName.
pub fn validate_Imported1LocalName(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "symbol") {
    raise ConversionError::TypeMismatch(
      path="Imported1_LocalName",
      expected="symbol",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_Imported1LocalName(value) {
    raise ConversionError::InvalidValue(
      path="Imported1_LocalName",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type Imported1ScopedTokens = @ion_model.IonValue

///|
fn ion_schema_codegen_matches_named_Imported1ScopedTokens(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="Imported1_ScopedTokens",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="Imported1_ScopedTokens",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "Imported1_ScopedTokens" +
        "[" +
        ion_schema_codegen_nullable_list_element_index.to_string() +
        "]"
      if ion_schema_codegen_nullable_list_element_value.is_null() {
        raise ConversionError::NullNotAllowed(
          path=ion_schema_codegen_nullable_list_element_path,
        )
      }
      if !ion_schema_codegen_matches_type(
          ion_schema_codegen_nullable_list_element_value, "symbol",
        ) {
        raise ConversionError::TypeMismatch(
          path=ion_schema_codegen_nullable_list_element_path,
          expected="symbol",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      if !is_valid_values_Imported1LocalName(
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
pub type Stage = Imported1StageToken

///|
pub type Base = Imported1BasePolicy

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline9.
fn is_valid_values_IonSchemaCodegenInternalInline9(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("record") catch { _ => [] }
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
    if !ion_schema_codegen_matches_type(value, "$symbol") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_9",
        expected="$symbol",
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
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline10.
fn is_valid_values_IonSchemaCodegenInternalInline10(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("record") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline12(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_12",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline12 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_12",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline12, "approved",
      "ion_schema_codegen_internal_inline_12",
    )
    true
  } catch {
    _ => false
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline13(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_13",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline13 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_13",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline13, "draft",
      "ion_schema_codegen_internal_inline_13",
    )
    true
  } catch {
    _ => false
  }
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
    let ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline14 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_14",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline14, "deprecated",
      "ion_schema_codegen_internal_inline_14",
    )
    true
  } catch {
    _ => false
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
    if !ion_schema_codegen_matches_named_Imported1BasePolicy(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_7",
        constraint="all_of",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let mut ion_schema_codegen_one_of_match_count_IonSchemaCodegenInternalInline7_0 = 0
    if ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline12(value) {
      ion_schema_codegen_one_of_match_count_IonSchemaCodegenInternalInline7_0
      += 1
    }
    if ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline13(value) {
      ion_schema_codegen_one_of_match_count_IonSchemaCodegenInternalInline7_0
      += 1
    }
    if ion_schema_codegen_one_of_match_count_IonSchemaCodegenInternalInline7_0 !=
      1 {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_7",
        constraint="one_of",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline14(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_7",
        constraint="not",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_7",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_7" +
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
      if !(ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline9(
          ion_schema_codegen_nullable_list_element_value,
        ) ||
        ion_schema_codegen_matches_named_Imported1StageToken(
          ion_schema_codegen_nullable_list_element_value,
        ) ||
        ion_schema_codegen_matches_named_Imported1VersionToken(
          ion_schema_codegen_nullable_list_element_value,
        )) {
        raise ConversionError::InvalidValue(
          path=ion_schema_codegen_nullable_list_element_path,
          constraint="any_of",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      ion_schema_codegen_nullable_list_element_index += 1
    }
    ion_schema_codegen_check_distinct(
      ion_schema_codegen_nullable_list_elements, "ion_schema_codegen_internal_inline_7",
    )
    let ion_schema_codegen_ordered_sexp_IonSchemaCodegenInternalInline7 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_7",
          constraint="ordered_elements",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline7(
      ion_schema_codegen_ordered_sexp_IonSchemaCodegenInternalInline7, "ion_schema_codegen_internal_inline_7",
    )
    true
  } catch {
    _ => false
  }
}

///|
pub type Envelope = @ion_model.IonValue

///|
/// Validate annotations for Envelope.
pub fn validate_annotations_Envelope(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="Envelope",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_Envelope_0 : Array[@ion_model.IonValue] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_Envelope_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline7(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_Envelope_0),
    ) {
    raise ConversionError::InvalidValue(
      path="Envelope",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline17.
fn is_valid_values_IonSchemaCodegenInternalInline17(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("record\napproved") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline19.
fn is_valid_values_IonSchemaCodegenInternalInline19(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("approved\ndraft") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline18(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_18",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_18",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_18" +
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
      if !is_valid_values_IonSchemaCodegenInternalInline19(
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
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline16(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_16",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline18(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_16",
        constraint="all_of",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_16",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_16" +
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
      if !is_valid_values_IonSchemaCodegenInternalInline17(
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
pub type RepeatedElement = @ion_model.IonValue

///|
/// Validate annotations for RepeatedElement.
pub fn validate_annotations_RepeatedElement(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="RepeatedElement",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_RepeatedElement_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_RepeatedElement_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline16(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_RepeatedElement_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="RepeatedElement",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline23.
fn is_valid_values_IonSchemaCodegenInternalInline23(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("approved\ndraft") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline23(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$symbol") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_23",
        expected="$symbol",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline23(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_23",
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
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline22.
fn is_valid_values_IonSchemaCodegenInternalInline22(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("record\napproved") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline21(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_21",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_21",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_21" +
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
      if !is_valid_values_IonSchemaCodegenInternalInline22(
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
      if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline23(
          ion_schema_codegen_nullable_list_element_value,
        ) {
        raise ConversionError::InvalidValue(
          path=ion_schema_codegen_nullable_list_element_path,
          constraint="all_of",
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
pub type RepeatedValues = @ion_model.IonValue

///|
/// Validate annotations for RepeatedValues.
pub fn validate_annotations_RepeatedValues(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="RepeatedValues",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_RepeatedValues_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_RepeatedValues_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline21(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_RepeatedValues_0),
    ) {
    raise ConversionError::InvalidValue(
      path="RepeatedValues",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline25.
fn is_valid_values_IonSchemaCodegenInternalInline25(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("[record, v1]\n[record, v2]") catch {
    _ => []
  }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline25(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_25",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline25(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_25",
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
pub type ExactSequence = @ion_model.IonValue

///|
/// Validate annotations for ExactSequence.
pub fn validate_annotations_ExactSequence(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="ExactSequence",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_ExactSequence_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_ExactSequence_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline25(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_ExactSequence_0),
    ) {
    raise ConversionError::InvalidValue(
      path="ExactSequence",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline28.
fn is_valid_values_IonSchemaCodegenInternalInline28(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("record") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline27(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_27",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_ordered_sexp_IonSchemaCodegenInternalInline27 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_27",
          constraint="ordered_elements",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline27(
      ion_schema_codegen_ordered_sexp_IonSchemaCodegenInternalInline27, "ion_schema_codegen_internal_inline_27",
    )
    true
  } catch {
    _ => false
  }
}

///|
pub type OrderedMinimum = @ion_model.IonValue

///|
/// Validate annotations for OrderedMinimum.
pub fn validate_annotations_OrderedMinimum(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="OrderedMinimum",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_OrderedMinimum_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_OrderedMinimum_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline27(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_OrderedMinimum_0),
    ) {
    raise ConversionError::InvalidValue(
      path="OrderedMinimum",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline30(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_30",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline30 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_30",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline30, "record",
      "ion_schema_codegen_internal_inline_30",
    )
    true
  } catch {
    _ => false
  }
}

///|
pub type NullableInline = @ion_model.IonValue

///|
/// Validate annotations for NullableInline.
pub fn validate_annotations_NullableInline(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NullableInline",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_NullableInline_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_NullableInline_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !(ion_schema_codegen_matches_type(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_NullableInline_0),
      "$null",
    ) ||
    ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline30(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_NullableInline_0),
    )) {
    raise ConversionError::InvalidValue(
      path="NullableInline",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline32(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_32",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_32",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_32" +
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
      if !ion_schema_codegen_annotations_match(
          ion_schema_codegen_nullable_list_element_value,
          [],
          true,
          false,
        ) {
        raise ConversionError::InvalidValue(
          path=ion_schema_codegen_nullable_list_element_path,
          constraint="annotations",
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
pub type NestedAnnotations = @ion_model.IonValue

///|
/// Validate annotations for NestedAnnotations.
pub fn validate_annotations_NestedAnnotations(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NestedAnnotations",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_NestedAnnotations_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_NestedAnnotations_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline32(
      @ion_model.IonValue::List(
        ion_schema_codegen_annotations_NestedAnnotations_0,
      ),
    ) {
    raise ConversionError::InvalidValue(
      path="NestedAnnotations",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline37(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$symbol") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_37",
        expected="$symbol",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_regex_matches(value, "^internal_") {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_37",
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
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline35(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_35",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_35",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_35" +
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
      if ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline37(
          ion_schema_codegen_nullable_list_element_value,
        ) {
        raise ConversionError::InvalidValue(
          path=ion_schema_codegen_nullable_list_element_path,
          constraint="not",
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
pub type PublicTokens = @ion_model.IonValue

///|
/// Validate annotations for PublicTokens.
pub fn validate_annotations_PublicTokens(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="PublicTokens",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_PublicTokens_0 : Array[@ion_model.IonValue] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_PublicTokens_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline35(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_PublicTokens_0),
    ) {
    raise ConversionError::InvalidValue(
      path="PublicTokens",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline39(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_39",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type AnyAnnotations = @ion_model.IonValue

///|
/// Validate annotations for AnyAnnotations.
pub fn validate_annotations_AnyAnnotations(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="AnyAnnotations",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_AnyAnnotations_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_AnyAnnotations_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline39(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_AnyAnnotations_0),
    ) {
    raise ConversionError::InvalidValue(
      path="AnyAnnotations",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline42(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_42",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline42 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_42",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline42, "record",
      "ion_schema_codegen_internal_inline_42",
    )
    true
  } catch {
    _ => false
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline43(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_43",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    match ion_schema_codegen_container_length(value) {
      Some(actual_length) =>
        if actual_length < 2 || actual_length > 2 {
          raise ConversionError::InvalidValue(
            path="ion_schema_codegen_internal_inline_43",
            constraint="container_length",
            actual=actual_length.to_string(),
          )
        }
      None =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_43",
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
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline41(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_41",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline42(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_41",
        constraint="all_of",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline43(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_41",
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
pub type AllOfPolicy = @ion_model.IonValue

///|
/// Validate annotations for AllOfPolicy.
pub fn validate_annotations_AllOfPolicy(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="AllOfPolicy",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_AllOfPolicy_0 : Array[@ion_model.IonValue] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_AllOfPolicy_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline41(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_AllOfPolicy_0),
    ) {
    raise ConversionError::InvalidValue(
      path="AllOfPolicy",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline45(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_45",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_nullable_list_elements = match
      value.without_annotations() {
      @ion_model.IonValue::List(elements) => elements
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_45",
          constraint="element",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    let mut ion_schema_codegen_nullable_list_element_index = 0
    for
      ion_schema_codegen_nullable_list_element_value in ion_schema_codegen_nullable_list_elements {
      let ion_schema_codegen_nullable_list_element_path = "ion_schema_codegen_internal_inline_45" +
        "[" +
        ion_schema_codegen_nullable_list_element_index.to_string() +
        "]"
      if ion_schema_codegen_nullable_list_element_value.is_null() {
        raise ConversionError::NullNotAllowed(
          path=ion_schema_codegen_nullable_list_element_path,
        )
      }
      if !ion_schema_codegen_matches_type(
          ion_schema_codegen_nullable_list_element_value, "symbol",
        ) {
        raise ConversionError::TypeMismatch(
          path=ion_schema_codegen_nullable_list_element_path,
          expected="symbol",
          actual=ion_schema_codegen_actual_type(
            ion_schema_codegen_nullable_list_element_value,
          ),
        )
      }
      if !is_valid_values_Imported1StageToken(
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
pub type ImportedTokens = @ion_model.IonValue

///|
/// Validate annotations for ImportedTokens.
pub fn validate_annotations_ImportedTokens(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="ImportedTokens",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_ImportedTokens_0 : Array[
    @ion_model.IonValue,
  ] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_ImportedTokens_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline45(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_ImportedTokens_0),
    ) {
    raise ConversionError::InvalidValue(
      path="ImportedTokens",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
pub type LocalName = @bigint.BigInt

///|
pub type ImportedList = @ion_model.IonValue

///|
/// Validate annotations for ImportedList.
pub fn validate_annotations_ImportedList(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="ImportedList",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_ImportedList_0 : Array[@ion_model.IonValue] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_ImportedList_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_Imported1ScopedTokens(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_ImportedList_0),
    ) {
    raise ConversionError::InvalidValue(
      path="ImportedList",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline49(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_49",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    let ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline49 = match
      value.without_annotations() {
      @ion_model.IonValue::List(values) => values
      _ =>
        raise ConversionError::InvalidValue(
          path="ion_schema_codegen_internal_inline_49",
          constraint="contains",
          actual=ion_schema_codegen_actual_type(value),
        )
    }
    ion_schema_codegen_check_contains(
      ion_schema_codegen_contains_values_IonSchemaCodegenInternalInline49, "{id: \"missing.isl\", type: Stage}",
      "ion_schema_codegen_internal_inline_49",
    )
    true
  } catch {
    _ => false
  }
}

///|
pub type LiteralSafe = @ion_model.IonValue

///|
/// Validate annotations for LiteralSafe.
pub fn validate_annotations_LiteralSafe(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="LiteralSafe",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_LiteralSafe_0 : Array[@ion_model.IonValue] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_LiteralSafe_0.push(
      @ion_model.IonValue::Symbol(annotation),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline49(
      @ion_model.IonValue::List(ion_schema_codegen_annotations_LiteralSafe_0),
    ) {
    raise ConversionError::InvalidValue(
      path="LiteralSafe",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
pub type StageFields = @ion_model.IonValue

///|
pub(all) struct WorkflowMessage {
  payload : StageFields
}

///|
/// Convert an Ion struct to WorkflowMessage with field-level diagnostics.
pub fn WorkflowMessage::from_ion(
  value : @ion_model.IonValue,
) -> WorkflowMessage raise ConversionError {
  let type_path = "WorkflowMessage"
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
                  path="WorkflowMessage.payload",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="WorkflowMessage." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="WorkflowMessage.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : StageFields = match input_field_0 {
    Some(field_value) => {
      let field_path = "WorkflowMessage.payload"
      let field_item : StageFields = if ion_schema_codegen_matches_type(
          field_value, "$struct",
        ) {
        field_value
      } else {
        raise ConversionError::TypeMismatch(
          path=field_path,
          expected="$struct",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      let ion_schema_codegen_field_name_fields_StageFields = match
        field_value.without_annotations() {
        @ion_model.IonValue::Struct(fields) => fields
        _ =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="field_names",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      let mut ion_schema_codegen_field_name_index_StageFields = 0
      for
        (ion_schema_codegen_field_name_symbol_StageFields, _) in ion_schema_codegen_field_name_fields_StageFields {
        let ion_schema_codegen_field_name_path_StageFields = field_path +
          "." +
          ion_schema_codegen_field_name_symbol_StageFields
          .text_value()
          .unwrap_or("<field>") +
          "[" +
          ion_schema_codegen_field_name_index_StageFields.to_string() +
          "]"
        if @ion_model.IonValue::Symbol(
            ion_schema_codegen_field_name_symbol_StageFields,
          ).is_null() {
          raise ConversionError::NullNotAllowed(
            path=ion_schema_codegen_field_name_path_StageFields,
          )
        }
        if !ion_schema_codegen_matches_type(
            @ion_model.IonValue::Symbol(
              ion_schema_codegen_field_name_symbol_StageFields,
            ),
            "symbol",
          ) {
          raise ConversionError::TypeMismatch(
            path=ion_schema_codegen_field_name_path_StageFields,
            expected="symbol",
            actual=ion_schema_codegen_actual_type(
              @ion_model.IonValue::Symbol(
                ion_schema_codegen_field_name_symbol_StageFields,
              ),
            ),
          )
        }
        if !is_valid_values_Imported1StageToken(
            @ion_model.IonValue::Symbol(
              ion_schema_codegen_field_name_symbol_StageFields,
            ),
          ) {
          raise ConversionError::InvalidValue(
            path=ion_schema_codegen_field_name_path_StageFields,
            constraint="valid_values",
            actual=ion_schema_codegen_actual_type(
              @ion_model.IonValue::Symbol(
                ion_schema_codegen_field_name_symbol_StageFields,
              ),
            ),
          )
        }
        ion_schema_codegen_field_name_index_StageFields += 1
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="WorkflowMessage.payload",
      )
  }
  { payload: ion_schema_codegen_value_0, }
}

///|
/// Convert WorkflowMessage into an Ion struct in schema field order.
pub fn WorkflowMessage::to_ion(self : WorkflowMessage) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("payload"), self.payload))
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct AuditRecord {
  payload : Envelope
}

///|
/// Convert an Ion struct to AuditRecord with field-level diagnostics.
pub fn AuditRecord::from_ion(
  value : @ion_model.IonValue,
) -> AuditRecord raise ConversionError {
  let type_path = "AuditRecord"
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
                  path="AuditRecord.payload",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="AuditRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="AuditRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : Envelope = match input_field_0 {
    Some(field_value) => {
      let field_path = "AuditRecord.payload"
      let field_item : Envelope = field_value
      let ion_schema_codegen_annotations_Envelope_0 : Array[@ion_model.IonValue] = []
      for annotation in field_value.annotations() {
        ion_schema_codegen_annotations_Envelope_0.push(
          @ion_model.IonValue::Symbol(annotation),
        )
      }
      if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline7(
          @ion_model.IonValue::List(ion_schema_codegen_annotations_Envelope_0),
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
      raise ConversionError::MissingRequiredField(path="AuditRecord.payload")
  }
  { payload: ion_schema_codegen_value_0, }
}

///|
/// Convert AuditRecord into an Ion struct in schema field order.
pub fn AuditRecord::to_ion(self : AuditRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("payload"), self.payload))
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type AnnotationFreeStream = Array[@ion_model.IonValue]

///|
/// Convert an Ion document stream to AnnotationFreeStream.
pub fn from_ion_document_AnnotationFreeStream(
  values : Array[@ion_model.IonValue],
) -> AnnotationFreeStream raise ConversionError {
  let type_path = "AnnotationFreeStream"
  raise ConversionError::InvalidValue(
    path=type_path,
    constraint="annotations",
    actual="document",
  )
  values
}

///|
/// Convert AnnotationFreeStream to an Ion document stream.
pub fn to_ion_document_AnnotationFreeStream(
  values : AnnotationFreeStream,
) -> Array[@ion_model.IonValue] {
  values
}
