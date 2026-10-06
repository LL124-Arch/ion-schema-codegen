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
pub(all) struct Address {
  city : String?
}

///|
/// Convert an Ion struct to Address with field-level diagnostics.
pub fn Address::from_ion(
  value : @ion_model.IonValue,
) -> Address raise ConversionError {
  let type_path = "Address"
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
          "city" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="Address.city")
              None => Some(field_value)
            }
          _ => raise ConversionError::UnknownField(path="Address." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="Address.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : String? = match input_field_0 {
    Some(field_value) => {
      let field_path = "Address.city"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      Some(field_item)
    }
    None => None
  }
  { city: ion_schema_codegen_value_0, }
}

///|
/// Convert Address into an Ion struct in schema field order.
pub fn Address::to_ion(self : Address) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  match self.city {
    Some(field_value) =>
      output_fields.push(
        (
          @ion_model.IonSymbol::from_text("city"),
          @ion_model.IonValue::String(field_value),
        ),
      )
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type AddressList = Array[Address]

///|
/// Convert an Ion list to AddressList with element-level diagnostics.
pub fn from_ion_AddressList(
  value : @ion_model.IonValue,
) -> AddressList raise ConversionError {
  let type_path = "AddressList"
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
  let converted : AddressList = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : Address = Address::from_ion(element) catch {
      error => raise ion_schema_codegen_prefix_error(error, element_path + ".")
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert AddressList into an Ion list.
pub fn to_ion_AddressList(items : AddressList) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(Address::to_ion(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub type Score = @bigint.BigInt

///|
pub type Scores = Array[Score]

///|
/// Convert an Ion list to Scores with element-level diagnostics.
pub fn from_ion_Scores(
  value : @ion_model.IonValue,
) -> Scores raise ConversionError {
  let type_path = "Scores"
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
  let converted : Scores = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : Score = match element.without_annotations() {
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
/// Convert Scores into an Ion list.
pub fn to_ion_Scores(items : Scores) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Int(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct Person {
  primary : Address
  addresses : AddressList
  scores : Scores
  nickname : String?
}

///|
/// Convert an Ion struct to Person with field-level diagnostics.
pub fn Person::from_ion(
  value : @ion_model.IonValue,
) -> Person raise ConversionError {
  let type_path = "Person"
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
  let mut input_field_3 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "primary" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="Person.primary")
              None => Some(field_value)
            }
          "addresses" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="Person.addresses")
              None => Some(field_value)
            }
          "scores" =>
            input_field_2 = match input_field_2 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="Person.scores")
              None => Some(field_value)
            }
          "nickname" =>
            input_field_3 = match input_field_3 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="Person.nickname")
              None => Some(field_value)
            }
          _ => raise ConversionError::UnknownField(path="Person." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="Person.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : Address = match input_field_0 {
    Some(field_value) => {
      let field_path = "Person.primary"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Address = Address::from_ion(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="Person.primary")
  }
  let ion_schema_codegen_value_1 : AddressList = match input_field_1 {
    Some(field_value) => {
      let field_path = "Person.addresses"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : AddressList = from_ion_AddressList(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="Person.addresses")
  }
  let ion_schema_codegen_value_2 : Scores = match input_field_2 {
    Some(field_value) => {
      let field_path = "Person.scores"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Scores = from_ion_Scores(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="Person.scores")
  }
  let ion_schema_codegen_value_3 : String? = match input_field_3 {
    Some(field_value) => {
      let field_path = "Person.nickname"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      Some(field_item)
    }
    None => None
  }
  {
    primary: ion_schema_codegen_value_0,
    addresses: ion_schema_codegen_value_1,
    scores: ion_schema_codegen_value_2,
    nickname: ion_schema_codegen_value_3,
  }
}

///|
/// Convert Person into an Ion struct in schema field order.
pub fn Person::to_ion(self : Person) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("primary"), Address::to_ion(self.primary)),
  )
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("addresses"),
      to_ion_AddressList(self.addresses),
    ),
  )
  output_fields.push(
    (@ion_model.IonSymbol::from_text("scores"), to_ion_Scores(self.scores)),
  )
  match self.nickname {
    Some(field_value) =>
      output_fields.push(
        (
          @ion_model.IonSymbol::from_text("nickname"),
          @ion_model.IonValue::String(field_value),
        ),
      )
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type Expression = Array[@ion_model.IonValue]

///|
pub type Expressions = Array[Expression]

///|
/// Convert an Ion list to Expressions with element-level diagnostics.
pub fn from_ion_Expressions(
  value : @ion_model.IonValue,
) -> Expressions raise ConversionError {
  let type_path = "Expressions"
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
  let converted : Expressions = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : Expression = match element.without_annotations() {
      @ion_model.IonValue::Sexp(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="sexp",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert Expressions into an Ion list.
pub fn to_ion_Expressions(items : Expressions) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Sexp(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct ExpressionRecord {
  expression : Expression
}

///|
/// Convert an Ion struct to ExpressionRecord with field-level diagnostics.
pub fn ExpressionRecord::from_ion(
  value : @ion_model.IonValue,
) -> ExpressionRecord raise ConversionError {
  let type_path = "ExpressionRecord"
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
                  path="ExpressionRecord.expression",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="ExpressionRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="ExpressionRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : Expression = match input_field_0 {
    Some(field_value) => {
      let field_path = "ExpressionRecord.expression"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Expression = match field_value.without_annotations() {
        @ion_model.IonValue::Sexp(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="sexp",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="ExpressionRecord.expression",
      )
  }
  { expression: ion_schema_codegen_value_0, }
}

///|
/// Convert ExpressionRecord into an Ion struct in schema field order.
pub fn ExpressionRecord::to_ion(self : ExpressionRecord) -> @ion_model.IonValue {
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
pub type AnyValue = @ion_model.IonValue

///|
pub type AnyValues = Array[AnyValue]

///|
/// Convert an Ion list to AnyValues with element-level diagnostics.
pub fn from_ion_AnyValues(
  value : @ion_model.IonValue,
) -> AnyValues raise ConversionError {
  let type_path = "AnyValues"
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
  let converted : AnyValues = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : AnyValue = element
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert AnyValues into an Ion list.
pub fn to_ion_AnyValues(items : AnyValues) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct AnyRecord {
  named_value : AnyValue
  raw : @ion_model.IonValue
  optional_raw : @ion_model.IonValue?
}

///|
/// Convert an Ion struct to AnyRecord with field-level diagnostics.
pub fn AnyRecord::from_ion(
  value : @ion_model.IonValue,
) -> AnyRecord raise ConversionError {
  let type_path = "AnyRecord"
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
          "named_value" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="AnyRecord.named_value",
                )
              None => Some(field_value)
            }
          "raw" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="AnyRecord.raw")
              None => Some(field_value)
            }
          "optional_raw" =>
            input_field_2 = match input_field_2 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="AnyRecord.optional_raw",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(path="AnyRecord." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="AnyRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : AnyValue = match input_field_0 {
    Some(field_value) => {
      let field_path = "AnyRecord.named_value"
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : AnyValue = field_value
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="AnyRecord.named_value")
  }
  let ion_schema_codegen_value_1 : @ion_model.IonValue = match input_field_1 {
    Some(field_value) => {
      let field_path = "AnyRecord.raw"
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : @ion_model.IonValue = field_value
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="AnyRecord.raw")
  }
  let ion_schema_codegen_value_2 : @ion_model.IonValue? = match input_field_2 {
    Some(field_value) => {
      let field_path = "AnyRecord.optional_raw"
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : @ion_model.IonValue = field_value
      Some(field_item)
    }
    None => None
  }
  {
    named_value: ion_schema_codegen_value_0,
    raw: ion_schema_codegen_value_1,
    optional_raw: ion_schema_codegen_value_2,
  }
}

///|
/// Convert AnyRecord into an Ion struct in schema field order.
pub fn AnyRecord::to_ion(self : AnyRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("named_value"), self.named_value),
  )
  output_fields.push((@ion_model.IonSymbol::from_text("raw"), self.raw))
  match self.optional_raw {
    Some(field_value) =>
      output_fields.push(
        (@ion_model.IonSymbol::from_text("optional_raw"), field_value),
      )
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type NullableValue = @ion_model.IonValue

///|
pub type NullableValues = Array[NullableValue]

///|
/// Convert an Ion list to NullableValues with element-level diagnostics.
pub fn from_ion_NullableValues(
  value : @ion_model.IonValue,
) -> NullableValues raise ConversionError {
  let type_path = "NullableValues"
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
  let converted : NullableValues = []
  for element in input_elements {
    let item : NullableValue = element
    converted.push(item)
  }
  converted
}

///|
/// Convert NullableValues into an Ion list.
pub fn to_ion_NullableValues(items : NullableValues) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct NullableRecord {
  value : @ion_model.IonValue
  optional : NullableValue?
}

///|
/// Convert an Ion struct to NullableRecord with field-level diagnostics.
pub fn NullableRecord::from_ion(
  value : @ion_model.IonValue,
) -> NullableRecord raise ConversionError {
  let type_path = "NullableRecord"
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
          "value" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NullableRecord.value",
                )
              None => Some(field_value)
            }
          "optional" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NullableRecord.optional",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="NullableRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="NullableRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : @ion_model.IonValue = match input_field_0 {
    Some(field_value) => {
      let field_path = "NullableRecord.value"
      let _ = field_path
      let field_item : @ion_model.IonValue = field_value
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="NullableRecord.value")
  }
  let ion_schema_codegen_value_1 : NullableValue? = match input_field_1 {
    Some(field_value) => {
      let field_path = "NullableRecord.optional"
      let _ = field_path
      let field_item : NullableValue = field_value
      Some(field_item)
    }
    None => None
  }
  { value: ion_schema_codegen_value_0, optional: ion_schema_codegen_value_1, }
}

///|
/// Convert NullableRecord into an Ion struct in schema field order.
pub fn NullableRecord::to_ion(self : NullableRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push((@ion_model.IonSymbol::from_text("value"), self.value))
  match self.optional {
    Some(field_value) =>
      output_fields.push(
        (@ion_model.IonSymbol::from_text("optional"), field_value),
      )
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type EventStream = Array[@ion_model.IonValue]

///|
/// Convert an Ion document stream to EventStream.
pub fn from_ion_document_EventStream(
  values : Array[@ion_model.IonValue],
) -> EventStream {
  values
}

///|
/// Convert EventStream to an Ion document stream.
pub fn to_ion_document_EventStream(
  values : EventStream,
) -> Array[@ion_model.IonValue] {
  values
}

///|
pub type EventStreamAlias = EventStream

///|
/// Convert an Ion document stream to EventStreamAlias.
pub fn from_ion_document_EventStreamAlias(
  values : Array[@ion_model.IonValue],
) -> EventStreamAlias {
  values
}

///|
/// Convert EventStreamAlias to an Ion document stream.
pub fn to_ion_document_EventStreamAlias(
  values : EventStreamAlias,
) -> Array[@ion_model.IonValue] {
  values
}

///|
pub type NullableInt = @ion_model.IonValue

///|
pub type NullableInts = Array[NullableInt]

///|
/// Convert an Ion list to NullableInts with element-level diagnostics.
pub fn from_ion_NullableInts(
  value : @ion_model.IonValue,
) -> NullableInts raise ConversionError {
  let type_path = "NullableInts"
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
  let converted : NullableInts = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    let item : NullableInt = if ion_schema_codegen_matches_type(element, "$int") {
      element
    } else {
      raise ConversionError::TypeMismatch(
        path=element_path,
        expected="$int",
        actual=ion_schema_codegen_actual_type(element),
      )
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert NullableInts into an Ion list.
pub fn to_ion_NullableInts(items : NullableInts) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct NullableNominals {
  typed_int : NullableInt
  plain_null : @ion_model.IonValue
  maybe_text : @ion_model.IonValue?
  maybe_typed_int : @ion_model.IonValue?
  optional_boolean : @ion_model.IonValue?
}

///|
/// Convert an Ion struct to NullableNominals with field-level diagnostics.
pub fn NullableNominals::from_ion(
  value : @ion_model.IonValue,
) -> NullableNominals raise ConversionError {
  let type_path = "NullableNominals"
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
  let mut input_field_3 : @ion_model.IonValue? = None
  let mut input_field_4 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "typed_int" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NullableNominals.typed_int",
                )
              None => Some(field_value)
            }
          "plain_null" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NullableNominals.plain_null",
                )
              None => Some(field_value)
            }
          "maybe_text" =>
            input_field_2 = match input_field_2 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NullableNominals.maybe_text",
                )
              None => Some(field_value)
            }
          "maybe_typed_int" =>
            input_field_3 = match input_field_3 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NullableNominals.maybe_typed_int",
                )
              None => Some(field_value)
            }
          "optional_boolean" =>
            input_field_4 = match input_field_4 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="NullableNominals.optional_boolean",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="NullableNominals." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="NullableNominals.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : NullableInt = match input_field_0 {
    Some(field_value) => {
      let field_path = "NullableNominals.typed_int"
      let field_item : NullableInt = if ion_schema_codegen_matches_type(
          field_value, "$int",
        ) {
        field_value
      } else {
        raise ConversionError::TypeMismatch(
          path=field_path,
          expected="$int",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="NullableNominals.typed_int",
      )
  }
  let ion_schema_codegen_value_1 : @ion_model.IonValue = match input_field_1 {
    Some(field_value) => {
      let field_path = "NullableNominals.plain_null"
      let field_item : @ion_model.IonValue = if ion_schema_codegen_matches_type(
          field_value, "$null",
        ) {
        field_value
      } else {
        raise ConversionError::TypeMismatch(
          path=field_path,
          expected="$null",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="NullableNominals.plain_null",
      )
  }
  let ion_schema_codegen_value_2 : @ion_model.IonValue? = match input_field_2 {
    Some(field_value) => {
      let field_path = "NullableNominals.maybe_text"
      let field_item : @ion_model.IonValue = if ion_schema_codegen_matches_type(
          field_value, "$null",
        ) {
        field_value
      } else {
        if !ion_schema_codegen_matches_type(field_value, "string") {
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
        }
        field_value
      }
      Some(field_item)
    }
    None => None
  }
  let ion_schema_codegen_value_3 : @ion_model.IonValue? = match input_field_3 {
    Some(field_value) => {
      let field_path = "NullableNominals.maybe_typed_int"
      let field_item : @ion_model.IonValue = if ion_schema_codegen_matches_type(
          field_value, "$null",
        ) {
        field_value
      } else {
        if !ion_schema_codegen_matches_type(field_value, "$int") {
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="$int",
            actual=ion_schema_codegen_actual_type(field_value),
          )
        }
        field_value
      }
      Some(field_item)
    }
    None => None
  }
  let ion_schema_codegen_value_4 : @ion_model.IonValue? = match input_field_4 {
    Some(field_value) => {
      let field_path = "NullableNominals.optional_boolean"
      let field_item : @ion_model.IonValue = if ion_schema_codegen_matches_type(
          field_value, "$bool",
        ) {
        field_value
      } else {
        raise ConversionError::TypeMismatch(
          path=field_path,
          expected="$bool",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      Some(field_item)
    }
    None => None
  }
  {
    typed_int: ion_schema_codegen_value_0,
    plain_null: ion_schema_codegen_value_1,
    maybe_text: ion_schema_codegen_value_2,
    maybe_typed_int: ion_schema_codegen_value_3,
    optional_boolean: ion_schema_codegen_value_4,
  }
}

///|
/// Convert NullableNominals into an Ion struct in schema field order.
pub fn NullableNominals::to_ion(self : NullableNominals) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("typed_int"), self.typed_int),
  )
  output_fields.push(
    (@ion_model.IonSymbol::from_text("plain_null"), self.plain_null),
  )
  match self.maybe_text {
    Some(field_value) =>
      output_fields.push(
        (@ion_model.IonSymbol::from_text("maybe_text"), field_value),
      )
    None => ()
  }
  match self.maybe_typed_int {
    Some(field_value) =>
      output_fields.push(
        (@ion_model.IonSymbol::from_text("maybe_typed_int"), field_value),
      )
    None => ()
  }
  match self.optional_boolean {
    Some(field_value) =>
      output_fields.push(
        (@ion_model.IonSymbol::from_text("optional_boolean"), field_value),
      )
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type MaybeNumbers = Array[@ion_model.IonValue]

///|
/// Convert an Ion list to MaybeNumbers with element-level diagnostics.
pub fn from_ion_MaybeNumbers(
  value : @ion_model.IonValue,
) -> MaybeNumbers raise ConversionError {
  let type_path = "MaybeNumbers"
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
  let converted : MaybeNumbers = []
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
/// Convert MaybeNumbers into an Ion list.
pub fn to_ion_MaybeNumbers(items : MaybeNumbers) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(element)
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct OccurrenceRecord {
  fixed : Array[String]
  bounded : Array[@bigint.BigInt]
  optional_name : String?
  at_least_one : Array[Bool]
}

///|
/// Convert an Ion struct to OccurrenceRecord with field-level diagnostics.
pub fn OccurrenceRecord::from_ion(
  value : @ion_model.IonValue,
) -> OccurrenceRecord raise ConversionError {
  let type_path = "OccurrenceRecord"
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
  let input_field_0 : Array[@ion_model.IonValue] = []
  let input_field_1 : Array[@ion_model.IonValue] = []
  let mut input_field_2 : @ion_model.IonValue? = None
  let input_field_3 : Array[@ion_model.IonValue] = []
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "fixed" => input_field_0.push(field_value)
          "bounded" => input_field_1.push(field_value)
          "optional_name" =>
            input_field_2 = match input_field_2 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="OccurrenceRecord.optional_name",
                )
              None => Some(field_value)
            }
          "at_least_one" => input_field_3.push(field_value)
          _ =>
            raise ConversionError::UnknownField(
              path="OccurrenceRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="OccurrenceRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let field_count_0 = input_field_0.length()
  if field_count_0 < 2 {
    raise ConversionError::FieldOccurrenceMismatch(
      path="OccurrenceRecord.fixed",
      expected="2",
      actual=field_count_0,
    )
  }
  if field_count_0 > 2 {
    raise ConversionError::FieldOccurrenceMismatch(
      path="OccurrenceRecord.fixed",
      expected="2",
      actual=field_count_0,
    )
  }
  let ion_schema_codegen_value_0_values : Array[String] = []
  let mut field_index_0 = 0
  for field_value in input_field_0 {
    let field_path = "OccurrenceRecord.fixed[" + field_index_0.to_string() + "]"
    if field_value.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=field_path)
    }
    if field_value.is_null() {
      raise ConversionError::NullNotAllowed(path=field_path)
    }
    let field_item : String = match field_value.without_annotations() {
      @ion_model.IonValue::String(converted_value) => converted_value
      _ =>
        raise ConversionError::TypeMismatch(
          path=field_path,
          expected="string",
          actual=ion_schema_codegen_actual_type(field_value),
        )
    }
    ion_schema_codegen_value_0_values.push(field_item)
    field_index_0 += 1
  }
  let ion_schema_codegen_value_0 : Array[String] = ion_schema_codegen_value_0_values
  let field_count_1 = input_field_1.length()
  if field_count_1 < 2 {
    raise ConversionError::FieldOccurrenceMismatch(
      path="OccurrenceRecord.bounded",
      expected="2..4",
      actual=field_count_1,
    )
  }
  if field_count_1 > 4 {
    raise ConversionError::FieldOccurrenceMismatch(
      path="OccurrenceRecord.bounded",
      expected="2..4",
      actual=field_count_1,
    )
  }
  let ion_schema_codegen_value_1_values : Array[@bigint.BigInt] = []
  let mut field_index_1 = 0
  for field_value in input_field_1 {
    let field_path = "OccurrenceRecord.bounded[" +
      field_index_1.to_string() +
      "]"
    if field_value.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=field_path)
    }
    if field_value.is_null() {
      raise ConversionError::NullNotAllowed(path=field_path)
    }
    let field_item : @bigint.BigInt = match field_value.without_annotations() {
      @ion_model.IonValue::Int(converted_value) => converted_value
      _ =>
        raise ConversionError::TypeMismatch(
          path=field_path,
          expected="int",
          actual=ion_schema_codegen_actual_type(field_value),
        )
    }
    ion_schema_codegen_value_1_values.push(field_item)
    field_index_1 += 1
  }
  let ion_schema_codegen_value_1 : Array[@bigint.BigInt] = ion_schema_codegen_value_1_values
  let ion_schema_codegen_value_2 : String? = match input_field_2 {
    Some(field_value) => {
      let field_path = "OccurrenceRecord.optional_name"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      Some(field_item)
    }
    None => None
  }
  let field_count_3 = input_field_3.length()
  if field_count_3 < 1 {
    raise ConversionError::FieldOccurrenceMismatch(
      path="OccurrenceRecord.at_least_one",
      expected="1+",
      actual=field_count_3,
    )
  }
  let ion_schema_codegen_value_3_values : Array[Bool] = []
  let mut field_index_3 = 0
  for field_value in input_field_3 {
    let field_path = "OccurrenceRecord.at_least_one[" +
      field_index_3.to_string() +
      "]"
    if field_value.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=field_path)
    }
    if field_value.is_null() {
      raise ConversionError::NullNotAllowed(path=field_path)
    }
    let field_item : Bool = match field_value.without_annotations() {
      @ion_model.IonValue::Bool(converted_value) => converted_value
      _ =>
        raise ConversionError::TypeMismatch(
          path=field_path,
          expected="bool",
          actual=ion_schema_codegen_actual_type(field_value),
        )
    }
    ion_schema_codegen_value_3_values.push(field_item)
    field_index_3 += 1
  }
  let ion_schema_codegen_value_3 : Array[Bool] = ion_schema_codegen_value_3_values
  {
    fixed: ion_schema_codegen_value_0,
    bounded: ion_schema_codegen_value_1,
    optional_name: ion_schema_codegen_value_2,
    at_least_one: ion_schema_codegen_value_3,
  }
}

///|
/// Convert OccurrenceRecord into an Ion struct in schema field order.
pub fn OccurrenceRecord::to_ion(self : OccurrenceRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  for field_value in self.fixed {
    output_fields.push(
      (
        @ion_model.IonSymbol::from_text("fixed"),
        @ion_model.IonValue::String(field_value),
      ),
    )
  }
  for field_value in self.bounded {
    output_fields.push(
      (
        @ion_model.IonSymbol::from_text("bounded"),
        @ion_model.IonValue::Int(field_value),
      ),
    )
  }
  match self.optional_name {
    Some(field_value) =>
      output_fields.push(
        (
          @ion_model.IonSymbol::from_text("optional_name"),
          @ion_model.IonValue::String(field_value),
        ),
      )
    None => ()
  }
  for field_value in self.at_least_one {
    output_fields.push(
      (
        @ion_model.IonSymbol::from_text("at_least_one"),
        @ion_model.IonValue::Bool(field_value),
      ),
    )
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct OpenRecord {
  known : String
  ion_schema_codegen_open_content : Array[
    (@ion_model.IonSymbol, @ion_model.IonValue),
  ]
}

///|
/// Convert an Ion struct to OpenRecord with field-level diagnostics.
pub fn OpenRecord::from_ion(
  value : @ion_model.IonValue,
) -> OpenRecord raise ConversionError {
  let type_path = "OpenRecord"
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
  let mut input_field_0 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "known" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="OpenRecord.known")
              None => Some(field_value)
            }
          _ => ion_schema_codegen_open_content.push((field_symbol, field_value))
        }
      None => ion_schema_codegen_open_content.push((field_symbol, field_value))
    }
  }
  let ion_schema_codegen_value_0 : String = match input_field_0 {
    Some(field_value) => {
      let field_path = "OpenRecord.known"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="OpenRecord.known")
  }
  { known: ion_schema_codegen_value_0, ion_schema_codegen_open_content, }
}

///|
/// Convert OpenRecord into an Ion struct in schema field order.
pub fn OpenRecord::to_ion(self : OpenRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("known"),
      @ion_model.IonValue::String(self.known),
    ),
  )
  for (field_symbol, field_value) in self.ion_schema_codegen_open_content {
    output_fields.push((field_symbol, field_value))
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type AllowedScore = @bigint.BigInt

///|
/// Test whether an Ion value is in the valid_values set for AllowedScore.
pub fn is_valid_values_AllowedScore(value : @ion_model.IonValue) -> Bool {
  let allowed_values = @ion.parse_text("10\n20") catch { _ => [] }
  for candidate in allowed_values {
    if ion_schema_codegen_valid_values_equal(value, candidate) {
      return true
    }
  }
  false
}

///|
/// Validate the Ion type and valid_values set for AllowedScore.
pub fn validate_AllowedScore(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "int") {
    raise ConversionError::TypeMismatch(
      path="AllowedScore",
      expected="int",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if !is_valid_values_AllowedScore(value) {
    raise ConversionError::InvalidValue(
      path="AllowedScore",
      constraint="valid_values",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}

///|
pub type AllowedScoreAlias = AllowedScore

///|
pub type AllowedScores = Array[AllowedScoreAlias]

///|
/// Convert an Ion list to AllowedScores with element-level diagnostics.
pub fn from_ion_AllowedScores(
  value : @ion_model.IonValue,
) -> AllowedScores raise ConversionError {
  let type_path = "AllowedScores"
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
  let converted : AllowedScores = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : AllowedScoreAlias = match element.without_annotations() {
      @ion_model.IonValue::Int(item) => item
      _ =>
        raise ConversionError::TypeMismatch(
          path=element_path,
          expected="int",
          actual=ion_schema_codegen_actual_type(element),
        )
    }
    if !is_valid_values_AllowedScore(element) {
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
/// Convert AllowedScores into an Ion list.
pub fn to_ion_AllowedScores(items : AllowedScores) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(@ion_model.IonValue::Int(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct ScoredRecord {
  score : AllowedScoreAlias
}

///|
/// Convert an Ion struct to ScoredRecord with field-level diagnostics.
pub fn ScoredRecord::from_ion(
  value : @ion_model.IonValue,
) -> ScoredRecord raise ConversionError {
  let type_path = "ScoredRecord"
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
          "score" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="ScoredRecord.score")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="ScoredRecord." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="ScoredRecord.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : AllowedScoreAlias = match input_field_0 {
    Some(field_value) => {
      let field_path = "ScoredRecord.score"
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : AllowedScoreAlias = match
        field_value.without_annotations() {
        @ion_model.IonValue::Int(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="int",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      if !is_valid_values_AllowedScore(field_value) {
        raise ConversionError::InvalidValue(
          path=field_path,
          constraint="valid_values",
          actual=ion_schema_codegen_actual_type(field_value),
        )
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="ScoredRecord.score")
  }
  { score: ion_schema_codegen_value_0, }
}

///|
/// Convert ScoredRecord into an Ion struct in schema field order.
pub fn ScoredRecord::to_ion(self : ScoredRecord) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("score"),
      @ion_model.IonValue::Int(self.score),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}
