///|
fn not_error(
  validate : (@ion_model.IonValue) -> Unit raise @not.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    validate(value)
    ("", "")
  } catch {
    @not.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
test "not rejects matching built-in and named types" {
  @not.validate_type_NotNumber(@ion_model.IonValue::String("ion"))
  @not.validate_type_NotNamedChoice(@ion_model.IonValue::Bool(true))
  assert_eq(
    not_error(@not.validate_type_NotNumber, @ion_model.IonValue::Float(2.5)),
    ("NotNumber", "not"),
  )
  assert_eq(
    not_error(
      @not.validate_type_NotNamedChoice,
      @ion_model.IonValue::String("ion"),
    ),
    ("NotNamedChoice", "not"),
  )
}

///|
test "not nullable argument includes plain null" {
  @not.validate_type_NotNullableInt(@ion_model.IonValue::String("ion"))
  @not.validate_type_NotNullableInt(
    @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
  )
  assert_eq(
    not_error(
      @not.validate_type_NotNullableInt,
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Null),
    ),
    ("NotNullableInt", "not"),
  )
}

///|
test "not propagates through aliases fields and lists with paths" {
  try {
    ignore(
      @not.NotNumberRecord::from_ion(
        @ion_model.IonValue::Struct([
          (
            @ion_model.IonSymbol::from_text("value"),
            @ion_model.IonValue::Float(2.5),
          ),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @not.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "NotNumberRecord.value")
      assert_eq(constraint, "not")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  try {
    ignore(
      @not.from_ion_NotNumberList(
        @ion_model.IonValue::List([@ion_model.IonValue::Float(2.5)]),
      ),
    )
    assert_true(false)
  } catch {
    @not.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "NotNumberList[0]")
      assert_eq(constraint, "not")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
