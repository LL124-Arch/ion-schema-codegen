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
pub(all) struct Person {
  id : @bigint.BigInt
  name : String
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
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "id" => {
            if input_field_0 is Some(_) {
              raise ConversionError::DuplicateField(path="Person.id")
            }
            input_field_0 = Some(field_value)
          }
          "name" => {
            if input_field_1 is Some(_) {
              raise ConversionError::DuplicateField(path="Person.name")
            }
            input_field_1 = Some(field_value)
          }
          "nickname" => {
            if input_field_2 is Some(_) {
              raise ConversionError::DuplicateField(path="Person.nickname")
            }
            input_field_2 = Some(field_value)
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
  let ion_schema_codegen_value_0 : @bigint.BigInt = match input_field_0 {
    Some(field_value) => {
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path="Person.id")
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="Person.id")
      }
      match field_value.without_annotations() {
        @ion_model.IonValue::Int(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path="Person.id",
            expected="int",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
    }
    None => raise ConversionError::MissingRequiredField(path="Person.id")
  }
  let ion_schema_codegen_value_1 : String = match input_field_1 {
    Some(field_value) => {
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path="Person.name")
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path="Person.name")
      }
      match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path="Person.name",
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
    }
    None => raise ConversionError::MissingRequiredField(path="Person.name")
  }
  let ion_schema_codegen_value_2 : String? = match input_field_2 {
    Some(field_value) => {
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path="Person.nickname")
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
    id: ion_schema_codegen_value_0,
    name: ion_schema_codegen_value_1,
    nickname: ion_schema_codegen_value_2,
  }
}

///|
/// Convert Person into an Ion struct in schema field order.
pub fn Person::to_ion(self : Person) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (@ion_model.IonSymbol::from_text("id"), @ion_model.IonValue::Int(self.id)),
  )
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("name"),
      @ion_model.IonValue::String(self.name),
    ),
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
