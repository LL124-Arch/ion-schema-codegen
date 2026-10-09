///|
fn annotation_failure(
  validate : (@ion_model.IonValue) -> Unit raise @annotations.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String) {
  try {
    validate(value)
    ("", "")
  } catch {
    @annotations.ConversionError::InvalidValue(path~, constraint~, ..) =>
      (path, constraint)
    _ => ("unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected")
  }
}

///|
fn tagged_value() -> @ion_model.IonValue {
  @ion_model.IonValue::String("hello").with_annotations([
    @ion_model.IonSymbol::from_text("record"),
    @ion_model.IonSymbol::from_text("v1"),
  ])
}

///|
test "simple annotations support closed required and preserve raw values" {
  let value = tagged_value()
  @annotations.validate_annotations_Tagged(value)
  @annotations.validate_annotations_OpenTagged(
    value.with_annotations([
      @ion_model.IonSymbol::from_text("message"),
      @ion_model.IonSymbol::from_text("extra"),
    ]),
  )
  assert_eq(value.annotations().length(), 2)
  assert_eq(
    annotation_failure(
      @annotations.validate_annotations_Tagged,
      @ion_model.IonValue::String("hello").with_annotations([
        @ion_model.IonSymbol::from_text("record"),
      ]),
    ),
    ("Tagged", "annotations"),
  )
  assert_eq(
    annotation_failure(
      @annotations.validate_annotations_Tagged,
      value.with_annotations([@ion_model.IonSymbol::from_text("extra")]),
    ),
    ("Tagged", "annotations"),
  )
  @annotations.validate_annotations_Tagged(
    @ion_model.IonValue::null(kind=@ion_model.IonNull::Int).with_annotations([
      @ion_model.IonSymbol::from_text("record"),
      @ion_model.IonSymbol::from_text("v1"),
    ]),
  )
}

///|
test "standard annotations can reference a named type" {
  let value = @ion_model.IonValue::String("hello").with_annotations([
    @ion_model.IonSymbol::from_text("record"),
    @ion_model.IonSymbol::from_text("v1"),
  ])
  @annotations.validate_annotations_ExactlyTwoTagged(value)
  assert_eq(
    annotation_failure(
      @annotations.validate_annotations_ExactlyTwoTagged,
      value.with_annotations([@ion_model.IonSymbol::from_text("record")]),
    ),
    ("ExactlyTwoTagged", "annotations"),
  )
}

///|
test "standard annotations support exact and ranged container lengths" {
  let value = @ion_model.IonValue::String("hello")
  @annotations.validate_annotations_OneOrTwoAnnotations(
    value.with_annotations([@ion_model.IonSymbol::from_text("record")]),
  )
  @annotations.validate_annotations_OneOrTwoAnnotations(
    value.with_annotations([
      @ion_model.IonSymbol::from_text("record"),
      @ion_model.IonSymbol::from_text("v1"),
    ]),
  )
  assert_eq(
    annotation_failure(
      @annotations.validate_annotations_OneOrTwoAnnotations,
      value.with_annotations([]),
    ),
    ("OneOrTwoAnnotations", "annotations"),
  )
  assert_eq(
    annotation_failure(
      @annotations.validate_annotations_OneOrTwoAnnotations,
      value.with_annotations([
        @ion_model.IonSymbol::from_text("record"),
        @ion_model.IonSymbol::from_text("v1"),
        @ion_model.IonSymbol::from_text("extra"),
      ]),
    ),
    ("OneOrTwoAnnotations", "annotations"),
  )
}

///|
test "annotation constraints propagate through aliases fields and lists" {
  try {
    ignore(
      @annotations.TagRecord::from_ion(
        @ion_model.IonValue::Struct([
          (
            @ion_model.IonSymbol::from_text("payload"),
            @ion_model.IonValue::String("bad").with_annotations([
              @ion_model.IonSymbol::from_text("record"),
            ]),
          ),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @annotations.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "TagRecord.payload")
      assert_eq(constraint, "annotations")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }

  try {
    ignore(
      @annotations.from_ion_TagList(
        @ion_model.IonValue::List([
          @ion_model.IonValue::String("bad").with_annotations([
            @ion_model.IonSymbol::from_text("record"),
            @ion_model.IonSymbol::from_text("v1"),
            @ion_model.IonSymbol::from_text("extra"),
          ]),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @annotations.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "TagList[0]")
      assert_eq(constraint, "annotations")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }

  let record = @annotations.TagRecord::from_ion(
    @ion_model.IonValue::Struct([
      (@ion_model.IonSymbol::from_text("payload"), tagged_value()),
    ]),
  )
  let restored = record.to_ion()
  assert_eq(restored.get_field("payload").unwrap().annotations().length(), 2)
}

///|
test "document values never satisfy annotation constraints" {
  try {
    ignore(@annotations.from_ion_document_Stream([]))
    assert_true(false)
  } catch {
    @annotations.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "Stream")
      assert_eq(constraint, "annotations")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
