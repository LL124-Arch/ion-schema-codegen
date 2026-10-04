///|
pub(all) suberror ConversionError {
  TypeMismatch(path~ : String, expected~ : String, actual~ : String)
  MissingRequiredField(path~ : String)
  DuplicateField(path~ : String)
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
fn ion_schema_codegen_prefix_error(
  error : ConversionError,
  prefix : String,
) -> ConversionError {
  match error {
    ConversionError::TypeMismatch(path~, expected~, actual~) =>
      ConversionError::TypeMismatch(path=prefix + path, expected~, actual~)
    ConversionError::MissingRequiredField(path~) =>
      ConversionError::MissingRequiredField(path=prefix + path)
    ConversionError::DuplicateField(path~) =>
      ConversionError::DuplicateField(path=prefix + path)
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
          "city" => {
            if input_field_0 is Some(_) {
              raise ConversionError::DuplicateField(path="Address.city")
            }
            input_field_0 = Some(field_value)
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
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path="Address.city")
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="Address.city")
      }
      match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => Some(converted_value)
        _ =>
          raise ConversionError::TypeMismatch(
            path="Address.city",
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
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
          "primary" => {
            if input_field_0 is Some(_) {
              raise ConversionError::DuplicateField(path="Person.primary")
            }
            input_field_0 = Some(field_value)
          }
          "addresses" => {
            if input_field_1 is Some(_) {
              raise ConversionError::DuplicateField(path="Person.addresses")
            }
            input_field_1 = Some(field_value)
          }
          "scores" => {
            if input_field_2 is Some(_) {
              raise ConversionError::DuplicateField(path="Person.scores")
            }
            input_field_2 = Some(field_value)
          }
          "nickname" => {
            if input_field_3 is Some(_) {
              raise ConversionError::DuplicateField(path="Person.nickname")
            }
            input_field_3 = Some(field_value)
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
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path="Person.primary")
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="Person.primary")
      }
      Address::from_ion(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, "Person.primary.")
      }
    }
    None => raise ConversionError::MissingRequiredField(path="Person.primary")
  }
  let ion_schema_codegen_value_1 : AddressList = match input_field_1 {
    Some(field_value) => {
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(
          path="Person.addresses",
        )
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="Person.addresses")
      }
      from_ion_AddressList(field_value) catch {
        error =>
          raise ion_schema_codegen_prefix_error(error, "Person.addresses.")
      }
    }
    None => raise ConversionError::MissingRequiredField(path="Person.addresses")
  }
  let ion_schema_codegen_value_2 : Scores = match input_field_2 {
    Some(field_value) => {
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path="Person.scores")
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="Person.scores")
      }
      from_ion_Scores(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, "Person.scores.")
      }
    }
    None => raise ConversionError::MissingRequiredField(path="Person.scores")
  }
  let ion_schema_codegen_value_3 : String? = match input_field_3 {
    Some(field_value) => {
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(
          path="Person.nickname",
        )
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="Person.nickname")
      }
      match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => Some(converted_value)
        _ =>
          raise ConversionError::TypeMismatch(
            path="Person.nickname",
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
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
          "expression" => {
            if input_field_0 is Some(_) {
              raise ConversionError::DuplicateField(
                path="ExpressionRecord.expression",
              )
            }
            input_field_0 = Some(field_value)
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
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(
          path="ExpressionRecord.expression",
        )
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(
          path="ExpressionRecord.expression",
        )
      }
      match field_value.without_annotations() {
        @ion_model.IonValue::Sexp(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path="ExpressionRecord.expression",
            expected="sexp",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
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
          "named_value" => {
            if input_field_0 is Some(_) {
              raise ConversionError::DuplicateField(
                path="AnyRecord.named_value",
              )
            }
            input_field_0 = Some(field_value)
          }
          "raw" => {
            if input_field_1 is Some(_) {
              raise ConversionError::DuplicateField(path="AnyRecord.raw")
            }
            input_field_1 = Some(field_value)
          }
          "optional_raw" => {
            if input_field_2 is Some(_) {
              raise ConversionError::DuplicateField(
                path="AnyRecord.optional_raw",
              )
            }
            input_field_2 = Some(field_value)
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
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="AnyRecord.named_value")
      }
      field_value
    }
    None =>
      raise ConversionError::MissingRequiredField(path="AnyRecord.named_value")
  }
  let ion_schema_codegen_value_1 : @ion_model.IonValue = match input_field_1 {
    Some(field_value) => {
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="AnyRecord.raw")
      }
      field_value
    }
    None => raise ConversionError::MissingRequiredField(path="AnyRecord.raw")
  }
  let ion_schema_codegen_value_2 : @ion_model.IonValue? = match input_field_2 {
    Some(field_value) => {
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="AnyRecord.optional_raw")
      }
      Some(field_value)
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
