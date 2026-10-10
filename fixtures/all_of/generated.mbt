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
fn ion_schema_codegen_struct_field_values(
  fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)],
) -> Array[@ion_model.IonValue] {
  let values : Array[@ion_model.IonValue] = []
  for (_, value) in fields {
    values.push(value)
  }
  values
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
fn ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline29_0(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if value.is_null() {
      raise ConversionError::NullNotAllowed(path="ordered_elements")
    }
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="ordered_elements",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline30(value) {
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
fn ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline29_1(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if value.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path="ordered_elements")
    }
    if value.is_null() {
      raise ConversionError::NullNotAllowed(path="ordered_elements")
    }
    if !ion_schema_codegen_matches_type(value, "string") {
      raise ConversionError::TypeMismatch(
        path="ordered_elements",
        expected="string",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_regex_matches(value, "^done$") {
      raise ConversionError::InvalidValue(
        path="ordered_elements",
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
fn ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline29(
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
          ordered_count_1 <= 1 &&
          ordered_prefix_matches_1 {
      if ordered_count_1 > 0 &&
        !ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline29_1(
          values[ordered_start_1 + ordered_count_1 - 1],
        ) {
        ordered_prefix_matches_1 = false
      }
      if ordered_prefix_matches_1 &&
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
    let mut ordered_count_0 = 1
    let mut ordered_found_0 = false
    let mut ordered_prefix_matches_0 = true
    while ordered_count_0 <= value_count - ordered_start_0 &&
          ordered_count_0 <= 1 &&
          ordered_prefix_matches_0 {
      if ordered_count_0 > 0 &&
        !ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline29_0(
          values[ordered_start_0 + ordered_count_0 - 1],
        ) {
        ordered_prefix_matches_0 = false
      }
      if ordered_prefix_matches_0 &&
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
        ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline29_0(
          values[probe_index],
        ) {
        recognized = true
      }
      if !recognized &&
        ion_schema_codegen_ordered_matches_IonSchemaCodegenInternalInline29_1(
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
pub type Positive = @bigint.BigInt

///|
/// Test whether an Ion value satisfies valid_values for Positive.
pub fn is_valid_values_Positive(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("range::[1, max]") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for Positive.
pub fn validate_Positive(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "int") {
    raise ConversionError::TypeMismatch(
      path="Positive",
      expected="int",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_Positive(value) {
    raise ConversionError::InvalidValue(
      path="Positive",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_Positive(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="Positive",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_Positive(value) {
      raise ConversionError::InvalidValue(
        path="Positive",
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
pub type BelowTen = @bigint.BigInt

///|
/// Test whether an Ion value satisfies valid_values for BelowTen.
pub fn is_valid_values_BelowTen(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("range::[min, 9]") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for BelowTen.
pub fn validate_BelowTen(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "int") {
    raise ConversionError::TypeMismatch(
      path="BelowTen",
      expected="int",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_BelowTen(value) {
    raise ConversionError::InvalidValue(
      path="BelowTen",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_BelowTen(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="BelowTen",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_BelowTen(value) {
      raise ConversionError::InvalidValue(
        path="BelowTen",
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
pub type PositiveBelowTen = @ion_model.IonValue

///|
/// Validate the type algebra constraints for PositiveBelowTen.
pub fn validate_type_PositiveBelowTen(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="PositiveBelowTen",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_Positive(value) {
    raise ConversionError::InvalidValue(
      path="PositiveBelowTen",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_BelowTen(value) {
    raise ConversionError::InvalidValue(
      path="PositiveBelowTen",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type PositiveBelowTenAlias = PositiveBelowTen

///|
pub type PositiveBelowTenList = Array[PositiveBelowTenAlias]

///|
/// Convert an Ion list to PositiveBelowTenList with element-level diagnostics.
pub fn from_ion_PositiveBelowTenList(
  value : @ion_model.IonValue,
) -> PositiveBelowTenList raise ConversionError {
  let type_path = "PositiveBelowTenList"
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
  let converted : PositiveBelowTenList = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    let item : PositiveBelowTenAlias = element
    if !ion_schema_codegen_matches_named_Positive(element) {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="all_of",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    if !ion_schema_codegen_matches_named_BelowTen(element) {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="all_of",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert PositiveBelowTenList into an Ion list.
pub fn to_ion_PositiveBelowTenList(
  items : PositiveBelowTenList,
) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct PositiveBelowTenRecord {
  value : PositiveBelowTenAlias
}

///|
/// Convert an Ion struct to PositiveBelowTenRecord with field-level diagnostics.
pub fn PositiveBelowTenRecord::from_ion(
  value : @ion_model.IonValue,
) -> PositiveBelowTenRecord raise ConversionError {
  let type_path = "PositiveBelowTenRecord"
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
                  path="PositiveBelowTenRecord.value",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="PositiveBelowTenRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="PositiveBelowTenRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : PositiveBelowTenAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "PositiveBelowTenRecord.value"
      let field_item : PositiveBelowTenAlias = field_value
      if !ion_schema_codegen_matches_named_Positive(field_value) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="all_of",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      if !ion_schema_codegen_matches_named_BelowTen(field_value) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="all_of",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="PositiveBelowTenRecord.value",
      )
  }
  { value: ion_schema_codegen_value_0, }
}

///|
/// Convert PositiveBelowTenRecord into an Ion struct in schema field order.
pub fn PositiveBelowTenRecord::to_ion(
  self : PositiveBelowTenRecord,
) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("value"), self.value))
  @ion_model.IonValue::Struct(output_fields)
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
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::InvalidValue(
      path="MaybeInt",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_type(value, "int")) {
    raise ConversionError::InvalidValue(
      path="MaybeInt",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type MaybeTypedInt = @ion_model.IonValue

///|
/// Validate the type algebra constraints for MaybeTypedInt.
pub fn validate_type_MaybeTypedInt(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="MaybeTypedInt",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::InvalidValue(
      path="MaybeTypedInt",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_type(value, "$int")) {
    raise ConversionError::InvalidValue(
      path="MaybeTypedInt",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline8.
fn is_valid_values_IonSchemaCodegenInternalInline8(
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
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline8(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_8",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline8(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_8",
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
pub type InlineEven = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineEven.
pub fn validate_type_InlineEven(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineEven",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline8(value) {
    raise ConversionError::InvalidValue(
      path="InlineEven",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline10.
fn is_valid_values_IonSchemaCodegenInternalInline10(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("2") catch { _ => [] }
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
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_10",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline10(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_10",
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
pub type MaybeInlineEven = @ion_model.IonValue

///|
/// Validate the type algebra constraints for MaybeInlineEven.
pub fn validate_type_MaybeInlineEven(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="MaybeInlineEven",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline10(value)) {
    raise ConversionError::InvalidValue(
      path="MaybeInlineEven",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
type IonSchemaCodegenInternalInline13 = @bigint.BigInt

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline13.
fn is_valid_values_IonSchemaCodegenInternalInline13(
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
type IonSchemaCodegenInternalInline12 = Array[IonSchemaCodegenInternalInline13]

///|
/// Convert an Ion list to IonSchemaCodegenInternalInline12 with element-level diagnostics.
fn from_ion_IonSchemaCodegenInternalInline12(
  value : @ion_model.IonValue,
) -> IonSchemaCodegenInternalInline12 raise ConversionError {
  let type_path = "ion_schema_codegen_internal_inline_12"
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
  if input_elements.length() < 1 || input_elements.length() > 3 {
    raise ConversionError::InvalidValue(
      path=type_path,
      constraint="container_length",
      actual=input_elements.length().to_string(),
    )
  }
  let converted : IonSchemaCodegenInternalInline12 = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : IonSchemaCodegenInternalInline13 = match
      element.without_annotations() {
      @ion_model.IonValue::Int(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="int",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline13(element) {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline12(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    ignore(from_ion_IonSchemaCodegenInternalInline12(value))
    true
  } catch {
    _ => false
  }
}

///|
pub type InlineIntList = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineIntList.
pub fn validate_type_InlineIntList(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineIntList",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline12(value) {
    raise ConversionError::InvalidValue(
      path="InlineIntList",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
type IonSchemaCodegenInternalInline16 = @bigint.BigInt

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline16.
fn is_valid_values_IonSchemaCodegenInternalInline16(
  value : @ion_model.IonValue,
) -> Bool {
  let allowed_values = @ion.parse_text("7") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_match(value, candidate) {
      return true
    }
  }
  false
}

///|
type IonSchemaCodegenInternalInline17 = String

///|
priv struct IonSchemaCodegenInternalInline15 {
  id : IonSchemaCodegenInternalInline16
  label : IonSchemaCodegenInternalInline17?
}

///|
/// Convert an Ion struct to IonSchemaCodegenInternalInline15 with field-level diagnostics.
fn IonSchemaCodegenInternalInline15::from_ion(
  value : @ion_model.IonValue,
) -> IonSchemaCodegenInternalInline15 raise ConversionError {
  let type_path = "ion_schema_codegen_internal_inline_15"
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
          "id" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ion_schema_codegen_internal_inline_15.id",
                )
              None => Some(field_value)
            }
          "label" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ion_schema_codegen_internal_inline_15.label",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="ion_schema_codegen_internal_inline_15." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="ion_schema_codegen_internal_inline_15.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : IonSchemaCodegenInternalInline16 = match
    input_field_0 {
    Some(field_value) => {
      let field_path = "ion_schema_codegen_internal_inline_15.id"
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : IonSchemaCodegenInternalInline16 = match
        field_value.without_annotations() {
        @ion_model.IonValue::Int(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="int",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      if !is_valid_values_IonSchemaCodegenInternalInline16(field_value) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="valid_values",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="ion_schema_codegen_internal_inline_15.id",
      )
  }
  let ion_schema_codegen_value_1 : IonSchemaCodegenInternalInline17? = match
    input_field_1 {
    Some(field_value) => {
      let field_path = "ion_schema_codegen_internal_inline_15.label"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : IonSchemaCodegenInternalInline17 = match
        field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      if !ion_schema_codegen_regex_matches(field_value, "^[a-z]+$") {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="regex",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      Some(field_item)
    }
    None => None
  }
  { id: ion_schema_codegen_value_0, label: ion_schema_codegen_value_1, }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline15(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    let matched = IonSchemaCodegenInternalInline15::from_ion(value)
    ignore(matched.id)
    ignore(matched.label)
    true
  } catch {
    _ => false
  }
}

///|
pub type InlineRecord = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineRecord.
pub fn validate_type_InlineRecord(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineRecord",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline15(value) {
    raise ConversionError::InvalidValue(
      path="InlineRecord",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline19.
fn is_valid_values_IonSchemaCodegenInternalInline19(
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
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline19(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_19",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline19(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_19",
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !is_valid_values_Positive(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_19",
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
pub type InlineAlias = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineAlias.
pub fn validate_type_InlineAlias(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineAlias",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline19(value) {
    raise ConversionError::InvalidValue(
      path="InlineAlias",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
type IonSchemaCodegenInternalInline22 = @bigint.BigInt

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline22.
fn is_valid_values_IonSchemaCodegenInternalInline22(
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
type IonSchemaCodegenInternalInline21 = Array[IonSchemaCodegenInternalInline22]

///|
/// Convert an Ion list to IonSchemaCodegenInternalInline21 with element-level diagnostics.
fn from_ion_IonSchemaCodegenInternalInline21(
  value : @ion_model.IonValue,
) -> IonSchemaCodegenInternalInline21 raise ConversionError {
  let type_path = "ion_schema_codegen_internal_inline_21"
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
  let converted : IonSchemaCodegenInternalInline21 = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : IonSchemaCodegenInternalInline22 = match
      element.without_annotations() {
      @ion_model.IonValue::Int(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="int",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    if !is_valid_values_IonSchemaCodegenInternalInline22(element) {
      raise ConversionError::InvalidValue(
        path=element_path,
        constraint="valid_values",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline21(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    ignore(from_ion_IonSchemaCodegenInternalInline21(value))
    true
  } catch {
    _ => false
  }
}

///|
pub type MaybeInlineIntList = @ion_model.IonValue

///|
/// Validate the type algebra constraints for MaybeInlineIntList.
pub fn validate_type_MaybeInlineIntList(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="MaybeInlineIntList",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !(ion_schema_codegen_matches_type(value, "$null") ||
    ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline21(value)) {
    raise ConversionError::InvalidValue(
      path="MaybeInlineIntList",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
type IonSchemaCodegenInternalInline24 = Array[@bigint.BigInt]

///|
/// Convert an Ion list to IonSchemaCodegenInternalInline24 with element-level diagnostics.
fn from_ion_IonSchemaCodegenInternalInline24(
  value : @ion_model.IonValue,
) -> IonSchemaCodegenInternalInline24 raise ConversionError {
  let type_path = "ion_schema_codegen_internal_inline_24"
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
  if input_elements.length() < 2 || input_elements.length() > 3 {
    raise ConversionError::InvalidValue(
      path=type_path,
      constraint="container_length",
      actual=input_elements.length().to_string(),
    )
  }
  ion_schema_codegen_check_contains(input_elements, "2", type_path)
  ion_schema_codegen_check_distinct(input_elements, type_path)
  let converted : IonSchemaCodegenInternalInline24 = []
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
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline24(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    ignore(from_ion_IonSchemaCodegenInternalInline24(value))
    true
  } catch {
    _ => false
  }
}

///|
pub type InlineConstrainedList = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineConstrainedList.
pub fn validate_type_InlineConstrainedList(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineConstrainedList",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline24(value) {
    raise ConversionError::InvalidValue(
      path="InlineConstrainedList",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
priv struct IonSchemaCodegenInternalInline26 {
  id : @bigint.BigInt
  ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ]
}

///|
/// Convert an Ion struct to IonSchemaCodegenInternalInline26 with field-level diagnostics.
fn IonSchemaCodegenInternalInline26::from_ion(
  value : @ion_model.IonValue,
) -> IonSchemaCodegenInternalInline26 raise ConversionError {
  let type_path = "ion_schema_codegen_internal_inline_26"
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
  ion_schema_codegen_check_contains(
    ion_schema_codegen_struct_field_values(input_fields),
    "2",
    type_path,
  )
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
    if ion_schema_codegen_struct_element_value.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(
        path=ion_schema_codegen_struct_element_path,
      )
    }
    if ion_schema_codegen_struct_element_value.is_null() {
      raise ConversionError::NullNotAllowed(
        path=ion_schema_codegen_struct_element_path,
      )
    }
    if !ion_schema_codegen_matches_type(
        ion_schema_codegen_struct_element_value, "int",
      ) {
      raise ConversionError::TypeMismatch(
        path=ion_schema_codegen_struct_element_path,
        expected="int",
        actual=ion_schema_codegen_actual_type(
          ion_schema_codegen_struct_element_value,
        ),
      )
    }
    ion_schema_codegen_struct_element_index += 1
  }
  let mut ion_schema_codegen_field_name_index_IonSchemaCodegenInternalInline26 = 0
  for
    (ion_schema_codegen_field_name_symbol_IonSchemaCodegenInternalInline26, _) in input_fields {
    let ion_schema_codegen_field_name_path_IonSchemaCodegenInternalInline26 = type_path +
      "." +
      ion_schema_codegen_field_name_symbol_IonSchemaCodegenInternalInline26
      .text_value()
      .unwrap_or("<field>") +
      "[" +
      ion_schema_codegen_field_name_index_IonSchemaCodegenInternalInline26.to_string() +
      "]"
    if @ion_model.IonValue::Symbol(
        ion_schema_codegen_field_name_symbol_IonSchemaCodegenInternalInline26,
      )
      .annotations()
      .length() >
      0 {
      raise ConversionError::AnnotatedValueNotSupported(
        path=ion_schema_codegen_field_name_path_IonSchemaCodegenInternalInline26,
      )
    }
    if @ion_model.IonValue::Symbol(
        ion_schema_codegen_field_name_symbol_IonSchemaCodegenInternalInline26,
      ).is_null() {
      raise ConversionError::NullNotAllowed(
        path=ion_schema_codegen_field_name_path_IonSchemaCodegenInternalInline26,
      )
    }
    if !ion_schema_codegen_matches_type(
        @ion_model.IonValue::Symbol(
          ion_schema_codegen_field_name_symbol_IonSchemaCodegenInternalInline26,
        ),
        "symbol",
      ) {
      raise ConversionError::TypeMismatch(
        path=ion_schema_codegen_field_name_path_IonSchemaCodegenInternalInline26,
        expected="symbol",
        actual=ion_schema_codegen_actual_type(
          @ion_model.IonValue::Symbol(
            ion_schema_codegen_field_name_symbol_IonSchemaCodegenInternalInline26,
          ),
        ),
      )
    }
    ion_schema_codegen_field_name_index_IonSchemaCodegenInternalInline26 += 1
  }
  let ion_schema_codegen_field_names_IonSchemaCodegenInternalInline26 : Array[
    @ion_model.IonSymbol,
  ] = []
  for (ion_schema_codegen_field_name, _) in input_fields {
    ion_schema_codegen_field_names_IonSchemaCodegenInternalInline26.push(
      ion_schema_codegen_field_name,
    )
  }
  ion_schema_codegen_check_distinct_symbols(
    ion_schema_codegen_field_names_IonSchemaCodegenInternalInline26, type_path,
  )
  let ion_schema_codegen_distinct_IonSchemaCodegenInternalInline26 : Array[
    @ion_model.IonValue,
  ] = []
  for (_, ion_schema_codegen_distinct_value) in input_fields {
    ion_schema_codegen_distinct_IonSchemaCodegenInternalInline26.push(
      ion_schema_codegen_distinct_value,
    )
  }
  ion_schema_codegen_check_distinct(
    ion_schema_codegen_distinct_IonSchemaCodegenInternalInline26, type_path,
  )
  if input_fields.length() < 1 || input_fields.length() > 3 {
    raise ConversionError::InvalidValue(
      path=type_path,
      constraint="container_length",
      actual=input_fields.length().to_string(),
    )
  }
  let ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ] = []
  let mut input_field_0 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "id" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ion_schema_codegen_internal_inline_26.id",
                )
              None => Some(field_value)
            }
          _ => ion_schema_codegen_open_content.push((field_symbol, field_value))
        }
      None => ion_schema_codegen_open_content.push((field_symbol, field_value))
    }
  }
  let ion_schema_codegen_value_0 : @bigint.BigInt = match input_field_0 {
    Some(field_value) => {
      let field_path = "ion_schema_codegen_internal_inline_26.id"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : @bigint.BigInt = match
        field_value.without_annotations() {
        @ion_model.IonValue::Int(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="int",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="ion_schema_codegen_internal_inline_26.id",
      )
  }
  { id: ion_schema_codegen_value_0, ion_schema_codegen_open_content, }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline26(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    let matched = IonSchemaCodegenInternalInline26::from_ion(value)
    ignore(matched.id)
    ignore(matched.ion_schema_codegen_open_content)
    true
  } catch {
    _ => false
  }
}

///|
pub type InlineConstrainedRecord = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineConstrainedRecord.
pub fn validate_type_InlineConstrainedRecord(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineConstrainedRecord",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline26(value) {
    raise ConversionError::InvalidValue(
      path="InlineConstrainedRecord",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub(all) struct InlineRecordEnvelope {
  payload : InlineConstrainedRecord
}

///|
/// Convert an Ion struct to InlineRecordEnvelope with field-level diagnostics.
pub fn InlineRecordEnvelope::from_ion(
  value : @ion_model.IonValue,
) -> InlineRecordEnvelope raise ConversionError {
  let type_path = "InlineRecordEnvelope"
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
                  path="InlineRecordEnvelope.payload",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="InlineRecordEnvelope." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="InlineRecordEnvelope.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : InlineConstrainedRecord = match
    input_field_0 {
    Some(field_value) => {
      let field_path = "InlineRecordEnvelope.payload"
      let field_item : InlineConstrainedRecord = field_value
      if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline26(
          field_value,
        ) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="all_of",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="InlineRecordEnvelope.payload",
      )
  }
  { payload: ion_schema_codegen_value_0, }
}

///|
/// Convert InlineRecordEnvelope into an Ion struct in schema field order.
pub fn InlineRecordEnvelope::to_ion(
  self : InlineRecordEnvelope,
) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("payload"), self.payload))
  @ion_model.IonValue::Struct(output_fields)
}

///|
/// Test whether an Ion value satisfies valid_values for IonSchemaCodegenInternalInline30.
fn is_valid_values_IonSchemaCodegenInternalInline30(
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
type IonSchemaCodegenInternalInline29 = Array[@ion_model.IonValue]

///|
/// Convert an Ion list to IonSchemaCodegenInternalInline29 while validating its ordered elements.
fn from_ion_IonSchemaCodegenInternalInline29(
  value : @ion_model.IonValue,
) -> IonSchemaCodegenInternalInline29 raise ConversionError {
  let type_path = "ion_schema_codegen_internal_inline_29"
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
  ion_schema_codegen_validate_ordered_IonSchemaCodegenInternalInline29(
    input_elements, type_path,
  )
  input_elements
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline29(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    ignore(from_ion_IonSchemaCodegenInternalInline29(value))
    true
  } catch {
    _ => false
  }
}

///|
pub type InlineOrderedList = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineOrderedList.
pub fn validate_type_InlineOrderedList(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineOrderedList",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline29(value) {
    raise ConversionError::InvalidValue(
      path="InlineOrderedList",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline33(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_33",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_matches_named_Positive(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_33",
        constraint="all_of",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !ion_schema_codegen_matches_named_BelowTen(value) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_33",
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
pub type InlinePositiveBelowTen = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlinePositiveBelowTen.
pub fn validate_type_InlinePositiveBelowTen(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlinePositiveBelowTen",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline33(value) {
    raise ConversionError::InvalidValue(
      path="InlinePositiveBelowTen",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
fn ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline35(
  value : @ion_model.IonValue,
) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$any") {
      raise ConversionError::TypeMismatch(
        path="ion_schema_codegen_internal_inline_35",
        expected="$any",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    if !(ion_schema_codegen_matches_named_Positive(value) ||
      ion_schema_codegen_matches_type(value, "string")) {
      raise ConversionError::InvalidValue(
        path="ion_schema_codegen_internal_inline_35",
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
pub type InlineAnyPositiveOrString = @ion_model.IonValue

///|
/// Validate the type algebra constraints for InlineAnyPositiveOrString.
pub fn validate_type_InlineAnyPositiveOrString(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="InlineAnyPositiveOrString",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_matches_named_IonSchemaCodegenInternalInline35(value) {
    raise ConversionError::InvalidValue(
      path="InlineAnyPositiveOrString",
      constraint="all_of",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}
