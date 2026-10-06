///|
fn expect_schema_error(source : String) -> @ion-schema-codegen.SchemaError {
  try @ion-schema-codegen.check_schema(source) catch {
    error => error
  } noraise {
    _ => @ion-schema-codegen.SchemaError::InvalidSchema("expected schema error")
  }
}

///|
test "parse supported scalar struct list and named references" {
  let source = "$ion_schema_2_0 type::{name: Address, type: struct, fields: closed::{city: string}} type::{name: Person, type: struct, fields: closed::{address: Address, age: {type: int, occurs: required}, name: string, nickname: {type: string, occurs: optional}}} type::{name: People, type: list, element: Person} type::{name: DisplayName, type: string}"
  @ion-schema-codegen.check_schema(source)
}

///|
test "accept non-null any and nullable universal any" {
  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: AnyValue, type: any}",
  )
  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: NullableValue, type: $any}",
  )

  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: NullableInteger, type: $int} type::{name: MaybeInteger, type: list, element: $null_or::int}",
  )
}

///|
test "reject explicit occurs on nullable type arguments" {
  let error = expect_schema_error(
    "$ion_schema_2_0 type::{name: Record, type: struct, fields: closed::{value: {type: $null_or::int, occurs: required}}}",
  )
  assert_true(
    match error {
      @ion-schema-codegen.SchemaError::InvalidOccurs(_) => true
      _ => false
    },
  )
}

///|
test "accept integer and range occurs values" {
  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: Record, type: struct, fields: closed::{fixed: {type: int, occurs: 3}, bounded: {type: string, occurs: range::[2, 5]}, unbounded: {type: bool, occurs: range::[exclusive::0, max]}}}",
  )
}

///|
test "reject invalid occurs counts and ranges" {
  for
    invalid in [
      "occurs: -1", "occurs: range::[min, max]", "occurs: range::[exclusive::2, 2]",
      "occurs: range::[4, 2]",
    ] {
    let error = expect_schema_error(
      "$ion_schema_2_0 type::{name: Record, type: struct, fields: closed::{values: {type: int, \{invalid}}}}",
    )
    assert_true(
      match error {
        @ion-schema-codegen.SchemaError::InvalidOccurs(_) => true
        _ => false
      },
    )
  }
}

///|
test "accept named Ion document stream types" {
  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: EventStream, type: document}",
  )
}

///|
test "ISL 2.0 marker-only schema is valid" {
  @ion-schema-codegen.check_schema("$ion_schema_2_0")
}

///|
test "report missing unsupported and misplaced version markers" {
  let missing = expect_schema_error("type::{name: Person, type: struct}")
  assert_true(
    match missing {
      @ion-schema-codegen.SchemaError::UnsupportedVersion(_) => true
      _ => false
    },
  )

  let old_version = expect_schema_error("$ion_schema_1_0")
  assert_true(
    match old_version {
      @ion-schema-codegen.SchemaError::UnsupportedVersion(_) => true
      _ => false
    },
  )

  let misplaced = expect_schema_error("42 $ion_schema_2_0")
  assert_true(
    match misplaced {
      @ion-schema-codegen.SchemaError::InvalidSchema(_) => true
      _ => false
    },
  )

  let malformed = expect_schema_error("$ion_schema_2_0 type::{name:")
  assert_true(
    match malformed {
      @ion-schema-codegen.SchemaError::IonParse(_) => true
      _ => false
    },
  )
}

///|
test "reject duplicate type and field declarations" {
  let duplicate_type = expect_schema_error(
    "$ion_schema_2_0 type::{name: Person, type: string} type::{name: Person, type: int}",
  )
  assert_true(
    match duplicate_type {
      @ion-schema-codegen.SchemaError::DuplicateType(_) => true
      _ => false
    },
  )

  let duplicate_field = expect_schema_error(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{name: string, name: int}}",
  )
  assert_true(
    match duplicate_field {
      @ion-schema-codegen.SchemaError::DuplicateField(..) => true
      _ => false
    },
  )
}

///|
test "reject missing declarations and unknown references" {
  let missing_type = expect_schema_error(
    "$ion_schema_2_0 type::{name: Person, fields: closed::{name: string}}",
  )
  assert_true(
    match missing_type {
      @ion-schema-codegen.SchemaError::InvalidSchema(_) => true
      _ => false
    },
  )

  let missing_fields = expect_schema_error(
    "$ion_schema_2_0 type::{name: Person, type: struct}",
  )
  assert_true(
    match missing_fields {
      @ion-schema-codegen.SchemaError::InvalidSchema(_) => true
      _ => false
    },
  )

  let unknown_reference = expect_schema_error(
    "$ion_schema_2_0 type::{name: People, type: list, element: Missing}",
  )
  assert_true(
    match unknown_reference {
      @ion-schema-codegen.SchemaError::UnknownType(_) => true
      _ => false
    },
  )
}

///|
test "accept open fields and valid_values and reject unsupported constraints and imports" {
  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: {name: string}}",
  )

  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: Positive, type: int, valid_values: [1, 2]}",
  )

  let unsupported_constraint = expect_schema_error(
    "$ion_schema_2_0 type::{name: PositiveText, type: string, regex: 1}",
  )
  assert_true(
    match unsupported_constraint {
      @ion-schema-codegen.SchemaError::UnsupportedFeature(_) => true
      _ => false
    },
  )

  let imports = expect_schema_error(
    "$ion_schema_2_0 schema_header::{imports: []}",
  )
  assert_true(
    match imports {
      @ion-schema-codegen.SchemaError::UnsupportedFeature(_) => true
      _ => false
    },
  )

  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: NullableInt, type: $int} type::{name: MaybeString, type: list, element: $null_or::string}",
  )
}

///|
test "reject duplicate field occurrence declarations" {
  let duplicate_occurs = expect_schema_error(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{age: {type: int, occurs: required, occurs: optional}}}",
  )
  assert_true(
    match duplicate_occurs {
      @ion-schema-codegen.SchemaError::InvalidOccurs(_) => true
      _ => false
    },
  )
}

///|
test "validate schema header footer placement" {
  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 schema_header::{} type::{name: Person, type: string} schema_footer::{}",
  )

  let duplicate_header = expect_schema_error(
    "$ion_schema_2_0 schema_header::{} schema_header::{}",
  )
  assert_true(
    match duplicate_header {
      @ion-schema-codegen.SchemaError::InvalidSchema(_) => true
      _ => false
    },
  )

  let late_header = expect_schema_error(
    "$ion_schema_2_0 type::{name: Person, type: string} schema_header::{}",
  )
  assert_true(
    match late_header {
      @ion-schema-codegen.SchemaError::InvalidSchema(_) => true
      _ => false
    },
  )

  let after_footer = expect_schema_error(
    "$ion_schema_2_0 schema_footer::{} type::{name: Person, type: string}",
  )
  assert_true(
    match after_footer {
      @ion-schema-codegen.SchemaError::InvalidSchema(_) => true
      _ => false
    },
  )
}

///|
test "accept S-expressions as scalar type references" {
  @ion-schema-codegen.check_schema(
    "$ion_schema_2_0 type::{name: Expression, type: sexp} type::{name: Expressions, type: list, element: Expression} type::{name: ExpressionRecord, type: struct, fields: closed::{expression: {type: Expression, occurs: required}}}",
  )
}
