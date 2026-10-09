///|
fn integer(value : Int) -> @ion_model.IonValue {
  @ion_model.IonValue::Int(@bigint.BigInt::from_int(value))
}

///|
fn any_of_error(
  validate : (@ion_model.IonValue) -> Unit raise @any_of.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    validate(value)
    ("", "")
  } catch {
    @any_of.ConversionError::InvalidValue(path~, constraint~, ..) =>
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
test "any_of accepts the first matching branch and handles overlaps" {
  @any_of.validate_type_NumberOrText(integer(7))
  @any_of.validate_type_NumberOrText(@ion_model.IonValue::String("ion"))
  @any_of.validate_type_SignedSmall(integer(4))
  @any_of.validate_type_SignedSmall(integer(-4))
  @any_of.validate_type_Overlapping(integer(4))
  assert_eq(
    any_of_error(
      @any_of.validate_type_NumberOrText,
      @ion_model.IonValue::Bool(true),
    ),
    ("NumberOrText", "any_of"),
  )
  assert_eq(
    any_of_error(@any_of.validate_type_SignedSmall, integer(20)),
    ("SignedSmall", "any_of"),
  )
}

///|
test "any_of matches inline scalar definitions" {
  @any_of.validate_type_InlineNumberOrText(integer(2))
  @any_of.validate_type_InlineNumberOrText(@ion_model.IonValue::String("ion"))
  assert_eq(
    any_of_error(@any_of.validate_type_InlineNumberOrText, integer(3)),
    ("InlineNumberOrText", "any_of"),
  )
}

///|
test "inline scalar matcher executes its regular expression constraints" {
  @any_of.validate_type_InlinePatternOrInt(@ion_model.IonValue::String("ion"))
  assert_eq(
    any_of_error(
      @any_of.validate_type_InlinePatternOrInt,
      @ion_model.IonValue::String("ocean"),
    ),
    ("InlinePatternOrInt", "any_of"),
  )
}

///|
test "any_of nullable branch admits plain null and rejects typed null" {
  @any_of.validate_type_MaybeInt(
    @ion_model.IonValue::null(kind=@ion_model.IonNull::Null),
  )
  @any_of.validate_type_MaybeInt(integer(3))
  assert_eq(
    any_of_error(
      @any_of.validate_type_MaybeInt,
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Int),
    ),
    ("MaybeInt", "any_of"),
  )
}

///|
test "any_of propagates through aliases fields and lists with paths" {
  try {
    ignore(
      @any_of.ChoiceRecord::from_ion(
        @ion_model.IonValue::Struct([
          field("value", @ion_model.IonValue::Bool(true)),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @any_of.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "ChoiceRecord.value")
      assert_eq(constraint, "any_of")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  try {
    ignore(
      @any_of.from_ion_ChoiceList(
        @ion_model.IonValue::List([@ion_model.IonValue::Bool(true)]),
      ),
    )
    assert_true(false)
  } catch {
    @any_of.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "ChoiceList[0]")
      assert_eq(constraint, "any_of")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
