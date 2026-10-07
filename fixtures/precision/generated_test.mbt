///|
fn decimal_value(coefficient : Int, exponent : Int) -> @ion_model.IonValue {
  @ion_model.IonValue::Decimal(
    @ion_model.IonDecimal::new(
      coefficient=@bigint.BigInt::from_int(coefficient),
      exponent~,
    ),
  )
}

///|
fn decimal_constraint_error(
  validate : (@ion_model.IonValue) -> Unit raise @precision.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String, String) {
  try {
    validate(value)
    ("", "", "")
  } catch {
    @precision.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      (path, constraint, actual)
    _ => ("unexpected", "unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected", "unexpected")
  }
}

///|
fn precision_record_error(value : @ion_model.IonValue) -> (String, String) {
  try {
    ignore(@precision.PrecisionRecord::from_ion(value))
    ("", "")
  } catch {
    @precision.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn exponent_record_error(value : @ion_model.IonValue) -> (String, String) {
  try {
    ignore(@precision.ExponentRecord::from_ion(value))
    ("", "")
  } catch {
    @precision.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn ion_field(
  name : String,
  value : @ion_model.IonValue,
) -> (@ion_model.IonSymbol, @ion_model.IonValue) {
  (@ion_model.IonSymbol::from_text(name), value)
}

///|
test "precision measures unsigned coefficient digits and rejects null" {
  @precision.validate_decimal_constraints_PrecisionFour(
    decimal_value(-1234, -8),
  )
  @precision.validate_decimal_constraints_PrecisionFour(decimal_value(0, 0)) catch {
    @precision.ConversionError::InvalidValue(constraint~, actual~, ..) => {
      assert_eq(constraint, "precision")
      assert_eq(actual, "1")
    }
    _ => assert_true(false)
  }

  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_PrecisionFour,
      decimal_value(12345, -2),
    ),
    ("PrecisionFour", "precision", "5"),
  )

  let typed_null = @ion_model.IonValue::Null(@ion_model.IonNull::Decimal)
  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_NullablePrecision, typed_null,
    ),
    ("NullablePrecision", "precision", "null.decimal"),
  )
}

///|
test "precision ranges and aliases apply at nested field and list paths" {
  @precision.validate_decimal_constraints_PrecisionRange(decimal_value(12, -2))
  @precision.validate_decimal_constraints_AliasPrecision(decimal_value(1234, 0))
  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_PrecisionRange,
      decimal_value(1, 0),
    ),
    ("PrecisionRange", "precision", "1"),
  )
  assert_eq(
    precision_record_error(
      @ion_model.IonValue::Struct([
        ion_field("exact", decimal_value(12345, -1)),
        ion_field("values", @ion_model.IonValue::List([decimal_value(12, 0)])),
      ]),
    ),
    ("PrecisionRecord.exact", "precision"),
  )
  assert_eq(
    precision_record_error(
      @ion_model.IonValue::Struct([
        ion_field("exact", decimal_value(1234, -1)),
        ion_field("values", @ion_model.IonValue::List([decimal_value(1, 0)])),
      ]),
    ),
    ("PrecisionRecord.values.PrecisionValues[0]", "precision"),
  )
}

///|
test "exponent uses Decimal data model values and signed exclusive ranges" {
  @precision.validate_decimal_constraints_ExponentExact(decimal_value(123, -2))
  @precision.validate_decimal_constraints_ExponentRange(decimal_value(123, -3))
  @precision.validate_decimal_constraints_BaseExponent(decimal_value(1, -3))
  @precision.validate_decimal_constraints_BaseExponent(decimal_value(1, -1))
  @precision.validate_decimal_constraints_AliasExponent(decimal_value(123, -2))

  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_ExponentExact,
      decimal_value(123, -1),
    ),
    ("ExponentExact", "exponent", "-1"),
  )
  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_ExponentRange,
      decimal_value(123, -1),
    ),
    ("ExponentRange", "exponent", "-1"),
  )
  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_BaseExponent,
      decimal_value(1, -4),
    ),
    ("BaseExponent", "exponent", "-4"),
  )
  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_BaseExponent,
      decimal_value(1, 0),
    ),
    ("BaseExponent", "exponent", "0"),
  )

  let typed_null = @ion_model.IonValue::Null(@ion_model.IonNull::Decimal)
  assert_eq(
    decimal_constraint_error(
      @precision.validate_decimal_constraints_NullableExponent, typed_null,
    ),
    ("NullableExponent", "exponent", "null.decimal"),
  )
}

///|
test "exponent aliases validate nested struct fields and list elements" {
  assert_eq(
    exponent_record_error(
      @ion_model.IonValue::Struct([
        ion_field("exact", decimal_value(123, -1)),
        ion_field("values", @ion_model.IonValue::List([decimal_value(1, -2)])),
      ]),
    ),
    ("ExponentRecord.exact", "exponent"),
  )
  assert_eq(
    exponent_record_error(
      @ion_model.IonValue::Struct([
        ion_field("exact", decimal_value(123, -2)),
        ion_field("values", @ion_model.IonValue::List([decimal_value(1, 1)])),
      ]),
    ),
    ("ExponentRecord.values.ExponentValues[0]", "exponent"),
  )
}
