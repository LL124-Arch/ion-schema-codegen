///|
fn floating(value : Float) -> @ion_model.IonValue {
  @ion_model.IonValue::Float(value)
}

///|
fn one_of_error(
  validate : (@ion_model.IonValue) -> Unit raise @one_of.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    validate(value)
    ("", "")
  } catch {
    @one_of.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn field(
  name : String,
  value : @ion_model.IonValue,
) -> (@ion_model.IonSymbol, @ion_model.IonValue) {
  (@ion_model.IonSymbol::from_text(name), value)
}

///|
test "one_of requires exactly one matching branch" {
  @one_of.validate_type_IntegerOrText(@ion_model.IonValue::String("ion"))
  assert_eq(
    one_of_error(
      @one_of.validate_type_IntegerOrText,
      @ion_model.IonValue::Bool(true),
    ),
    ("IntegerOrText", "one_of"),
  )
  assert_eq(
    one_of_error(@one_of.validate_type_OverlappingNumeric, floating(1.5)),
    ("OverlappingNumeric", "one_of"),
  )
  assert_eq(
    one_of_error(@one_of.validate_type_RepeatedFloat, floating(1.5)),
    ("RepeatedFloat", "one_of"),
  )
}

///|
test "one_of counts nullable branch overlap and typed null" {
  @one_of.validate_type_NullableOverlap(floating(4.0))
  @one_of.validate_type_NullableTypedInt(
    @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
  )
  assert_eq(
    one_of_error(
      @one_of.validate_type_NullableOverlap,
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Null),
    ),
    ("NullableOverlap", "one_of"),
  )
}

///|
test "one_of propagates through aliases fields and lists with paths" {
  try {
    ignore(
      @one_of.ChoiceRecord::from_ion(
        @ion_model.IonValue::Struct([
          field("value", @ion_model.IonValue::Bool(true)),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @one_of.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "ChoiceRecord.value")
      assert_eq(constraint, "one_of")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  try {
    ignore(
      @one_of.from_ion_ChoiceList(
        @ion_model.IonValue::List([@ion_model.IonValue::Bool(true)]),
      ),
    )
    assert_true(false)
  } catch {
    @one_of.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "ChoiceList[0]")
      assert_eq(constraint, "one_of")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
