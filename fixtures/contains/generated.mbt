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
pub type RequiredValues = Array[@ion_model.IonValue]

///|
/// Convert an Ion list to RequiredValues with element-level diagnostics.
pub fn from_ion_RequiredValues(
  value : @ion_model.IonValue,
) -> RequiredValues raise ConversionError {
  let type_path = "RequiredValues"
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
  ion_schema_codegen_check_contains(
    input_elements, "tag::1\n{a: 1, b: 2}\ntag::1", type_path,
  )
  let converted : RequiredValues = []
  for element in input_elements {
    let item : @ion_model.IonValue = element
    converted.push(item)
  }
  converted
}

///|
/// Convert RequiredValues into an Ion list.
pub fn to_ion_RequiredValues(items : RequiredValues) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type RequiredIntValues = Array[@bigint.BigInt]

///|
/// Convert an Ion list to RequiredIntValues with element-level diagnostics.
pub fn from_ion_RequiredIntValues(
  value : @ion_model.IonValue,
) -> RequiredIntValues raise ConversionError {
  let type_path = "RequiredIntValues"
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
  ion_schema_codegen_check_contains(input_elements, "3", type_path)
  let converted : RequiredIntValues = []
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
/// Convert RequiredIntValues into an Ion list.
pub fn to_ion_RequiredIntValues(
  items : RequiredIntValues,
) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Int(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type NullableIntValues = Array[@ion_model.IonValue]

///|
/// Convert an Ion list to NullableIntValues with element-level diagnostics.
pub fn from_ion_NullableIntValues(
  value : @ion_model.IonValue,
) -> NullableIntValues raise ConversionError {
  let type_path = "NullableIntValues"
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
  ion_schema_codegen_check_contains(input_elements, "1", type_path)
  let converted : NullableIntValues = []
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
/// Convert NullableIntValues into an Ion list.
pub fn to_ion_NullableIntValues(
  items : NullableIntValues,
) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type RequiredExpression = Array[@ion_model.IonValue]

///|
pub(all) struct RequiredFields {
  ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ]
}

///|
/// Convert an Ion struct to RequiredFields with field-level diagnostics.
pub fn RequiredFields::from_ion(
  value : @ion_model.IonValue,
) -> RequiredFields raise ConversionError {
  let type_path = "RequiredFields"
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
    "green",
    type_path,
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
/// Convert RequiredFields into an Ion struct in schema field order.
pub fn RequiredFields::to_ion(self : RequiredFields) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  for (field_symbol, field_value) in self.ion_schema_codegen_open_content {
    output_fields.push((field_symbol, field_value))
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type RequiredStream = Array[@ion_model.IonValue]

///|
/// Convert an Ion document stream to RequiredStream.
pub fn from_ion_document_RequiredStream(
  values : Array[@ion_model.IonValue],
) -> RequiredStream raise ConversionError {
  let type_path = "RequiredStream"
  ion_schema_codegen_check_contains(values, "1\n2", type_path)
  values
}

///|
/// Convert RequiredStream to an Ion document stream.
pub fn to_ion_document_RequiredStream(
  values : RequiredStream,
) -> Array[@ion_model.IonValue] {
  values
}

///|
pub type RequiredStreamAlias = RequiredStream

///|
/// Convert an Ion document stream to RequiredStreamAlias.
pub fn from_ion_document_RequiredStreamAlias(
  values : Array[@ion_model.IonValue],
) -> RequiredStreamAlias raise ConversionError {
  let type_path = "RequiredStreamAlias"
  ion_schema_codegen_check_contains(values, "3", type_path)
  ion_schema_codegen_check_contains(values, "1\n2", type_path)
  values
}

///|
/// Convert RequiredStreamAlias to an Ion document stream.
pub fn to_ion_document_RequiredStreamAlias(
  values : RequiredStreamAlias,
) -> Array[@ion_model.IonValue] {
  values
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
pub type RequiredFieldsAlias = BaseFields

///|
pub type BaseValues = Array[@ion_model.IonValue]

///|
/// Convert an Ion list to BaseValues with element-level diagnostics.
pub fn from_ion_BaseValues(
  value : @ion_model.IonValue,
) -> BaseValues raise ConversionError {
  let type_path = "BaseValues"
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
  let converted : BaseValues = []
  for element in input_elements {
    let item : @ion_model.IonValue = element
    converted.push(item)
  }
  converted
}

///|
/// Convert BaseValues into an Ion list.
pub fn to_ion_BaseValues(items : BaseValues) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type AliasValues = BaseValues

///|
pub(all) struct ContainsHolder {
  expression : RequiredExpression
  values : AliasValues
  record : RequiredFieldsAlias
}

///|
/// Convert an Ion struct to ContainsHolder with field-level diagnostics.
pub fn ContainsHolder::from_ion(
  value : @ion_model.IonValue,
) -> ContainsHolder raise ConversionError {
  let type_path = "ContainsHolder"
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
  let mut input_field_2 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "expression" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ContainsHolder.expression",
                )
              None => Some(field_value)
            }
          "values" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ContainsHolder.values",
                )
              None => Some(field_value)
            }
          "record" =>
            input_field_2 = match input_field_2 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ContainsHolder.record",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="ContainsHolder." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="ContainsHolder.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : RequiredExpression = match input_field_0 {
    Some(field_value) => {
      let field_path = "ContainsHolder.expression"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : RequiredExpression = match
        field_value.without_annotations() {
        @ion_model.IonValue::Sexp(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="sexp",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      let ion_schema_codegen_contains_values_RequiredExpression = match
        field_value.without_annotations() {
        @ion_model.IonValue::Sexp(values) => values
        _ =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="contains",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      ion_schema_codegen_check_contains(
        ion_schema_codegen_contains_values_RequiredExpression, "ready", field_path,
      )
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="ContainsHolder.expression",
      )
  }
  let ion_schema_codegen_value_1 : AliasValues = match input_field_1 {
    Some(field_value) => {
      let field_path = "ContainsHolder.values"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : AliasValues = from_ion_BaseValues(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      let ion_schema_codegen_contains_values_AliasValues = match
        field_value.without_annotations() {
        @ion_model.IonValue::List(values) => values
        _ =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="contains",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      ion_schema_codegen_check_contains(
        ion_schema_codegen_contains_values_AliasValues, "4\n4", field_path,
      )
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="ContainsHolder.values")
  }
  let ion_schema_codegen_value_2 : RequiredFieldsAlias = match input_field_2 {
    Some(field_value) => {
      let field_path = "ContainsHolder.record"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : RequiredFieldsAlias = BaseFields::from_ion(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      let ion_schema_codegen_contains_fields_RequiredFieldsAlias = match
        field_value.without_annotations() {
        @ion_model.IonValue::Struct(fields) => fields
        _ =>
          raise ConversionError::InvalidValue(
            path=field_path,
            constraint="contains",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      ion_schema_codegen_check_contains(
        ion_schema_codegen_struct_field_values(
          ion_schema_codegen_contains_fields_RequiredFieldsAlias,
        ),
        "blue",
        field_path,
      )
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="ContainsHolder.record")
  }
  {
    expression: ion_schema_codegen_value_0,
    values: ion_schema_codegen_value_1,
    record: ion_schema_codegen_value_2,
  }
}

///|
/// Convert ContainsHolder into an Ion struct in schema field order.
pub fn ContainsHolder::to_ion(self : ContainsHolder) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("expression"),
      @ion_model.IonValue::Sexp(self.expression),
    ),
  )
  output_fields.push(
    (@ion_model.IonSymbol::from_text("values"), to_ion_BaseValues(self.values)),
  )
  output_fields.push(
    (@ion_model.IonSymbol::from_text("record"), BaseFields::to_ion(self.record)),
  )
  @ion_model.IonValue::Struct(output_fields)
}
