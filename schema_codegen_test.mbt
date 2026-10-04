///|
fn expect_codegen_error(source : String) -> @ion-schema-codegen.SchemaError {
  try @ion-schema-codegen.generate_code(source) catch {
    error => error
  } noraise {
    _ =>
      @ion-schema-codegen.SchemaError::InvalidSchema("expected codegen error")
  }
}

///|
test "map every supported scalar to a precision-safe MoonBit type" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Boolean, type: bool} type::{name: Integer, type: int} type::{name: Floating, type: float} type::{name: DecimalValue, type: decimal} type::{name: Text, type: string} type::{name: SymbolValue, type: symbol} type::{name: Time, type: timestamp} type::{name: Binary, type: blob} type::{name: CharacterData, type: clob}",
  )
  assert_eq(
    generated.source,
    "///|\npub type Boolean = Bool\n\n///|\npub type Integer = @bigint.BigInt\n\n///|\npub type Floating = Float\n\n///|\npub type DecimalValue = @ion_model.IonDecimal\n\n///|\npub type Text = String\n\n///|\npub type SymbolValue = @ion_model.IonSymbol\n\n///|\npub type Time = @ion_model.IonTimestamp\n\n///|\npub type Binary = Bytes\n\n///|\npub type CharacterData = Bytes\n",
  )
  assert_eq(generated.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model", "\"moonbitlang/core/bigint\"",
  ])
}

///|
test "generate closed structs with required and optional fields" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{id: {type: int, occurs: required}, name: {type: string, occurs: required}, nickname: {type: string, occurs: optional}}}",
  )
  assert_eq(
    generated.source,
    "///|\npub(all) struct Person {\n  id : @bigint.BigInt\n  name : String\n  nickname : String?\n}\n",
  )
  assert_eq(generated.package_imports, ["\"moonbitlang/core/bigint\""])

  let empty = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: EmptyRecord, type: struct, fields: closed::{}}",
  )
  assert_eq(empty.source, "///|\npub(all) struct EmptyRecord {}\n")
  assert_eq(empty.package_imports, [])
}

///|
test "normalize names deterministically and report keyword and name conflicts" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: my_type, type: struct, fields: closed::{'first-name': string, Name: string}} type::{name: '123-value', type: string}",
  )
  assert_eq(
    generated.source,
    "///|\npub(all) struct MyType {\n  first_name : String?\n  name : String?\n}\n\n///|\npub type T_123Value = String\n",
  )
  assert_eq(generated.package_imports, [])

  let unicode = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: '用户', type: struct, fields: closed::{'年龄': int}}",
  )
  assert_eq(
    unicode.source,
    "///|\npub(all) struct T_用户 {\n  年龄 : @bigint.BigInt?\n}\n",
  )
  assert_eq(unicode.package_imports, ["\"moonbitlang/core/bigint\""])

  let keyword = expect_codegen_error(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{fn: string}}",
  )
  assert_true(
    match keyword {
      @ion-schema-codegen.SchemaError::InvalidIdentifier(_) => true
      _ => false
    },
  )

  let invalid_type = expect_codegen_error(
    "$ion_schema_2_0 type::{name: 'bad/name', type: string}",
  )
  assert_true(
    match invalid_type {
      @ion-schema-codegen.SchemaError::InvalidIdentifier(_) => true
      _ => false
    },
  )

  let type_collision = expect_codegen_error(
    "$ion_schema_2_0 type::{name: 'foo-bar', type: string} type::{name: foo_bar, type: int}",
  )
  assert_true(
    match type_collision {
      @ion-schema-codegen.SchemaError::IdentifierCollision(_) => true
      _ => false
    },
  )

  let field_collision = expect_codegen_error(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{'first-name': string, first_name: int}}",
  )
  assert_true(
    match field_collision {
      @ion-schema-codegen.SchemaError::IdentifierCollision(_) => true
      _ => false
    },
  )

  let builtin_collision = expect_codegen_error(
    "$ion_schema_2_0 type::{name: String, type: bool}",
  )
  assert_true(
    match builtin_collision {
      @ion-schema-codegen.SchemaError::InvalidIdentifier(_) => true
      _ => false
    },
  )

  let option_collision = expect_codegen_error(
    "$ion_schema_2_0 type::{name: Option, type: string}",
  )
  assert_true(
    match option_collision {
      @ion-schema-codegen.SchemaError::InvalidIdentifier(_) => true
      _ => false
    },
  )
}

///|
test "report stable source and imports for repeated generation" {
  let source = "$ion_schema_2_0 type::{name: Score, type: decimal} type::{name: Player, type: struct, fields: closed::{score: decimal}}"
  let first = @ion-schema-codegen.generate_code(source)
  let second = @ion-schema-codegen.generate_code(source)
  assert_eq(first.source, second.source)
  assert_eq(first.package_imports, second.package_imports)
}

///|
test "defer lists and named references to their planned batch" {
  let list = expect_codegen_error(
    "$ion_schema_2_0 type::{name: Scores, type: list, element: int}",
  )
  assert_true(
    match list {
      @ion-schema-codegen.SchemaError::UnsupportedFeature(_) => true
      _ => false
    },
  )

  let named_reference = expect_codegen_error(
    "$ion_schema_2_0 type::{name: Player, type: struct, fields: closed::{score: Score}} type::{name: Score, type: int}",
  )
  assert_true(
    match named_reference {
      @ion-schema-codegen.SchemaError::UnsupportedFeature(_) => true
      _ => false
    },
  )
}
