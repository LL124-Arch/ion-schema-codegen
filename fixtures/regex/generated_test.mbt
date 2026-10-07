///|
fn regex_error(
  validate : (@ion_model.IonValue) -> Unit raise @regex.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    validate(value)
    ("", "")
  } catch {
    @regex.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
test "regex supports strings, symbols, case-insensitive and multiline matching" {
  @regex.validate_regex_Digits(@ion_model.IonValue::String("id=42"))
  @regex.validate_regex_CaseInsensitive(
    @ion_model.IonValue::String("ION schema"),
  )
  @regex.validate_regex_MultilineValue(
    @ion_model.IonValue::String("begin\nvalue\nend"),
  )
  @regex.validate_regex_DotWithoutLineBreak(@ion_model.IonValue::String("a-b"))
  @regex.validate_regex_SymbolCode(
    @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("MoonBit")),
  )
  @regex.validate_regex_DigitAlias(@ion_model.IonValue::String("42"))

  assert_eq(
    regex_error(
      @regex.validate_regex_AnchoredDigits,
      @ion_model.IonValue::String("x42x"),
    ),
    ("AnchoredDigits", "regex"),
  )
  assert_eq(
    regex_error(
      @regex.validate_regex_CaseInsensitive,
      @ion_model.IonValue::String("schema"),
    ),
    ("CaseInsensitive", "regex"),
  )
  assert_eq(
    regex_error(
      @regex.validate_regex_MultilineValue,
      @ion_model.IonValue::String("prefix value suffix"),
    ),
    ("MultilineValue", "regex"),
  )
  assert_eq(
    regex_error(
      @regex.validate_regex_DotWithoutLineBreak,
      @ion_model.IonValue::String("a\nb"),
    ),
    ("DotWithoutLineBreak", "regex"),
  )
  assert_eq(
    regex_error(
      @regex.validate_regex_SymbolCode,
      @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text("123")),
    ),
    ("SymbolCode", "regex"),
  )
}

///|
test "regex constraints follow named types into records and lists" {
  try {
    ignore(
      @regex.RegexRecord::from_ion(
        @ion_model.IonValue::Struct([
          (
            @ion_model.IonSymbol::from_text("code"),
            @ion_model.IonValue::String("12x"),
          ),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @regex.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "RegexRecord.code")
      assert_eq(constraint, "regex")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }

  try {
    ignore(
      @regex.from_ion_RegexArray(
        @ion_model.IonValue::List([@ion_model.IonValue::String("12x")]),
      ),
    )
    assert_true(false)
  } catch {
    @regex.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "RegexArray[0]")
      assert_eq(constraint, "regex")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
