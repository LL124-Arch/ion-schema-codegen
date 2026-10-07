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
  let mut ion_schema_codegen_document_index_7 = 0
  for ion_schema_codegen_document_value_7 in values {
    let ion_schema_codegen_document_path_7 = type_path +
      "[" +
      ion_schema_codegen_document_index_7.to_string() +
      "]"
    if !ion_schema_codegen_matches_type(
        ion_schema_codegen_document_value_7, "$any",
      ) {
      raise ConversionError::TypeMismatch(
        path=ion_schema_codegen_document_path_7,
        expected="$any",
        actual=ion_schema_codegen_actual_type(
          ion_schema_codegen_document_value_7,
        ),
      )
    }
    ion_schema_codegen_document_index_7 += 1
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
