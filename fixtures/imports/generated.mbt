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
pub type Imported1Shared = @bigint.BigInt

///|
pub type Imported1Extra = String

///|
pub(all) struct Imported2Envelope {
  value : Imported1Shared
}

///|
/// Convert an Ion struct to Imported2Envelope with field-level diagnostics.
pub fn Imported2Envelope::from_ion(
  value : @ion_model.IonValue,
) -> Imported2Envelope raise ConversionError {
  let type_path = "Imported2_Envelope"
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
                  path="Imported2_Envelope.value",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="Imported2_Envelope." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="Imported2_Envelope.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : Imported1Shared = match input_field_0 {
    Some(field_value) => {
      let field_path = "Imported2_Envelope.value"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Imported1Shared = match
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
        path="Imported2_Envelope.value",
      )
  }
  { value: ion_schema_codegen_value_0, }
}

///|
/// Convert Imported2Envelope into an Ion struct in schema field order.
pub fn Imported2Envelope::to_ion(
  self : Imported2Envelope,
) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("value"),
      @ion_model.IonValue::Int(self.value),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type Shared = Imported1Shared

///|
fn ion_schema_codegen_matches_named_Shared(value : @ion_model.IonValue) -> Bool {
  try {
    if !ion_schema_codegen_matches_type(value, "int") {
      raise ConversionError::TypeMismatch(
        path="Shared",
        expected="int",
        actual=ion_schema_codegen_actual_type(value),
      )
    }
    true
  } catch {
    _ => false
  }
}

///|
pub type Extra = Imported1Extra

///|
pub type ImportedEnvelope = Imported2Envelope

///|
pub(all) struct ImportedExample {
  shared : Imported1Shared
  extra : Imported1Extra
  envelope : Imported2Envelope
}

///|
/// Convert an Ion struct to ImportedExample with field-level diagnostics.
pub fn ImportedExample::from_ion(
  value : @ion_model.IonValue,
) -> ImportedExample raise ConversionError {
  let type_path = "ImportedExample"
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
          "shared" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ImportedExample.shared",
                )
              None => Some(field_value)
            }
          "extra" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ImportedExample.extra",
                )
              None => Some(field_value)
            }
          "envelope" =>
            input_field_2 = match input_field_2 {
              Some(_) =>
                raise ConversionError::DuplicateField(
                  path="ImportedExample.envelope",
                )
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="ImportedExample." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="ImportedExample.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : Imported1Shared = match input_field_0 {
    Some(field_value) => {
      let field_path = "ImportedExample.shared"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Imported1Shared = match
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
      raise ConversionError::MissingRequiredField(path="ImportedExample.shared")
  }
  let ion_schema_codegen_value_1 : Imported1Extra = match input_field_1 {
    Some(field_value) => {
      let field_path = "ImportedExample.extra"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Imported1Extra = match
        field_value.without_annotations() {
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
    None =>
      raise ConversionError::MissingRequiredField(path="ImportedExample.extra")
  }
  let ion_schema_codegen_value_2 : Imported2Envelope = match input_field_2 {
    Some(field_value) => {
      let field_path = "ImportedExample.envelope"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Imported2Envelope = Imported2Envelope::from_ion(
        field_value,
      ) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(
        path="ImportedExample.envelope",
      )
  }
  {
    shared: ion_schema_codegen_value_0,
    extra: ion_schema_codegen_value_1,
    envelope: ion_schema_codegen_value_2,
  }
}

///|
/// Convert ImportedExample into an Ion struct in schema field order.
pub fn ImportedExample::to_ion(self : ImportedExample) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("shared"),
      @ion_model.IonValue::Int(self.shared),
    ),
  )
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("extra"),
      @ion_model.IonValue::String(self.extra),
    ),
  )
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("envelope"),
      Imported2Envelope::to_ion(self.envelope),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type NotShared = @ion_model.IonValue

///|
/// Validate the type algebra constraints for NotShared.
pub fn validate_type_NotShared(
  value : @ion_model.IonValue,
) -> Unit raise ConversionError {
  if !ion_schema_codegen_matches_type(value, "$any") {
    raise ConversionError::TypeMismatch(
      path="NotShared",
      expected="$any",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
  if ion_schema_codegen_matches_named_Shared(value) {
    raise ConversionError::InvalidValue(
      path="NotShared",
      constraint="not",
      actual=ion_schema_codegen_actual_type(value),
    )
  }
}
