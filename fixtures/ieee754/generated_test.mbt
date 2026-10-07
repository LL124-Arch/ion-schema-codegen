///|
fn float_constraint_error(
  validate : (@ion_model.IonValue) -> Unit raise @ieee754.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    validate(value)
    ("", "")
  } catch {
    @ieee754.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
test "binary16 checks exact normal, subnormal, overflow, and special values" {
  @ieee754.validate_ieee754_float_HalfFloat(@ion_model.IonValue::Float(65504.0))
  @ieee754.validate_ieee754_float_HalfFloat(
    @ion_model.IonValue::Float(0.00006103515625),
  )
  @ieee754.validate_ieee754_float_HalfFloat(
    @ion_model.IonValue::Float(0.000000059604645),
  )
  @ieee754.validate_ieee754_float_HalfFloat(@ion_model.IonValue::Float(-0.0))
  @ieee754.validate_ieee754_float_HalfFloat(
    @ion_model.IonValue::Float(0.0 / 0.0),
  )
  @ieee754.validate_ieee754_float_HalfFloat(
    @ion_model.IonValue::Float(1.0 / 0.0),
  )
  @ieee754.validate_ieee754_float_HalfFloat(
    @ion_model.IonValue::Float(-1.0 / 0.0),
  )

  assert_eq(
    float_constraint_error(
      @ieee754.validate_ieee754_float_HalfFloat,
      @ion_model.IonValue::Float(0.1),
    ),
    ("HalfFloat", "ieee754_float"),
  )
  assert_eq(
    float_constraint_error(
      @ieee754.validate_ieee754_float_HalfFloat,
      @ion_model.IonValue::Float(0.000000029802322),
    ),
    ("HalfFloat", "ieee754_float"),
  )
  assert_eq(
    float_constraint_error(
      @ieee754.validate_ieee754_float_HalfFloat,
      @ion_model.IonValue::Float(65520.0),
    ),
    ("HalfFloat", "ieee754_float"),
  )
}

///|
test "IEEE format constraints apply through aliases, fields, and list items" {
  @ieee754.validate_ieee754_float_SingleFloat(@ion_model.IonValue::Float(0.1))
  @ieee754.validate_ieee754_float_DoubleFloat(
    @ion_model.IonValue::Float(65520.0),
  )
  @ieee754.validate_ieee754_float_HalfFloatAlias(
    @ion_model.IonValue::Float(1.5),
  )

  assert_eq(
    float_constraint_error(
      @ieee754.validate_ieee754_float_HalfFloatAlias,
      @ion_model.IonValue::Float(0.1),
    ),
    ("HalfFloatAlias", "ieee754_float"),
  )

  try {
    ignore(
      @ieee754.FloatRecord::from_ion(
        @ion_model.IonValue::Struct([
          (
            @ion_model.IonSymbol::from_text("measurement"),
            @ion_model.IonValue::Float(0.1),
          ),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @ieee754.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "FloatRecord.measurement")
      assert_eq(constraint, "ieee754_float")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }

  try {
    ignore(
      @ieee754.from_ion_FloatArray(
        @ion_model.IonValue::List([@ion_model.IonValue::Float(0.1)]),
      ),
    )
    assert_true(false)
  } catch {
    @ieee754.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "FloatArray[0]")
      assert_eq(constraint, "ieee754_float")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
