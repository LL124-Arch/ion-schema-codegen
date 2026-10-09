///|
fn integer(value : Int) -> @ion_model.IonValue {
  @ion_model.IonValue::Int(@bigint.BigInt::from_int(value))
}

///|
fn all_of_error(
  validate : (@ion_model.IonValue) -> Unit raise @all_of.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    validate(value)
    ("", "")
  } catch {
    @all_of.ConversionError::InvalidValue(path~, constraint~, ..) =>
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
test "all_of intersects named types and defaults to raw IonValue" {
  assert_true(@all_of.is_valid_values_Positive(integer(7)))
  assert_true(@all_of.is_valid_values_BelowTen(integer(7)))
  @all_of.validate_Positive(integer(7))
  @all_of.validate_BelowTen(integer(7))
  @all_of.validate_type_PositiveBelowTen(integer(7))
  assert_eq(
    all_of_error(@all_of.validate_type_PositiveBelowTen, integer(12)),
    ("PositiveBelowTen", "all_of"),
  )
  assert_eq(
    all_of_error(@all_of.validate_type_PositiveBelowTen, integer(0)),
    ("PositiveBelowTen", "all_of"),
  )
}

///|
test "all_of accepts anonymous scalar definitions without exposing a type" {
  @all_of.validate_type_InlineEven(integer(2))
  @all_of.validate_type_InlineEven(integer(4))
  assert_eq(
    all_of_error(@all_of.validate_type_InlineEven, integer(3)),
    ("InlineEven", "all_of"),
  )
}

///|
test "all_of validates inline list definitions" {
  @all_of.validate_type_InlineIntList(
    @ion_model.IonValue::List([integer(2), integer(4)]),
  )
  for
    invalid in [
      @ion_model.IonValue::String("not a list"),
      @ion_model.IonValue::List([]),
      @ion_model.IonValue::List([integer(2), @ion_model.IonValue::String("x")]),
      @ion_model.IonValue::List([integer(2), integer(3)]),
    ] {
    assert_eq(
      all_of_error(@all_of.validate_type_InlineIntList, invalid),
      ("InlineIntList", "all_of"),
    )
  }
}

///|
test "all_of validates inline struct fields and closedness" {
  @all_of.validate_type_InlineRecord(
    @ion_model.IonValue::Struct([field("id", integer(7))]),
  )
  @all_of.validate_type_InlineRecord(
    @ion_model.IonValue::Struct([
      field("id", integer(7)),
      field("label", @ion_model.IonValue::String("ready")),
    ]),
  )
  for
    invalid in [
      @ion_model.IonValue::Struct([]),
      @ion_model.IonValue::Struct([
        field("id", @ion_model.IonValue::String("bad")),
      ]),
      @ion_model.IonValue::Struct([
        field("id", integer(7)),
        field("label", @ion_model.IonValue::String("NOT VALID")),
      ]),
      @ion_model.IonValue::Struct([
        field("id", integer(7)),
        field("extra", integer(8)),
      ]),
    ] {
    assert_eq(
      all_of_error(@all_of.validate_type_InlineRecord, invalid),
      ("InlineRecord", "all_of"),
    )
  }
}

///|
test "nullable inline containers accept plain null or nested matches" {
  let plain_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::Null)
  let typed_list_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::List)
  @all_of.validate_type_MaybeInlineIntList(plain_null)
  @all_of.validate_type_MaybeInlineIntList(
    @ion_model.IonValue::List([integer(2), integer(4)]),
  )
  for invalid in [typed_list_null, @ion_model.IonValue::List([integer(3)])] {
    assert_eq(
      all_of_error(@all_of.validate_type_MaybeInlineIntList, invalid),
      ("MaybeInlineIntList", "all_of"),
    )
  }
}

///|
test "inline aliases intersect referenced type constraints" {
  @all_of.validate_type_InlineAlias(integer(2))
  @all_of.validate_type_InlineAlias(integer(4))
  for invalid in [integer(1), integer(3), integer(12)] {
    assert_eq(
      all_of_error(@all_of.validate_type_InlineAlias, invalid),
      ("InlineAlias", "all_of"),
    )
  }
}

///|
test "nullable inline definitions accept only plain null or a matching value" {
  let plain_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::Null)
  let typed_int_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::Int)
  @all_of.validate_type_MaybeInlineEven(plain_null)
  @all_of.validate_type_MaybeInlineEven(integer(2))
  assert_eq(
    all_of_error(@all_of.validate_type_MaybeInlineEven, typed_int_null),
    ("MaybeInlineEven", "all_of"),
  )
  assert_eq(
    all_of_error(@all_of.validate_type_MaybeInlineEven, integer(4)),
    ("MaybeInlineEven", "all_of"),
  )
}

///|
test "all_of propagates through aliases fields and list elements" {
  try {
    ignore(
      @all_of.PositiveBelowTenRecord::from_ion(
        @ion_model.IonValue::Struct([field("value", integer(12))]),
      ),
    )
    assert_true(false)
  } catch {
    @all_of.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "PositiveBelowTenRecord.value")
      assert_eq(constraint, "all_of")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
  try {
    ignore(
      @all_of.from_ion_PositiveBelowTenList(
        @ion_model.IonValue::List([integer(12)]),
      ),
    )
    assert_true(false)
  } catch {
    @all_of.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "PositiveBelowTenList[0]")
      assert_eq(constraint, "all_of")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "all_of nullable arguments preserve plain and typed null rules" {
  let plain_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::Null)
  let typed_int_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::Int)
  @all_of.validate_type_MaybeInt(plain_null)
  @all_of.validate_type_MaybeTypedInt(plain_null)
  @all_of.validate_type_MaybeTypedInt(typed_int_null)
  assert_eq(
    all_of_error(@all_of.validate_type_MaybeInt, typed_int_null),
    ("MaybeInt", "all_of"),
  )
  @all_of.validate_type_MaybeInt(integer(4))
}
