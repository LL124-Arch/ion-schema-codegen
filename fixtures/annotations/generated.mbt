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
      (kind == @ion_model.IonNull::Int ||
        kind == @ion_model.IonNull::Float ||
        kind == @ion_model.IonNull::Decimal) && (expected == "$number" || !is_null)
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
fn ion_schema_codegen_container_length(
  value : @ion_model.IonValue,
) -> Int? {
  match value.without_annotations() {
    @ion_model.IonValue::List(elements) => Some(elements.length())
    @ion_model.IonValue::Sexp(elements) => Some(elements.length())
    @ion_model.IonValue::Struct(fields) => Some(fields.length())
    _ => None
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
pub type Tagged = @ion_model.IonValue

///|
/// Validate annotations for Tagged.
pub fn validate_annotations_Tagged(value : @ion_model.IonValue) -> Unit raise ConversionError {
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
pub fn validate_annotations_OpenTagged(value : @ion_model.IonValue) -> Unit raise ConversionError {
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
fn ion_schema_codegen_matches_named_TwoAnnotationSymbols(value : @ion_model.IonValue) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "$list") {
      raise ConversionError::TypeMismatch(
        path="TwoAnnotationSymbols",
        expected="$list",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    match ion_schema_codegen_container_length(value) {
      Some(actual_length) => {
        if actual_length < 2 || actual_length > 2 {
          raise ConversionError::InvalidValue(
            path="TwoAnnotationSymbols",
            constraint="container_length",
            actual=actual_length.to_string(),
          )
        }
      }
      None => raise ConversionError::InvalidValue(
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
pub fn validate_annotations_ExactlyTwoTagged(value : @ion_model.IonValue) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="ExactlyTwoTagged",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotations_ExactlyTwoTagged_0 : Array[@ion_model.IonValue] = []
  for annotation in value.annotations() {
    ion_schema_codegen_annotations_ExactlyTwoTagged_0.push(@ion_model.IonValue::Symbol(annotation))
  }
  if !(ion_schema_codegen_matches_named_TwoAnnotationSymbols(@ion_model.IonValue::List(ion_schema_codegen_annotations_ExactlyTwoTagged_0))) {
    raise ConversionError::InvalidValue(
      path="ExactlyTwoTagged",
      constraint="annotations",
      actual="symbol list",
    )
  }
}

///|
pub type OneOrTwoAnnotations = @ion_model.IonValue

///|
/// Validate annotations for OneOrTwoAnnotations.
pub fn validate_annotations_OneOrTwoAnnotations(value : @ion_model.IonValue) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="OneOrTwoAnnotations",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  let ion_schema_codegen_annotation_count_OneOrTwoAnnotations_0 = value.annotations().length()
  if ion_schema_codegen_annotation_count_OneOrTwoAnnotations_0 < 1 || ion_schema_codegen_annotation_count_OneOrTwoAnnotations_0 > 2 {
    raise ConversionError::InvalidValue(
      path="OneOrTwoAnnotations",
      constraint="annotations",
      actual=ion_schema_codegen_annotation_count_OneOrTwoAnnotations_0.to_string(),
    )
  }
}

///|
pub type ContainsRecordAndVersion = @ion_model.IonValue

///|
/// Validate annotations for ContainsRecordAndVersion.
pub fn validate_annotations_ContainsRecordAndVersion(value : @ion_model.IonValue) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="ContainsRecordAndVersion",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_annotations_match(value, ["record", "v1"], false, true) {
    raise ConversionError::InvalidValue(
      path="ContainsRecordAndVersion",
      constraint="annotations",
      actual=ion_schema_codegen_actual_type(value),
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
    _ => raise ConversionError::TypeMismatch(path=type_path, expected="struct", actual=ion_schema_codegen_actual_type(value))
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "payload" => input_field_0 = match input_field_0 {
            Some(_) =>
              raise ConversionError::DuplicateField(
                path="ContainsRecordField.payload",
              )
            None => Some(field_value)
          }
          _ => raise ConversionError::UnknownField(path="ContainsRecordField." + field_name)
        }
      None => raise ConversionError::UnknownSymbol(path="ContainsRecordField.<field>", sid=field_symbol.sid_value().unwrap_or(0))
    }
  }
  let ion_schema_codegen_value_0 : ContainsRecordAndVersion = match input_field_0 {
    Some(field_value) => {
      let field_path = "ContainsRecordField.payload"
      let field_item : ContainsRecordAndVersion = field_value
      if !ion_schema_codegen_annotations_match(field_value, ["record", "v1"], false, true) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="annotations",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="ContainsRecordField.payload")
  }
  {
    payload: ion_schema_codegen_value_0,
  }
}

///|
/// Convert ContainsRecordField into an Ion struct in schema field order.
pub fn ContainsRecordField::to_ion(self : ContainsRecordField) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("payload"),
      self.payload),
  )
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type AllowedAnnotationTokens = @ion_model.IonValue

///|
/// Validate annotations for AllowedAnnotationTokens.
pub fn validate_annotations_AllowedAnnotationTokens(value : @ion_model.IonValue) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="AllowedAnnotationTokens",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !ion_schema_codegen_annotations_match(value, ["record", "v1"], true, false) {
    raise ConversionError::InvalidValue(
      path="AllowedAnnotationTokens",
      constraint="annotations",
      actual=ion_schema_codegen_actual_type(value),
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
    _ => raise ConversionError::TypeMismatch(path=type_path, expected="struct", actual=ion_schema_codegen_actual_type(value))
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "payload" => input_field_0 = match input_field_0 {
            Some(_) =>
              raise ConversionError::DuplicateField(
                path="AllowedAnnotationField.payload",
              )
            None => Some(field_value)
          }
          _ => raise ConversionError::UnknownField(path="AllowedAnnotationField." + field_name)
        }
      None => raise ConversionError::UnknownSymbol(path="AllowedAnnotationField.<field>", sid=field_symbol.sid_value().unwrap_or(0))
    }
  }
  let ion_schema_codegen_value_0 : AllowedAnnotationTokens = match input_field_0 {
    Some(field_value) => {
      let field_path = "AllowedAnnotationField.payload"
      let field_item : AllowedAnnotationTokens = field_value
      if !ion_schema_codegen_annotations_match(field_value, ["record", "v1"], true, false) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="annotations",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="AllowedAnnotationField.payload")
  }
  {
    payload: ion_schema_codegen_value_0,
  }
}

///|
/// Convert AllowedAnnotationField into an Ion struct in schema field order.
pub fn AllowedAnnotationField::to_ion(self : AllowedAnnotationField) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("payload"),
      self.payload),
  )
  @ion_model.IonValue::Struct(output_fields)
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
    if !ion_schema_codegen_annotations_match(element, ["record", "v1"], true, true) {
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
    _ => raise ConversionError::TypeMismatch(path=type_path, expected="struct", actual=ion_schema_codegen_actual_type(value))
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "payload" => input_field_0 = match input_field_0 {
            Some(_) =>
              raise ConversionError::DuplicateField(
                path="TagRecord.payload",
              )
            None => Some(field_value)
          }
          _ => raise ConversionError::UnknownField(path="TagRecord." + field_name)
        }
      None => raise ConversionError::UnknownSymbol(path="TagRecord.<field>", sid=field_symbol.sid_value().unwrap_or(0))
    }
  }
  let ion_schema_codegen_value_0 : TaggedAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "TagRecord.payload"
      let field_item : TaggedAlias = field_value
      if !ion_schema_codegen_annotations_match(field_value, ["record", "v1"], true, true) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="annotations",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="TagRecord.payload")
  }
  {
    payload: ion_schema_codegen_value_0,
  }
}

///|
/// Convert TagRecord into an Ion struct in schema field order.
pub fn TagRecord::to_ion(self : TagRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("payload"),
      self.payload),
  )
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
pub fn to_ion_document_Stream(
  values : Stream
) -> Array[@ion_model.IonValue] {
  values
}
