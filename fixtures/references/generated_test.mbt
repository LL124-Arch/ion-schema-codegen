///|
fn make_address(city : String) -> @references.Address {
  { city: Some(city), }
}

///|
fn expect_person_error(
  value : @ion_model.IonValue,
) -> @references.ConversionError {
  try @references.Person::from_ion(value) catch {
    error => error
  } noraise {
    _ =>
      @references.ConversionError::TypeMismatch(
        path="test",
        expected="error",
        actual="conversion succeeded",
      )
  }
}

///|
test "nested named structs and scalar lists round trip" {
  let person : @references.Person = {
    primary: make_address("New York"),
    addresses: [make_address("New York"), make_address("London")],
    scores: [
      @bigint.BigInt::from_int(7),
      @bigint.BigInt::from_int(42),
      @bigint.BigInt::from_int(99),
    ],
    nickname: Some("Ada"),
  }
  let encoded = @references.Person::to_ion(person)
  let decoded = @references.Person::from_ion(encoded)
  assert_eq(@references.Person::to_ion(decoded), encoded)
}

///|
test "empty and single element lists convert" {
  let empty : @references.Person = {
    primary: make_address("Oslo"),
    addresses: [],
    scores: [],
    nickname: None,
  }
  let empty_ion = @references.Person::to_ion(empty)
  let decoded_empty = @references.Person::from_ion(empty_ion)
  assert_eq(decoded_empty.addresses.length(), 0)
  assert_eq(decoded_empty.scores.length(), 0)

  let single : @references.Person = {
    primary: make_address("Tokyo"),
    addresses: [make_address("Tokyo")],
    scores: [@bigint.BigInt::from_int(1)],
    nickname: None,
  }
  let decoded_single = @references.Person::from_ion(
    @references.Person::to_ion(single),
  )
  assert_eq(decoded_single.addresses.length(), 1)
  assert_eq(decoded_single.scores.length(), 1)
}

///|
test "list element errors report their index and expected Ion type" {
  let invalid_scores = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("primary"),
      @references.Address::to_ion(make_address("Paris")),
    ),
    (
      @ion_model.IonSymbol::from_text("addresses"),
      @ion_model.IonValue::List([]),
    ),
    (
      @ion_model.IonSymbol::from_text("scores"),
      @ion_model.IonValue::List([
        @ion_model.IonValue::Int(@bigint.BigInt::from_int(5)),
        @ion_model.IonValue::String("wrong"),
      ]),
    ),
  ])
  match expect_person_error(invalid_scores) {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) => {
      assert_eq(path, "Person.scores.Scores[1]")
      assert_eq(expected, "int")
      assert_eq(actual, "string")
    }
    _ => fail("expected an indexed list element type mismatch")
  }
}

///|
test "named list converters reject the wrong container type" {
  let error = try
    @references.from_ion_Scores(@ion_model.IonValue::Sexp([]))
  catch {
    error => error
  } noraise {
    _ =>
      @references.ConversionError::TypeMismatch(
        path="test",
        expected="error",
        actual="conversion succeeded",
      )
  }
  match error {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) => {
      assert_eq(path, "Scores")
      assert_eq(expected, "list")
      assert_eq(actual, "sexp")
    }
    _ => fail("expected a list container type mismatch")
  }
}

///|
test "nested named element errors retain the parent field and list index" {
  let invalid_addresses = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("primary"),
      @references.Address::to_ion(make_address("Rome")),
    ),
    (
      @ion_model.IonSymbol::from_text("addresses"),
      @ion_model.IonValue::List([@ion_model.IonValue::String("wrong")]),
    ),
    (@ion_model.IonSymbol::from_text("scores"), @ion_model.IonValue::List([])),
  ])
  match expect_person_error(invalid_addresses) {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) => {
      assert_eq(path, "Person.addresses.AddressList[0].Address")
      assert_eq(expected, "struct")
      assert_eq(actual, "string")
    }
    _ => fail("expected a nested indexed type mismatch")
  }
}

///|
test "S-expression fields and list elements round trip nested Ion values" {
  let expression : @references.Expression = [
    @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("add")),
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(10)),
    @ion_model.IonValue::List([
      @ion_model.IonValue::String("nested"),
      @ion_model.IonValue::Sexp([@ion_model.IonValue::Bool(true)]),
    ]),
  ]
  let record : @references.ExpressionRecord = { expression, }
  let encoded_record = @references.ExpressionRecord::to_ion(record)
  let decoded_record = @references.ExpressionRecord::from_ion(encoded_record)
  assert_eq(decoded_record.expression, expression)
  assert_eq(
    @references.ExpressionRecord::to_ion(decoded_record),
    encoded_record,
  )

  let expressions : @references.Expressions = [[], expression]
  let encoded_expressions = @references.to_ion_Expressions(expressions)
  let decoded_expressions = @references.from_ion_Expressions(
    encoded_expressions,
  )
  assert_eq(decoded_expressions, expressions)
  assert_eq(
    @references.to_ion_Expressions(decoded_expressions),
    encoded_expressions,
  )
}

///|
test "S-expression list elements report mismatched Ion container types" {
  let error = try
    @references.from_ion_Expressions(
      @ion_model.IonValue::List([@ion_model.IonValue::List([])]),
    )
  catch {
    error => error
  } noraise {
    _ =>
      @references.ConversionError::TypeMismatch(
        path="test",
        expected="error",
        actual="conversion succeeded",
      )
  }
  match error {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) => {
      assert_eq(path, "Expressions[0]")
      assert_eq(expected, "sexp")
      assert_eq(actual, "list")
    }
    _ => fail("expected an S-expression type mismatch")
  }
}
