///|
fn int_value(value : Int) -> @ion_model.IonValue {
  @ion_model.IonValue::Int(@bigint.BigInt::from_int(value))
}

///|
fn symbol_value(value : String) -> @ion_model.IonValue {
  @ion_model.IonValue::Symbol(@ion_model.IonSymbol::from_text(value))
}

///|
fn tagged_one() -> @ion_model.IonValue {
  @ion_model.IonValue::Annotated(
    [@ion_model.IonSymbol::from_text("tag")],
    int_value(1),
  )
}

///|
fn nested_struct(reverse : Bool) -> @ion_model.IonValue {
  let a = (@ion_model.IonSymbol::from_text("a"), int_value(1))
  let b = (@ion_model.IonSymbol::from_text("b"), int_value(2))
  if reverse {
    @ion_model.IonValue::Struct([b, a])
  } else {
    @ion_model.IonValue::Struct([a, b])
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
fn required_values_error(
  value : @ion_model.IonValue,
) -> (String, String, String) {
  try {
    ignore(@contains.from_ion_RequiredValues(value))
    ("", "", "")
  } catch {
    @contains.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      (path, constraint, actual)
    _ => ("unexpected", "unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected", "unexpected")
  }
}

///|
fn required_fields_error(
  value : @ion_model.IonValue,
) -> (String, String, String) {
  try {
    ignore(@contains.RequiredFields::from_ion(value))
    ("", "", "")
  } catch {
    @contains.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      (path, constraint, actual)
    _ => ("unexpected", "unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected", "unexpected")
  }
}

///|
fn required_stream_error(
  values : Array[@ion_model.IonValue],
) -> (String, String, String) {
  try {
    ignore(@contains.from_ion_document_RequiredStream(values))
    ("", "", "")
  } catch {
    @contains.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      (path, constraint, actual)
    _ => ("unexpected", "unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected", "unexpected")
  }
}

///|
fn holder_error(value : @ion_model.IonValue) -> (String, String, String) {
  try {
    ignore(@contains.ContainsHolder::from_ion(value))
    ("", "", "")
  } catch {
    @contains.ConversionError::InvalidValue(path~, constraint~, actual~) =>
      (path, constraint, actual)
    _ => ("unexpected", "unexpected", "unexpected")
  } noraise {
    _ => ("unexpected", "unexpected", "unexpected")
  }
}

///|
test "contains uses Ion equivalence and ignores repeated requirements" {
  let accepted = @contains.from_ion_RequiredValues(
    @ion_model.IonValue::List([int_value(9), nested_struct(true), tagged_one()]),
  )
  assert_eq(accepted.length(), 3)
  assert_eq(
    @contains.from_ion_RequiredIntValues(
      @ion_model.IonValue::List([int_value(3)]),
    ),
    [@bigint.BigInt::from_int(3)],
  )
  let typed_null = @ion_model.IonValue::null(kind=@ion_model.IonNull::Null)
  assert_eq(
    @contains.from_ion_NullableIntValues(
      @ion_model.IonValue::List([typed_null, int_value(1)]),
    ),
    [typed_null, int_value(1)],
  )

  assert_eq(
    required_values_error(@ion_model.IonValue::List([int_value(1)])),
    ("RequiredValues", "contains", "tag::1"),
  )
  assert_eq(
    required_values_error(@ion_model.IonValue::List([tagged_one()])),
    ("RequiredValues", "contains", "{a: 1, b: 2}"),
  )
}

///|
test "contains checks values inside struct fields" {
  let accepted = @contains.RequiredFields::from_ion(
    @ion_model.IonValue::Struct([ion_field("color", symbol_value("green"))]),
  )
  assert_eq(accepted.ion_schema_codegen_open_content.length(), 1)

  assert_eq(
    required_fields_error(
      @ion_model.IonValue::Struct([ion_field("color", symbol_value("red"))]),
    ),
    ("RequiredFields", "contains", "green"),
  )
}

///|
test "contains validates document streams regardless of value order" {
  assert_eq(
    @contains.from_ion_document_RequiredStream([int_value(2), int_value(1)]),
    [int_value(2), int_value(1)],
  )
  assert_eq(
    @contains.from_ion_document_RequiredStreamAlias([
      int_value(3),
      int_value(1),
      int_value(2),
    ]),
    [int_value(3), int_value(1), int_value(2)],
  )
  assert_eq(
    required_stream_error([int_value(1)]),
    ("RequiredStream", "contains", "2"),
  )
}

///|
test "contains constraints on sexp and list aliases reach nested conversions" {
  let valid = @contains.ContainsHolder::from_ion(
    @ion_model.IonValue::Struct([
      ion_field(
        "expression",
        @ion_model.IonValue::Sexp([symbol_value("ready")]),
      ),
      ion_field("values", @ion_model.IonValue::List([int_value(4)])),
      ion_field(
        "record",
        @ion_model.IonValue::Struct([ion_field("color", symbol_value("blue"))]),
      ),
    ]),
  )
  assert_eq(valid.values, [int_value(4)])

  assert_eq(
    holder_error(
      @ion_model.IonValue::Struct([
        ion_field("expression", @ion_model.IonValue::Sexp([])),
        ion_field("values", @ion_model.IonValue::List([int_value(4)])),
        ion_field(
          "record",
          @ion_model.IonValue::Struct([ion_field("color", symbol_value("blue"))]),
        ),
      ]),
    ),
    ("ContainsHolder.expression", "contains", "ready"),
  )
  assert_eq(
    holder_error(
      @ion_model.IonValue::Struct([
        ion_field(
          "expression",
          @ion_model.IonValue::Sexp([symbol_value("ready")]),
        ),
        ion_field("values", @ion_model.IonValue::List([])),
        ion_field(
          "record",
          @ion_model.IonValue::Struct([ion_field("color", symbol_value("blue"))]),
        ),
      ]),
    ),
    ("ContainsHolder.values", "contains", "4"),
  )
  assert_eq(
    holder_error(
      @ion_model.IonValue::Struct([
        ion_field(
          "expression",
          @ion_model.IonValue::Sexp([symbol_value("ready")]),
        ),
        ion_field("values", @ion_model.IonValue::List([int_value(4)])),
        ion_field(
          "record",
          @ion_model.IonValue::Struct([ion_field("color", symbol_value("red"))]),
        ),
      ]),
    ),
    ("ContainsHolder.record", "contains", "blue"),
  )
}
