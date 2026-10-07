///|
fn timestamp_value(
  month : Int?,
  day : Int?,
  include_time : Bool,
  include_second : Bool,
  fraction_digits : Int,
) -> @ion_model.IonValue {
  @ion_model.IonValue::Timestamp(
    @ion_model.IonTimestamp::new(
      year=2000,
      month~,
      day~,
      hour=if include_time { Some(12) } else { None },
      minute=if include_time { Some(34) } else { None },
      second=if include_second { Some(56) } else { None },
      offset_minutes=if include_time { Some(0) } else { None },
      fraction_exponent=if fraction_digits > 0 {
        Some(-fraction_digits)
      } else {
        None
      },
      fraction_coefficient=if fraction_digits > 0 {
        Some(123456789)
      } else {
        None
      },
    ),
  )
}

///|
fn timestamp_with_offset(offset_minutes : Int?) -> @ion_model.IonValue {
  @ion_model.IonValue::Timestamp(
    @ion_model.IonTimestamp::new(
      year=2000,
      month=Some(1),
      day=Some(1),
      hour=Some(12),
      minute=Some(34),
      second=Some(56),
      offset_minutes~,
      fraction_exponent=None,
      fraction_coefficient=None,
    ),
  )
}

///|
fn timestamp_precision_error(
  validate : (@ion_model.IonValue) -> Unit raise @timestamps.ConversionError,
  value : @ion_model.IonValue,
) -> (String, String, String) {
  try {
    validate(value)
    ("", "", "")
  } catch {
    @timestamps.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      (path, constraint, actual)
    _ => ("unexpected", "unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected", "unexpected")
  }
}

///|
test "exact timestamp precision uses the declared component and fraction digits" {
  @timestamps.validate_timestamp_precision_TimestampYear(
    timestamp_value(None, None, false, false, 0),
  )
  @timestamps.validate_timestamp_precision_TimestampSecond(
    timestamp_value(Some(1), Some(1), true, true, 0),
  )
  @timestamps.validate_timestamp_precision_TimestampMillisecond(
    timestamp_value(Some(1), Some(1), true, true, 3),
  )
  @timestamps.validate_timestamp_precision_TimestampMicrosecond(
    timestamp_value(Some(1), Some(1), true, true, 6),
  )
  @timestamps.validate_timestamp_precision_TimestampNanosecond(
    timestamp_value(Some(1), Some(1), true, true, 9),
  )

  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_precision_TimestampYear,
      timestamp_value(Some(1), None, false, false, 0),
    ),
    ("TimestampYear", "timestamp_precision", "3"),
  )
  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_precision_TimestampMicrosecond,
      timestamp_value(Some(1), Some(1), true, true, 5),
    ),
    ("TimestampMicrosecond", "timestamp_precision", "17"),
  )
}

///|
test "timestamp precision constraints follow aliases and nested values" {
  @timestamps.validate_timestamp_precision_TimestampAliasYear(
    timestamp_value(None, None, false, false, 0),
  )
  let wrong_field = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("value"),
      timestamp_value(Some(1), Some(1), true, true, 3),
    ),
  ])
  try {
    ignore(@timestamps.TimestampRecord::from_ion(wrong_field))
    assert_true(false)
  } catch {
    @timestamps.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "TimestampRecord.value")
      assert_eq(constraint, "timestamp_precision")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }

  let wrong_element = @ion_model.IonValue::List([
    timestamp_value(Some(1), Some(1), true, true, 2),
  ])
  try {
    ignore(@timestamps.from_ion_TimestampArray(wrong_element))
    assert_true(false)
  } catch {
    @timestamps.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "TimestampArray[0]")
      assert_eq(constraint, "timestamp_precision")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }

  try {
    ignore(
      @timestamps.from_ion_TimestampRangeArray(
        @ion_model.IonValue::List([
          timestamp_value(Some(1), Some(1), true, true, 3),
        ]),
      ),
    )
    assert_true(false)
  } catch {
    @timestamps.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "TimestampRangeArray[0]")
      assert_eq(constraint, "timestamp_precision")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "timestamp precision ranges compare fractional seconds between named levels" {
  @timestamps.validate_timestamp_precision_TimestampFractionSubMillisecond(
    timestamp_value(Some(1), Some(1), true, true, 1),
  )
  @timestamps.validate_timestamp_precision_TimestampFractionSubMillisecond(
    timestamp_value(Some(1), Some(1), true, true, 2),
  )
  @timestamps.validate_timestamp_precision_TimestampMillisecondOrFiner(
    timestamp_value(Some(1), Some(1), true, true, 9),
  )
  @timestamps.validate_timestamp_precision_TimestampPrefixThroughDay(
    timestamp_value(Some(1), Some(1), false, false, 0),
  )
  @timestamps.validate_timestamp_precision_TimestampFractionAlias(
    timestamp_value(Some(1), Some(1), true, true, 1),
  )

  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_precision_TimestampFractionSubMillisecond,
      timestamp_value(Some(1), Some(1), true, true, 0),
    ),
    ("TimestampFractionSubMillisecond", "timestamp_precision", "12"),
  )
  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_precision_TimestampFractionSubMillisecond,
      timestamp_value(Some(1), Some(1), true, true, 3),
    ),
    ("TimestampFractionSubMillisecond", "timestamp_precision", "15"),
  )
  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_precision_TimestampMillisecondOrFiner,
      timestamp_value(Some(1), Some(1), true, true, 2),
    ),
    ("TimestampMillisecondOrFiner", "timestamp_precision", "14"),
  )

  let out_of_range_field = @ion_model.IonValue::Struct([
    (
      @ion_model.IonSymbol::from_text("value"),
      timestamp_value(Some(1), Some(1), true, true, 0),
    ),
  ])
  try {
    ignore(@timestamps.TimestampRangeRecord::from_ion(out_of_range_field))
    assert_true(false)
  } catch {
    @timestamps.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "TimestampRangeRecord.value")
      assert_eq(constraint, "timestamp_precision")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "timestamp offset constraints distinguish UTC from unknown local offset" {
  @timestamps.validate_timestamp_offset_TimestampUtc(
    timestamp_with_offset(Some(0)),
  )
  @timestamps.validate_timestamp_offset_TimestampUnknownOffset(
    timestamp_with_offset(None),
  )
  @timestamps.validate_timestamp_offset_TimestampKnownOffsets(
    timestamp_with_offset(Some(330)),
  )
  @timestamps.validate_timestamp_offset_TimestampKnownOffsets(
    timestamp_with_offset(Some(-240)),
  )
  @timestamps.validate_timestamp_offset_TimestampOffsetAlias(
    timestamp_with_offset(Some(0)),
  )

  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_offset_TimestampUtc,
      timestamp_with_offset(Some(60)),
    ),
    ("TimestampUtc", "timestamp_offset", "+01:00"),
  )
  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_offset_TimestampUnknownOffset,
      timestamp_with_offset(Some(0)),
    ),
    ("TimestampUnknownOffset", "timestamp_offset", "Z"),
  )
  assert_eq(
    timestamp_precision_error(
      @timestamps.validate_timestamp_offset_TimestampNoAllowedOffset,
      timestamp_with_offset(None),
    ),
    ("TimestampNoAllowedOffset", "timestamp_offset", "-00:00"),
  )

  let invalid_field = @ion_model.IonValue::Struct([
    (@ion_model.IonSymbol::from_text("value"), timestamp_with_offset(Some(60))),
  ])
  try {
    ignore(@timestamps.TimestampOffsetRecord::from_ion(invalid_field))
    assert_true(false)
  } catch {
    @timestamps.ConversionError::InvalidValue(path~, constraint~, actual~) => {
      assert_eq(path, "TimestampOffsetRecord.value")
      assert_eq(constraint, "timestamp_offset")
      assert_eq(actual, "+01:00")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }

  try {
    ignore(
      @timestamps.from_ion_TimestampOffsetArray(
        @ion_model.IonValue::List([timestamp_with_offset(Some(60))]),
      ),
    )
    assert_true(false)
  } catch {
    @timestamps.ConversionError::InvalidValue(path~, constraint~, ..) => {
      assert_eq(path, "TimestampOffsetArray[0]")
      assert_eq(constraint, "timestamp_offset")
    }
    _ => assert_true(false)
  } noraise {
    _ => assert_true(false)
  }
}
