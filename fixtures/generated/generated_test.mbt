///|
fn make_fixture_struct(
  fields : Array[(String, @ion_model.IonValue)],
) -> @ion_model.IonValue {
  let ion_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  for (name, value) in fields {
    ion_fields.push((@ion_model.IonSymbol::from_text(name), value))
  }
  @ion_model.IonValue::Struct(ion_fields)
}

///|
fn full_person_value() -> @ion_model.IonValue {
  @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("id"),
      @ion_model.IonValue::Int(
        @bigint.BigInt::from_string("123456789012345678901234567890"),
      ),
    ),
    (
      @ion_model.IonSymbol::from_text("name"),
      @ion_model.IonValue::String("Ada"),
    ),
    (
      @ion_model.IonSymbol::from_text("enabled"),
      @ion_model.IonValue::Bool(true),
    ),
    (@ion_model.IonSymbol::from_text("ratio"), @ion_model.IonValue::Float(1.5)),
    (
      @ion_model.IonSymbol::from_text("amount"),
      @ion_model.IonValue::Decimal(
        @ion_model.IonDecimal::new(
          coefficient=@bigint.BigInt::from_int(1230),
          exponent=-2,
        ),
      ),
    ),
    (
      @ion_model.IonSymbol::from_text("code"),
      @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_sid(77)),
    ),
    (
      @ion_model.IonSymbol::from_text("created"),
      @ion_model.IonValue::Timestamp(
        @ion_model.IonTimestamp::new(
          year=2026,
          month=Some(10),
          day=Some(4),
          hour=Some(0),
          minute=Some(0),
          second=Some(0),
          offset_minutes=Some(0),
          fraction_exponent=None,
          fraction_coefficient=None,
        ),
      ),
    ),
    (
      @ion_model.IonSymbol::from_text("payload"),
      @ion_model.IonValue::Blob(Bytes::from_array([1, 2, 3])),
    ),
    (
      @ion_model.IonSymbol::from_text("note"),
      @ion_model.IonValue::Clob(Bytes::from_array([105, 111, 110])),
    ),
  ])
}

///|
fn expect_person_error(
  value : @ion_model.IonValue,
) -> @generated.ConversionError {
  try @generated.Person::from_ion(value) catch {
    error => error
  } noraise {
    _ =>
      @generated.ConversionError::TypeMismatch(
        path="test",
        expected="error",
        actual="conversion succeeded",
      )
  }
}

///|
test "generated scalar conversions preserve Ion values on round trip" {
  let input = full_person_value()
  let person = @generated.Person::from_ion(input)
  assert_eq(@generated.Person::to_ion(person), input)
}

///|
test "optional fields can be absent and stay absent when written back" {
  let input = make_fixture_struct([
    ("id", @ion_model.IonValue::Int(@bigint.BigInt::from_int(7))),
    ("name", @ion_model.IonValue::String("Grace")),
  ])
  let person = @generated.Person::from_ion(input)
  assert_eq(person.enabled, None)
  assert_eq(@generated.Person::to_ion(person), input)
}

///|
test "conversion reports missing duplicate unknown and unresolved fields" {
  let missing = expect_person_error(
    make_fixture_struct([
      ("id", @ion_model.IonValue::Int(@bigint.BigInt::from_int(1))),
    ]),
  )
  assert_true(
    match missing {
      @generated.ConversionError::MissingRequiredField(path~) =>
        path == "Person.name"
      _ => false
    },
  )

  let duplicate = expect_person_error(
    make_fixture_struct([
      ("id", @ion_model.IonValue::Int(@bigint.BigInt::from_int(1))),
      ("id", @ion_model.IonValue::Int(@bigint.BigInt::from_int(2))),
      ("name", @ion_model.IonValue::String("Ada")),
    ]),
  )
  assert_true(
    match duplicate {
      @generated.ConversionError::DuplicateField(path~) => path == "Person.id"
      _ => false
    },
  )

  let unknown = expect_person_error(
    make_fixture_struct([
      ("id", @ion_model.IonValue::Int(@bigint.BigInt::from_int(1))),
      ("name", @ion_model.IonValue::String("Ada")),
      ("extra", @ion_model.IonValue::Bool(true)),
    ]),
  )
  assert_true(
    match unknown {
      @generated.ConversionError::UnknownField(path~) => path == "Person.extra"
      _ => false
    },
  )

  let unknown_symbol = @ion_model.IonValue::Struct([
    (@ion_model.IonSymbol::from_sid(42), @ion_model.IonValue::String("x")),
  ])
  let unresolved = expect_person_error(unknown_symbol)
  assert_true(
    match unresolved {
      @generated.ConversionError::UnknownSymbol(path~, sid~) =>
        path == "Person.<field>" && sid == 42
      _ => false
    },
  )
}

///|
test "conversion reports root type scalar type and typed null errors" {
  let wrong_root = expect_person_error(@ion_model.IonValue::List([]))
  assert_true(
    match wrong_root {
      @generated.ConversionError::TypeMismatch(path~, expected~, actual~) =>
        path == "Person" && expected == "struct" && actual == "list"
      _ => false
    },
  )

  let wrong_scalar = expect_person_error(
    make_fixture_struct([
      ("id", @ion_model.IonValue::String("one")),
      ("name", @ion_model.IonValue::String("Ada")),
    ]),
  )
  assert_true(
    match wrong_scalar {
      @generated.ConversionError::TypeMismatch(path~, expected~, actual~) =>
        path == "Person.id" && expected == "int" && actual == "string"
      _ => false
    },
  )

  let typed_null = expect_person_error(
    make_fixture_struct([
      ("id", @ion_model.IonValue::null(kind=@ion_model.IonNull::Int)),
      ("name", @ion_model.IonValue::String("Ada")),
    ]),
  )
  assert_true(
    match typed_null {
      @generated.ConversionError::NullNotAllowed(path~) => path == "Person.id"
      _ => false
    },
  )
}

///|
test "conversion rejects annotations that typed fields cannot retain" {
  let annotation = [@ion_model.IonSymbol::from_text("meta")][:]
  let annotated_root = expect_person_error(
    full_person_value().with_annotations(annotation),
  )
  assert_true(
    match annotated_root {
      @generated.ConversionError::AnnotatedValueNotSupported(path~) =>
        path == "Person"
      _ => false
    },
  )

  let annotated_id = @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)).with_annotations(
    annotation,
  )
  let annotated_field = expect_person_error(
    make_fixture_struct([
      ("id", annotated_id),
      ("name", @ion_model.IonValue::String("Ada")),
    ]),
  )
  assert_true(
    match annotated_field {
      @generated.ConversionError::AnnotatedValueNotSupported(path~) =>
        path == "Person.id"
      _ => false
    },
  )
}
