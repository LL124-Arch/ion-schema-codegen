///|
fn inline_import_int(value : Int) -> @ion_model.IonValue {
  @ion_model.IonValue::Int(@bigint.BigInt::from_int(value))
}

///|
test "inline imports resolve relative files for each type algebra operator" {
  @inline_imports.validate_type_InlineAll(inline_import_int(7))
  @inline_imports.validate_type_InlineAny(inline_import_int(7))
  @inline_imports.validate_type_InlineAny(@ion_model.IonValue::String("ion"))
  @inline_imports.validate_type_InlineOne(inline_import_int(7))
  @inline_imports.validate_type_InlineOne(@ion_model.IonValue::String("ion"))
  @inline_imports.validate_type_InlineNot(inline_import_int(10))
  @inline_imports.validate_type_InlineNullableNot(inline_import_int(10))
  @inline_imports.validate_type_InlineNullableNot(
    @ion_model.IonValue::String("ion"),
  )
  let rejected = try {
    @inline_imports.validate_type_InlineNot(inline_import_int(7))
    false
  } catch {
    @inline_imports.ConversionError::InvalidValue(constraint="not", ..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(rejected)
  let nullable_rejected = try {
    @inline_imports.validate_type_InlineNullableNot(
      @ion_model.IonValue::null(kind=@ion_model.IonNull::Null),
    )
    false
  } catch {
    @inline_imports.ConversionError::InvalidValue(constraint="not", ..) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(nullable_rejected)
}

///|
test "inline import constraints keep field and list error paths" {
  let record_error = try {
    ignore(
      @inline_imports.InlineRecord::from_ion(
        @ion_model.IonValue::Struct([
          (@ion_model.IonSymbol::from_text("count"), inline_import_int(12)),
        ]),
      ),
    )
    ("", "")
  } catch {
    @inline_imports.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
  assert_eq(record_error, ("InlineRecord.count", "all_of"))

  let list_error = try {
    ignore(
      @inline_imports.from_ion_InlineList(
        @ion_model.IonValue::List([inline_import_int(12)]),
      ),
    )
    ("", "")
  } catch {
    @inline_imports.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
  assert_eq(list_error, ("InlineList[0]", "all_of"))
}
