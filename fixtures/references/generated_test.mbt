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
fn expect_nullable_nominals_error(
  value : @ion_model.IonValue,
) -> @references.ConversionError {
  try @references.NullableNominals::from_ion(value) catch {
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
fn expect_maybe_numbers_error(
  value : @ion_model.IonValue,
) -> @references.ConversionError {
  try @references.from_ion_MaybeNumbers(value) catch {
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

///|
fn expect_any_record_error(
  value : @ion_model.IonValue,
) -> @references.ConversionError {
  try @references.AnyRecord::from_ion(value) catch {
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
test "any fields and lists preserve arbitrary Ion values and annotations" {
  let metadata = [@ion_model.IonSymbol::from_text("meta")][:]
  let annotated = @ion_model.IonValue::List([
    @ion_model.IonValue::String("kept"),
    @ion_model.IonValue::Sexp([@ion_model.IonValue::Bool(true)]),
  ]).with_annotations(metadata)
  let raw = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("nested"),
      @ion_model.IonValue::Decimal(
        @ion_model.IonDecimal::new(
          coefficient=@bigint.BigInt::from_int(123),
          exponent=-2,
        ),
      ),
    ),
  ])
  let record : @references.AnyRecord = {
    named_value: annotated,
    raw,
    optional_raw: Some(annotated),
  }
  let encoded_record = @references.AnyRecord::to_ion(record)
  let decoded_record = @references.AnyRecord::from_ion(encoded_record)
  assert_eq(decoded_record.named_value, annotated)
  assert_eq(decoded_record.raw, raw)
  assert_eq(decoded_record.optional_raw, Some(annotated))
  assert_eq(@references.AnyRecord::to_ion(decoded_record), encoded_record)

  let values : @references.AnyValues = [annotated, raw]
  let encoded_values = @references.to_ion_AnyValues(values)
  let decoded_values = @references.from_ion_AnyValues(encoded_values)
  assert_eq(decoded_values, values)
  assert_eq(@references.to_ion_AnyValues(decoded_values), encoded_values)
}

///|
test "any rejects plain and typed null with field and index paths" {
  let field_error = expect_any_record_error(
    @ion_model.IonValue::Struct([
      (
        @ion_model.IonSymbol::from_text("named_value"),
        @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
      ),
      (
        @ion_model.IonSymbol::from_text("raw"),
        @ion_model.IonValue::null(kind=@ion_model.IonNull::String),
      ),
    ]),
  )
  assert_true(
    match field_error {
      @references.ConversionError::NullNotAllowed(path~) =>
        path == "AnyRecord.raw"
      _ => false
    },
  )

  let list_error = try
    @references.from_ion_AnyValues(
      @ion_model.IonValue::List([
        @ion_model.IonValue::Bool(false),
        @ion_model.IonValue::Null(@ion_model.IonNull::Null),
      ]),
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
  assert_true(
    match list_error {
      @references.ConversionError::NullNotAllowed(path~) =>
        path == "AnyValues[1]"
      _ => false
    },
  )
}

///|
test "$any preserves plain typed and annotated null values" {
  let annotation = [@ion_model.IonSymbol::from_text("meta")][:]
  let plain_null = @ion_model.IonValue::Null(@ion_model.IonNull::Null)
  let typed_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::Int)
  let annotated_null = typed_null.with_annotations(annotation)
  let record : @references.NullableRecord = {
    value: annotated_null,
    optional: Some(plain_null),
  }
  let encoded_record = @references.NullableRecord::to_ion(record)
  let decoded_record = @references.NullableRecord::from_ion(encoded_record)
  assert_eq(decoded_record.value, annotated_null)
  assert_eq(decoded_record.optional, Some(plain_null))
  assert_eq(@references.NullableRecord::to_ion(decoded_record), encoded_record)

  let values : @references.NullableValues = [
    plain_null,
    typed_null,
    annotated_null,
    @ion_model.IonValue::String("non-null"),
  ]
  let encoded_values = @references.to_ion_NullableValues(values)
  let decoded_values = @references.from_ion_NullableValues(encoded_values)
  assert_eq(decoded_values, values)
  assert_eq(@references.to_ion_NullableValues(decoded_values), encoded_values)
}

///|
test "document stream aliases preserve multiple top-level Ion values" {
  let values = [
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
    @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    @ion_model.IonValue::Struct([
      (
        @ion_model.IonSymbol::from_text("nested"),
        @ion_model.IonValue::List([
          @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
          @ion_model.IonValue::Int(@bigint.BigInt::from_int(3)),
        ]),
      ),
    ]),
  ]
  let document = @references.from_ion_document_EventStream(values)
  let aliased = @references.from_ion_document_EventStreamAlias(document)
  let decoded = @references.to_ion_document_EventStreamAlias(aliased)
  assert_eq(decoded, values)

  let empty : @references.EventStream = []
  assert_eq(@references.to_ion_document_EventStream(empty), [])
}

///|
test "nullable nominal types and null-or values preserve each null kind" {
  let input = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("typed_int"),
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    ),
    (
      @ion_model.IonSymbol::from_text("plain_null"),
      @ion_model.IonValue::Null(@ion_model.IonNull::Null),
    ),
    (
      @ion_model.IonSymbol::from_text("maybe_text"),
      @ion_model.IonValue::Null(@ion_model.IonNull::Null),
    ),
    (
      @ion_model.IonSymbol::from_text("maybe_typed_int"),
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    ),
    (
      @ion_model.IonSymbol::from_text("optional_boolean"),
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Bool),
    ),
  ])
  let decoded = @references.NullableNominals::from_ion(input)
  assert_eq(@references.NullableNominals::to_ion(decoded), input)

  let nullable_ints = @references.from_ion_NullableInts(
    @ion_model.IonValue::List([
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(4)),
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    ]),
  )
  assert_eq(nullable_ints.length(), 2)
  assert_eq(
    @references.to_ion_NullableInts(nullable_ints),
    @ion_model.IonValue::List([
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(4)),
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    ]),
  )

  let wrong_nullable_kind = expect_nullable_nominals_error(
    @ion_model.IonValue::Struct([
      (
        @ion_model.IonSymbol::from_text("typed_int"),
        @ion_model.IonValue::null(kind=@ion_model.IonNull::String),
      ),
    ]),
  )
  assert_true(
    match wrong_nullable_kind {
      @references.ConversionError::TypeMismatch(path~, expected~, actual~) =>
        path == "NullableNominals.typed_int" &&
        expected == "$int" &&
        actual == "null.string"
      _ => false
    },
  )

  let maybe_numbers = @references.from_ion_MaybeNumbers(
    @ion_model.IonValue::List([
      @ion_model.IonValue::Null(@ion_model.IonNull::Null),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(7)),
    ]),
  )
  assert_eq(maybe_numbers.length(), 2)
  assert_eq(
    @references.to_ion_MaybeNumbers(maybe_numbers),
    @ion_model.IonValue::List([
      @ion_model.IonValue::Null(@ion_model.IonNull::Null),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(7)),
    ]),
  )

  let wrong_list_null = expect_maybe_numbers_error(
    @ion_model.IonValue::List([
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    ]),
  )
  assert_true(
    match wrong_list_null {
      @references.ConversionError::TypeMismatch(path~, expected~, actual~) =>
        path == "MaybeNumbers[0]" && expected == "int" && actual == "null.int"
      _ => false
    },
  )
}

///|
test "field occurs counts preserve duplicates and enforce bounds" {
  let input = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("fixed"),
      @ion_model.IonValue::String("first"),
    ),
    (
      @ion_model.IonSymbol::from_text("fixed"),
      @ion_model.IonValue::String("second"),
    ),
    (
      @ion_model.IonSymbol::from_text("bounded"),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(3)),
    ),
    (
      @ion_model.IonSymbol::from_text("bounded"),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(4)),
    ),
    (
      @ion_model.IonSymbol::from_text("optional_name"),
      @ion_model.IonValue::String("label"),
    ),
    (
      @ion_model.IonSymbol::from_text("at_least_one"),
      @ion_model.IonValue::Bool(true),
    ),
  ])
  let decoded = @references.OccurrenceRecord::from_ion(input)
  assert_eq(decoded.fixed, ["first", "second"])
  assert_eq(decoded.bounded.length(), 2)
  assert_eq(decoded.optional_name, Some("label"))
  assert_eq(decoded.at_least_one, [true])
  assert_eq(@references.OccurrenceRecord::to_ion(decoded), input)

  let too_few = try {
    let _ = @references.OccurrenceRecord::from_ion(
      @ion_model.IonValue::Struct([
        (
          @ion_model.IonSymbol::from_text("fixed"),
          @ion_model.IonValue::String("only one"),
        ),
      ]),
    )
    None
  } catch {
    @references.ConversionError::FieldOccurrenceMismatch(
      path~,
      expected~,
      actual~
    ) => Some((path, expected, actual))
    _ => None
  }
  assert_eq(too_few, Some(("OccurrenceRecord.fixed", "2", 1)))
}

///|
test "open structs preserve duplicate and unresolved unknown fields" {
  let unresolved_name = @ion_model.IonSymbol::from_sid(42)
  let input = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("extra"),
      @ion_model.IonValue::String("before known"),
    ),
    (
      @ion_model.IonSymbol::from_text("known"),
      @ion_model.IonValue::String("value"),
    ),
    (
      @ion_model.IonSymbol::from_text("extra"),
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    ),
    (
      unresolved_name,
      @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_sid(77)),
    ),
  ])
  let decoded = @references.OpenRecord::from_ion(input)
  assert_eq(decoded.known, "value")
  assert_eq(decoded.ion_schema_codegen_open_content.length(), 3)
  assert_eq(
    @references.OpenRecord::to_ion(decoded),
    @ion_model.IonValue::Struct([
      (
        @ion_model.IonSymbol::from_text("known"),
        @ion_model.IonValue::String("value"),
      ),
      (
        @ion_model.IonSymbol::from_text("extra"),
        @ion_model.IonValue::String("before known"),
      ),
      (
        @ion_model.IonSymbol::from_text("extra"),
        @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
      ),
      (
        @ion_model.IonSymbol::from_sid(42),
        @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_sid(77)),
      ),
    ]),
  )
}

///|
test "container_length validates list struct sexp and document values" {
  let list = @references.from_ion_SizedList(
    @ion_model.IonValue::List([
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
    ]),
  )
  assert_eq(list, [@bigint.BigInt::from_int(1), @bigint.BigInt::from_int(2)])
  assert_eq(
    @references.to_ion_SizedList(list),
    @ion_model.IonValue::List([
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
    ]),
  )

  let short_list = try {
    let _ = @references.from_ion_SizedList(@ion_model.IonValue::List([]))
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(short_list, Some(("SizedList", "container_length", "0")))

  let record = @references.SizedRecord::from_ion(
    @ion_model.IonValue::Struct([
      (
        @ion_model.IonSymbol::from_text("known"),
        @ion_model.IonValue::String("value"),
      ),
      (
        @ion_model.IonSymbol::from_text("extra"),
        @ion_model.IonValue::Bool(true),
      ),
    ]),
  )
  assert_eq(record.known, Some("value"))
  assert_eq(record.ion_schema_codegen_open_content.length(), 1)

  let oversized_record = try {
    let _ = @references.SizedRecord::from_ion(
      @ion_model.IonValue::Struct([
        (
          @ion_model.IonSymbol::from_text("known"),
          @ion_model.IonValue::String("value"),
        ),
        (
          @ion_model.IonSymbol::from_text("extra"),
          @ion_model.IonValue::Bool(true),
        ),
        (
          @ion_model.IonSymbol::from_text("extra"),
          @ion_model.IonValue::Bool(false),
        ),
        (
          @ion_model.IonSymbol::from_text("another"),
          @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
        ),
        (
          @ion_model.IonSymbol::from_text("last"),
          @ion_model.IonValue::String("extra"),
        ),
      ]),
    )
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(oversized_record, Some(("SizedRecord", "container_length", "5")))

  let null_list = try {
    let _ = @references.from_ion_SizedList(
      @ion_model.IonValue::null(kind=@ion_model.IonNull::List),
    )
    None
  } catch {
    @references.ConversionError::NullNotAllowed(path~) => Some(path)
    _ => None
  }
  assert_eq(null_list, Some("SizedList"))

  let expression = @references.SizedExpressionRecord::from_ion(
    @ion_model.IonValue::Struct([
      (
        @ion_model.IonSymbol::from_text("expression"),
        @ion_model.IonValue::Sexp([
          @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("add")),
          @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
        ]),
      ),
    ]),
  )
  assert_eq(expression.expression.length(), 2)

  let expression_error = try {
    let _ = @references.SizedExpressionRecord::from_ion(
      @ion_model.IonValue::Struct([
        (
          @ion_model.IonSymbol::from_text("expression"),
          @ion_model.IonValue::Sexp([@ion_model.IonValue::Bool(true)]),
        ),
      ]),
    )
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(
    expression_error,
    Some(("SizedExpressionRecord.expression", "container_length", "1")),
  )

  let document = @references.from_ion_document_SizedDocument([
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
    @ion_model.IonValue::String("two"),
  ])
  assert_eq(@references.to_ion_document_SizedDocument(document), [
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
    @ion_model.IonValue::String("two"),
  ])
  let short_document = try {
    let _ = @references.from_ion_document_SizedDocument([])
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(short_document, Some(("SizedDocument", "container_length", "0")))
}

///|
fn content_record_input(text : String, blob : Bytes) -> @ion_model.IonValue {
  @ion_model.IonValue::Struct([
    (@ion_model.IonSymbol::from_text("text"), @ion_model.IonValue::String(text)),
    (
      @ion_model.IonSymbol::from_text("symbol"),
      @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("猫")),
    ),
    (@ion_model.IonSymbol::from_text("blob"), @ion_model.IonValue::Blob(blob)),
    (
      @ion_model.IonSymbol::from_text("clob"),
      @ion_model.IonValue::Clob(Bytes::from_array([4, 5, 6, 7])),
    ),
  ])
}

///|
test "content length constraints count Unicode and LOB bytes" {
  let input = content_record_input("A🤣", Bytes::from_array([1, 2, 3]))
  let record = @references.ContentLengthRecord::from_ion(input)
  assert_eq(record.text, "A🤣")
  assert_eq(record.symbol.text_value(), Some("猫"))
  assert_eq(record.blob.length(), 3)
  assert_eq(record.clob.length(), 4)
  assert_eq(@references.ContentLengthRecord::to_ion(record), input)

  let short_text = try {
    let _ = @references.ContentLengthRecord::from_ion(
      content_record_input("A", Bytes::from_array([1, 2, 3])),
    )
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(
    short_text,
    Some(("ContentLengthRecord.text", "codepoint_length", "1")),
  )

  let short_utf8 = try {
    let _ = @references.ContentLengthRecord::from_ion(
      content_record_input("AA", Bytes::from_array([1, 2, 3])),
    )
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(
    short_utf8,
    Some(("ContentLengthRecord.text", "utf8_byte_length", "2")),
  )

  let short_blob = try {
    let _ = @references.ContentLengthRecord::from_ion(
      content_record_input("A🤣", Bytes::from_array([1])),
    )
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(short_blob, Some(("ContentLengthRecord.blob", "byte_length", "1")))
}

///|
test "element constraints validate S-expression values by position" {
  let input = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("expression"),
      @ion_model.IonValue::Sexp([
        @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
        @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
      ]),
    ),
  ])
  let record = @references.IntExpressionRecord::from_ion(input)
  assert_eq(record.expression.length(), 2)
  assert_eq(@references.IntExpressionRecord::to_ion(record), input)

  let invalid = try {
    let _ = @references.IntExpressionRecord::from_ion(
      @ion_model.IonValue::Struct([
        (
          @ion_model.IonSymbol::from_text("expression"),
          @ion_model.IonValue::Sexp([
            @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
            @ion_model.IonValue::Bool(true),
          ]),
        ),
      ]),
    )
    None
  } catch {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) =>
      Some((path, expected, actual))
    _ => None
  }
  assert_eq(invalid, Some(("IntExpressionRecord.expression[1]", "int", "bool")))
}

///|
test "struct element constraints include repeated and open fields" {
  let input = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("known"),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
    ),
    (
      @ion_model.IonSymbol::from_text("repeated"),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
    ),
    (
      @ion_model.IonSymbol::from_text("extra"),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(3)),
    ),
    (
      @ion_model.IonSymbol::from_text("extra"),
      @ion_model.IonValue::Int(@bigint.BigInt::from_int(4)),
    ),
  ])
  let record = @references.ElementRecord::from_ion(input)
  assert_eq(record.known, @bigint.BigInt::from_int(1))
  assert_eq(record.repeated.length(), 1)
  assert_eq(record.ion_schema_codegen_open_content.length(), 2)
  assert_eq(@references.ElementRecord::to_ion(record), input)

  let invalid = try {
    let _ = @references.ElementRecord::from_ion(
      @ion_model.IonValue::Struct([
        (
          @ion_model.IonSymbol::from_text("known"),
          @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
        ),
        (
          @ion_model.IonSymbol::from_text("extra"),
          @ion_model.IonValue::Bool(true),
        ),
      ]),
    )
    None
  } catch {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) =>
      Some((path, expected, actual))
    _ => None
  }
  assert_eq(invalid, Some(("ElementRecord.extra[1]", "int", "bool")))
}

///|
test "element-only structs preserve their open fields" {
  let input = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("first"),
      @ion_model.IonValue::String("one"),
    ),
    (
      @ion_model.IonSymbol::from_text("second"),
      @ion_model.IonValue::String("two"),
    ),
  ])
  let fields = @references.StringFields::from_ion(input)
  assert_eq(fields.ion_schema_codegen_open_content.length(), 2)
  assert_eq(@references.StringFields::to_ion(fields), input)

  let invalid = try {
    let _ = @references.StringFields::from_ion(
      @ion_model.IonValue::Struct([
        (
          @ion_model.IonSymbol::from_text("first"),
          @ion_model.IonValue::String("one"),
        ),
        (
          @ion_model.IonSymbol::from_text("second"),
          @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
        ),
      ]),
    )
    None
  } catch {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) =>
      Some((path, expected, actual))
    _ => None
  }
  assert_eq(invalid, Some(("StringFields.second[1]", "string", "int")))
}

///|
test "document element constraints validate each top-level value" {
  let values = [
    @ion_model.IonValue::String("one"),
    @ion_model.IonValue::String("two"),
  ]
  let document = @references.from_ion_document_TextDocument(values)
  assert_eq(@references.to_ion_document_TextDocument(document), values)
  let document_alias = @references.from_ion_document_TextDocumentAlias(values)
  assert_eq(
    @references.to_ion_document_TextDocumentAlias(document_alias),
    values,
  )

  let invalid = try {
    let _ = @references.from_ion_document_TextDocument([
      @ion_model.IonValue::String("one"),
      @ion_model.IonValue::Bool(true),
    ])
    None
  } catch {
    @references.ConversionError::TypeMismatch(path~, expected~, actual~) =>
      Some((path, expected, actual))
    _ => None
  }
  assert_eq(invalid, Some(("TextDocument[1]", "string", "bool")))

  let too_short = try {
    let _ = @references.from_ion_document_TextDocumentAlias([
      @ion_model.IonValue::String("one"),
    ])
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(too_short, Some(("TextDocumentAlias", "container_length", "1")))
}

///|
test "ordered_elements preserve heterogeneous list order and occurrences" {
  let minimum = @ion_model.IonValue::List([
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(7)),
    @ion_model.IonValue::Bool(true),
    @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("left")),
    @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("right")),
  ])
  let parsed_minimum = @references.from_ion_OrderedValues(minimum)
  assert_eq(@references.to_ion_OrderedValues(parsed_minimum), minimum)

  let maximum = @ion_model.IonValue::List([
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(7)),
    @ion_model.IonValue::String("optional"),
    @ion_model.IonValue::Bool(true),
    @ion_model.IonValue::Bool(false),
    @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("left")),
    @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("right")),
  ])
  let parsed_maximum = @references.from_ion_OrderedValues(maximum)
  assert_eq(@references.to_ion_OrderedValues(parsed_maximum), maximum)

  let alias_input = @ion_model.IonValue::List([
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
  ])
  let alias_values = @references.from_ion_OrderedAliasList(alias_input)
  assert_eq(@references.to_ion_OrderedAliasList(alias_values), alias_input)
  let backtracked = @ion_model.IonValue::List([
    @ion_model.IonValue::String("must satisfy the second position"),
  ])
  assert_eq(
    @references.to_ion_OrderedBacktrack(
      @references.from_ion_OrderedBacktrack(backtracked),
    ),
    backtracked,
  )

  let nullable = @ion_model.IonValue::List([
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(20)),
    @ion_model.IonValue::null(kind=@ion_model.IonNull::Null),
  ])
  assert_eq(
    @references.to_ion_OrderedNullableList(
      @references.from_ion_OrderedNullableList(nullable),
    ),
    nullable,
  )

  let invalid = try {
    let _ = @references.from_ion_OrderedValues(
      @ion_model.IonValue::List([
        @ion_model.IonValue::Int(@bigint.BigInt::from_int(7)),
        @ion_model.IonValue::Blob(Bytes::from_array([1])),
        @ion_model.IonValue::Bool(true),
        @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("left")),
        @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("right")),
      ]),
    )
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(invalid, Some(("OrderedValues[1]", "ordered_elements", "blob")))

  let missing = try {
    let _ = @references.from_ion_OrderedValues(@ion_model.IonValue::List([]))
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(
    missing,
    Some(("OrderedValues[0]", "ordered_elements", "sequence length 0")),
  )
}

///|
test "ordered_elements validate S-expression and document positions" {
  let expression = @ion_model.IonValue::Sexp([
    @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("op")),
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(1)),
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(2)),
  ])
  let expression_record = @references.OrderedExpressionRecord::from_ion(
    @ion_model.IonValue::Struct([
      (@ion_model.IonSymbol::from_text("expression"), expression),
    ]),
  )
  assert_eq(
    @references.OrderedExpressionRecord::to_ion(expression_record),
    @ion_model.IonValue::Struct([
      (@ion_model.IonSymbol::from_text("expression"), expression),
    ]),
  )

  let invalid_expression = try {
    let _ = @references.OrderedExpressionRecord::from_ion(
      @ion_model.IonValue::Struct([
        (
          @ion_model.IonSymbol::from_text("expression"),
          @ion_model.IonValue::Sexp([
            @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("op")),
            @ion_model.IonValue::Blob(Bytes::from_array([1])),
          ]),
        ),
      ]),
    )
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(
    invalid_expression,
    Some(("OrderedExpressionRecord.expression[1]", "ordered_elements", "blob")),
  )

  let document = [
    @ion_model.IonValue::String("header"),
    @ion_model.IonValue::Int(@bigint.BigInt::from_int(3)),
  ]
  let parsed_document = @references.from_ion_document_OrderedDocument(document)
  assert_eq(
    @references.to_ion_document_OrderedDocument(parsed_document),
    document,
  )
  let document_alias = @references.from_ion_document_OrderedDocumentAlias(
    document,
  )
  assert_eq(
    @references.to_ion_document_OrderedDocumentAlias(document_alias),
    document,
  )

  let invalid_document = try {
    let _ = @references.from_ion_document_OrderedDocument([
      @ion_model.IonValue::String("header"),
      @ion_model.IonValue::Bool(true),
    ])
    None
  } catch {
    @references.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      Some((path, constraint, actual))
    _ => None
  }
  assert_eq(
    invalid_document,
    Some(("OrderedDocument[1]", "ordered_elements", "bool")),
  )
}

///|
test "ordered_elements retain annotations and decimal precision" {
  let annotation = [@ion_model.IonSymbol::from_text("meta")][:]
  let annotated = @ion_model.IonValue::Int(@bigint.BigInt::from_int(9)).with_annotations(
    annotation,
  )
  let decimal = @ion_model.IonValue::Decimal(
    @ion_model.IonDecimal::new(
      coefficient=@bigint.BigInt::from_int(123),
      exponent=-2,
    ),
  )
  let input = @ion_model.IonValue::List([annotated, decimal])
  let values = @references.from_ion_OrderedIdentity(input)
  assert_eq(@references.to_ion_OrderedIdentity(values), input)
}

///|
test "element constraints accept nullable type arguments" {
  let input = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("expression"),
      @ion_model.IonValue::Sexp([
        @ion_model.IonValue::Int(@bigint.BigInt::from_int(4)),
        @ion_model.IonValue::null(kind=@ion_model.IonNull::Null),
      ]),
    ),
  ])
  let record = @references.NullableExpressionRecord::from_ion(input)
  assert_eq(record.expression.length(), 2)
  assert_eq(@references.NullableExpressionRecord::to_ion(record), input)
}
