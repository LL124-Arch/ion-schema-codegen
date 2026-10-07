///|
fn int_value(value : Int) -> @ion_model.IonValue {
  @ion_model.IonValue::Int(@bigint.BigInt::from_int(value))
}

///|
fn unique_values_error(value : @ion_model.IonValue) -> (String, String) {
  try {
    ignore(@constraints.from_ion_UniqueValues(value))
    ("", "")
  } catch {
    @constraints.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn unique_ints_error(value : @ion_model.IonValue) -> (String, String) {
  try {
    ignore(@constraints.from_ion_UniqueInts(value))
    ("", "")
  } catch {
    @constraints.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn nullable_unique_values_error(
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    ignore(@constraints.from_ion_NullableUniqueValues(value))
    ("", "")
  } catch {
    @constraints.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn unique_record_error(value : @ion_model.IonValue) -> (String, String) {
  try {
    ignore(@constraints.UniqueRecord::from_ion(value))
    ("", "")
  } catch {
    @constraints.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn unique_expression_error(value : @ion_model.IonValue) -> (String, String) {
  try {
    ignore(@constraints.UniqueExpressionRecord::from_ion(value))
    ("", "")
  } catch {
    @constraints.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn unique_document_error(
  values : Array[@ion_model.IonValue],
) -> (String, String) {
  try {
    ignore(@constraints.from_ion_document_UniqueStream(values))
    ("", "")
  } catch {
    @constraints.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
test "distinct lists compare complete Ion values including annotations" {
  let duplicate_ints = unique_ints_error(
    @ion_model.IonValue::List([int_value(1), int_value(1)]),
  )
  assert_eq(duplicate_ints, ("UniqueInts[1]", "distinct::element"))

  let left = @ion_model.IonValue::Annotated(
    [@ion_model.IonSymbol::from_text("left")],
    int_value(1),
  )
  let right = @ion_model.IonValue::Annotated(
    [@ion_model.IonSymbol::from_text("right")],
    int_value(1),
  )
  let values = @constraints.from_ion_UniqueValues(
    @ion_model.IonValue::List([left, right]),
  )
  assert_eq(values.length(), 2)

  let duplicate = unique_values_error(@ion_model.IonValue::List([left, left]))
  assert_eq(duplicate, ("UniqueValues[1]", "distinct::element"))
}

///|
test "distinct nullable elements include nulls in uniqueness checks" {
  let null_value = @ion_model.IonValue::null(kind=@ion_model.IonNull::Null)
  let valid = @constraints.from_ion_NullableUniqueValues(
    @ion_model.IonValue::List([null_value, int_value(2)]),
  )
  assert_eq(valid.length(), 2)
  assert_eq(
    nullable_unique_values_error(
      @ion_model.IonValue::List([null_value, null_value]),
    ),
    ("NullableUniqueValues[1]", "distinct::element"),
  )
}

///|
test "distinct compares nested structs without relying on field order" {
  let first = @ion_model.IonValue::Struct([
    (@ion_model.IonSymbol::from_text("x"), int_value(1)),
    (@ion_model.IonSymbol::from_text("y"), int_value(2)),
  ])
  let second = @ion_model.IonValue::Struct([
    (@ion_model.IonSymbol::from_text("y"), int_value(2)),
    (@ion_model.IonSymbol::from_text("x"), int_value(1)),
  ])
  let duplicate = unique_values_error(
    @ion_model.IonValue::List([first, second]),
  )
  assert_eq(duplicate, ("UniqueValues[1]", "distinct::element"))
}

///|
test "distinct checks struct fields and named S-expression elements" {
  let repeated_fields = @ion_model.IonValue::Struct([
    (@ion_model.IonSymbol::from_text("first"), int_value(7)),
    (@ion_model.IonSymbol::from_text("second"), int_value(7)),
  ])
  assert_eq(
    unique_record_error(repeated_fields),
    ("UniqueRecord[1]", "distinct::element"),
  )

  let repeated_expression = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("expression"),
      @ion_model.IonValue::Sexp([int_value(3), int_value(3)]),
    ),
  ])
  assert_eq(
    unique_expression_error(repeated_expression),
    ("UniqueExpressionRecord.expression[1]", "distinct::element"),
  )
}

///|
test "distinct checks document stream values" {
  assert_eq(
    unique_document_error([int_value(4), int_value(4)]),
    ("UniqueStream[1]", "distinct::element"),
  )
}
