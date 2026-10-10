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
test "map any to raw Ion values in aliases fields and lists" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: AnyValue, type: any} type::{name: AnyValues, type: list, element: AnyValue} type::{name: AnyRecord, type: struct, fields: closed::{named_value: {type: AnyValue, occurs: required}, raw: {type: any, occurs: required}, optional_raw: {type: any, occurs: optional}}}",
  )
  assert_true(
    generated.source.contains("pub type AnyValue = @ion_model.IonValue"),
  )
  assert_true(generated.source.contains("pub(all) struct AnyRecord {"))
  assert_true(generated.source.contains("named_value : AnyValue"))
  assert_true(generated.source.contains("raw : @ion_model.IonValue"))
  assert_true(generated.source.contains("optional_raw : @ion_model.IonValue?"))
  assert_true(generated.source.contains("pub type AnyValues = Array[AnyValue]"))
  assert_eq(generated.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
  ])
}

///|
test "map nullable any to raw Ion values" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: NullableValue, type: $any} type::{name: NullableValues, type: list, element: NullableValue} type::{name: NullableRecord, type: struct, fields: closed::{value: {type: $any, occurs: required}, optional: {type: NullableValue, occurs: optional}}}",
  )
  assert_true(
    generated.source.contains("pub type NullableValue = @ion_model.IonValue"),
  )
  assert_true(generated.source.contains("value : @ion_model.IonValue"))
  assert_true(generated.source.contains("optional : NullableValue?"))
  assert_true(
    generated.source.contains("pub type NullableValues = Array[NullableValue]"),
  )
}

///|
test "map nullable Ion types and null-or type arguments to raw Ion values" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: TypedInt, type: $int} type::{name: MaybeStrings, type: list, element: $null_or::string} type::{name: NullableRecord, type: struct, fields: closed::{typed_int: {type: TypedInt, occurs: required}, optional_text: $null_or::string}}",
  )
  assert_true(
    generated.source.contains("pub type TypedInt = @ion_model.IonValue"),
  )
  assert_true(
    generated.source.contains(
      "pub type MaybeStrings = Array[@ion_model.IonValue]",
    ),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_matches_type(field_value, \"$int\")",
    ),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_matches_type(field_value, \"$null\")",
    ),
  )
  let occurrences = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Record, type: struct, fields: closed::{values: {type: string, occurs: range::[2, 4]}}}",
  )
  assert_true(occurrences.source.contains("values : Array[String]"))
  assert_true(occurrences.source.contains("FieldOccurrenceMismatch"))
  assert_eq(generated.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
  ])
}

///|
test "generate document stream APIs and reject nested document types" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: EventStream, type: document} type::{name: EventStreamAlias, type: EventStream}",
  )
  assert_true(
    generated.source.contains(
      "pub type EventStream = Array[@ion_model.IonValue]",
    ),
  )
  assert_true(
    generated.source.contains("pub fn from_ion_document_EventStream("),
  )
  assert_true(generated.source.contains("values : Array[@ion_model.IonValue]"))
  assert_true(
    generated.source.contains("pub fn to_ion_document_EventStreamAlias("),
  )

  let nested_document = expect_codegen_error(
    "$ion_schema_2_0 type::{name: EventStream, type: document} type::{name: Envelope, type: struct, fields: closed::{document: EventStream}}",
  )
  assert_true(
    match nested_document {
      @ion-schema-codegen.SchemaError::UnsupportedFeature(_) => true
      _ => false
    },
  )

  let list_document = expect_codegen_error(
    "$ion_schema_2_0 type::{name: EventStream, type: document} type::{name: EventStreams, type: list, element: EventStream}",
  )
  assert_true(
    match list_document {
      @ion-schema-codegen.SchemaError::UnsupportedFeature(_) => true
      _ => false
    },
  )
}

///|
test "generate closed structs with required and optional fields" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{id: {type: int, occurs: required}, name: {type: string, occurs: required}, nickname: {type: string, occurs: optional}}}",
  )
  assert_true(generated.source.contains("pub(all) struct Person {"))
  assert_true(generated.source.contains("  id : @bigint.BigInt\n"))
  assert_true(generated.source.contains("  nickname : String?\n"))
  assert_true(generated.source.contains("pub fn Person::from_ion"))
  assert_true(generated.source.contains("pub fn Person::to_ion"))
  assert_true(
    generated.source.contains(
      "ConversionError::MissingRequiredField(path=\"Person.id\")",
    ),
  )
  assert_eq(generated.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model", "\"moonbitlang/core/bigint\"",
  ])

  let empty = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: EmptyRecord, type: struct, fields: closed::{}}",
  )
  assert_true(empty.source.contains("pub(all) struct EmptyRecord {}"))
  assert_true(empty.source.contains("pub fn EmptyRecord::from_ion"))
  assert_true(empty.source.contains("pub fn EmptyRecord::to_ion"))
  assert_eq(empty.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
  ])
}

///|
test "generate open structs that retain unknown fields" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Record, type: struct, fields:{known: {type: string, occurs: required}}}",
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_open_content : Array[(@ion_model.IonSymbol, @ion_model.IonValue)]",
    ),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_open_content.push((field_symbol, field_value))",
    ),
  )
  assert_true(generated.source.contains("self.ion_schema_codegen_open_content"))
}

///|
test "normalize names deterministically and report keyword and name conflicts" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: my_type, type: struct, fields: closed::{'first-name': string, Name: string}} type::{name: '123-value', type: string}",
  )
  assert_true(generated.source.contains("pub(all) struct MyType {"))
  assert_true(generated.source.contains("  first_name : String?\n"))
  assert_true(generated.source.contains("  name : String?\n"))
  assert_true(generated.source.contains("pub type T_123Value = String"))
  assert_true(generated.source.contains("pub fn MyType::from_ion"))
  assert_eq(generated.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
  ])

  let unicode = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: '用户', type: struct, fields: closed::{'年龄': int}}",
  )
  assert_true(unicode.source.contains("pub(all) struct T_用户 {"))
  assert_true(unicode.source.contains("  年龄 : @bigint.BigInt?\n"))
  assert_eq(unicode.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model", "\"moonbitlang/core/bigint\"",
  ])

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

  let conversion_error_collision = expect_codegen_error(
    "$ion_schema_2_0 type::{name: ConversionError, type: string} type::{name: Person, type: struct, fields: closed::{name: string}}",
  )
  assert_true(
    match conversion_error_collision {
      @ion-schema-codegen.SchemaError::IdentifierCollision(_) => true
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
test "generated conversion locals avoid schema field name collisions" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: CollisionCase, type: struct, fields: closed::{ion_schema_codegen_value_0: {type: string, occurs: required}, input_field_1: {type: int, occurs: required}}}",
  )
  assert_true(
    generated.source.contains(
      "let ion_schema_codegen_value__0 : String = match input_field_0 {",
    ),
  )
  assert_true(
    generated.source.contains(
      "let ion_schema_codegen_value__1 : @bigint.BigInt = match input_field_1 {",
    ),
  )
  assert_true(
    generated.source.contains("input_field_1: ion_schema_codegen_value__1"),
  )
}

///|
test "generate lists and resolve forward named references" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{primary: Address, addresses: AddressList, scores: Scores}} type::{name: AddressList, type: list, element: Address} type::{name: Scores, type: list, element: Score} type::{name: Address, type: struct, fields: closed::{city: string}} type::{name: Score, type: int}",
  )
  assert_true(
    generated.source.contains("pub type AddressList = Array[Address]"),
  )
  assert_true(generated.source.contains("pub type Scores = Array[Score]"))
  assert_true(generated.source.contains("pub type Score = @bigint.BigInt"))
  assert_true(generated.source.contains("pub fn from_ion_AddressList"))
  assert_true(generated.source.contains("pub fn to_ion_AddressList"))
  assert_true(generated.source.contains("Address::from_ion(field_value)"))
  assert_true(generated.source.contains("to_ion_AddressList(field_value)"))
  assert_true(generated.source.contains("path=element_path"))
  assert_eq(generated.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model", "\"moonbitlang/core/bigint\"",
  ])
  assert_eq(
    @ion-schema-codegen.generate_code(
      "$ion_schema_2_0 type::{name: Values, type: list, element: string}",
    ).source,
    @ion-schema-codegen.generate_code(
      "$ion_schema_2_0 type::{name: Values, type: list, element: string}",
    ).source,
  )

  let forward = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{address: {type: Address, occurs: required}}} type::{name: Address, type: struct, fields: closed::{city: string}}",
  )
  let dependency_first = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Address, type: struct, fields: closed::{city: string}} type::{name: Person, type: struct, fields: closed::{address: {type: Address, occurs: required}}}",
  )
  assert_eq(forward.source, dependency_first.source)
}

///|
test "reject unknown and cyclic named references with a cycle chain" {
  let unknown = expect_codegen_error(
    "$ion_schema_2_0 type::{name: Person, type: struct, fields: closed::{address: MissingAddress}}",
  )
  assert_true(
    match unknown {
      @ion-schema-codegen.SchemaError::UnknownType(_) => true
      _ => false
    },
  )

  let cycle = expect_codegen_error(
    "$ion_schema_2_0 type::{name: First, type: struct, fields: closed::{second: Second}} type::{name: Second, type: struct, fields: closed::{first: First}}",
  )
  assert_true(
    match cycle {
      @ion-schema-codegen.SchemaError::CyclicTypeReference(message) =>
        message.contains("First -> Second -> First")
      _ => false
    },
  )
}

///|
test "reject unknown references nested in inline not constraints" {
  let error = expect_codegen_error(
    "$ion_schema_2_0 type::{name: UnknownInlineNegative, all_of: [{not: MissingType}]}",
  )
  assert_true(
    match error {
      @ion-schema-codegen.SchemaError::UnknownType(message) =>
        message.contains("MissingType")
      _ => false
    },
  )
}

///|
test "detect cycles crossing inline type algebra definitions" {
  let error = expect_codegen_error(
    "$ion_schema_2_0 type::{name: InlineCycleA, all_of: [{all_of: [InlineCycleB]}]} type::{name: InlineCycleB, all_of: [{all_of: [InlineCycleA]}]}",
  )
  assert_true(
    match error {
      @ion-schema-codegen.SchemaError::CyclicTypeReference(message) =>
        message.contains("InlineCycleA") && message.contains("InlineCycleB")
      _ => false
    },
  )
}

///|
test "generate S-expression aliases fields and list elements" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: Expression, type: sexp} type::{name: Expressions, type: list, element: Expression} type::{name: ExpressionRecord, type: struct, fields: closed::{expression: {type: Expression, occurs: required}}}",
  )
  assert_true(
    generated.source.contains(
      "pub type Expression = Array[@ion_model.IonValue]",
    ),
  )
  assert_true(
    generated.source.contains("@ion_model.IonValue::Sexp(converted_value)"),
  )
  assert_true(generated.source.contains("pub fn from_ion_Expressions"))
  assert_true(generated.source.contains("pub fn ExpressionRecord::from_ion"))
  assert_eq(generated.package_imports, [
    "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
  ])
}

///|
test "generate container_length checks for containers and document streams" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: SizedList, type: list, element: int, container_length: range::[1, 4]} type::{name: SizedStruct, type: struct, fields: {}, container_length: 2} type::{name: SizedDocument, type: document, container_length: 3}",
  )
  assert_true(
    generated.source.contains(
      "if input_elements.length() < 1 || input_elements.length() > 4",
    ),
  )
  assert_true(
    generated.source.contains(
      "if input_fields.length() < 2 || input_fields.length() > 2",
    ),
  )
  assert_true(
    generated.source.contains("if values.length() < 3 || values.length() > 3"),
  )
  assert_true(generated.source.contains("constraint=\"container_length\""))
}

///|
test "generate Unicode and LOB length validators" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: LimitedText, type: string, codepoint_length: 2, utf8_byte_length: range::[2, 8]} type::{name: LimitedBlob, type: blob, byte_length: 3} type::{name: TextRecord, type: struct, fields: closed::{text: {type: LimitedText, occurs: required}, blob: {type: LimitedBlob, occurs: required}}}",
  )
  assert_true(generated.source.contains("text.char_length()"))
  assert_true(generated.source.contains("codepoint <= 0x7F"))
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_utf8_byte_length(field_value)",
    ),
  )
  assert_true(
    generated.source.contains("ion_schema_codegen_byte_length(field_value)"),
  )
  assert_true(generated.source.contains("constraint=\"byte_length\""))
}

///|
test "generate element validators for structs S-expressions and documents" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: IntExpression, type: sexp, element: int} type::{name: IntExpressionRecord, type: struct, fields: closed::{expression: {type: IntExpression, occurs: required}}} type::{name: IntRecord, type: struct, element: int} type::{name: IntDocument, type: document, element: int}",
  )
  assert_true(generated.source.contains("@ion_model.IonValue::Sexp(elements)"))
  assert_true(
    generated.source.contains("ion_schema_codegen_struct_element_path"),
  )
  assert_true(generated.source.contains("ion_schema_codegen_document_index_"))
  assert_true(generated.source.contains("expected=\"int\""))
}

///|
test "generate distinct element checks using Ion value equivalence" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: UniqueValues, type: list, element: distinct::$any} type::{name: UniqueFields, type: struct, element: distinct::$any}",
  )
  assert_true(generated.source.contains("fn ion_schema_codegen_values_equal("))
  assert_true(generated.source.contains("constraint=\"distinct::element\""))
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_check_distinct(input_elements, type_path)",
    ),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_check_distinct(ion_schema_codegen_distinct_UniqueFields, type_path)",
    ),
  )
}

///|
test "generate field_names checks for direct and aliased structs" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: AllowedNames, type: symbol, valid_values: [alpha]} type::{name: NamedFields, type: struct, field_names: AllowedNames} type::{name: UniqueFields, type: struct, field_names: distinct::AllowedNames} type::{name: BaseFields, type: struct} type::{name: UniqueFieldAlias, type: BaseFields, field_names: distinct::AllowedNames} type::{name: FieldAliasHolder, type: struct, fields: {record: UniqueFieldAlias}}",
  )
  assert_true(generated.source.contains("field_names"))
  assert_true(generated.source.contains("distinct::field_names"))
  assert_true(
    generated.source.contains("ion_schema_codegen_check_distinct_symbols("),
  )
  assert_true(
    generated.source.contains("ion_schema_codegen_field_names_UniqueFields"),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_field_name_fields_UniqueFieldAlias",
    ),
  )
}

///|
test "generate contains checks with the Ion value matcher" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: RequiredValues, type: list, element: $any, contains: [tag::1]} type::{name: RequiredFields, type: struct, contains: [ready]} type::{name: RequiredStream, type: document, contains: [1]}",
  )
  assert_true(generated.source.contains("ion_schema_codegen_check_contains("))
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_values_equal(expected, value)",
    ),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_struct_field_values(input_fields)",
    ),
  )
  assert_true(
    generated.package_imports.contains(
      "\"LL124-Arch/amazon-ion-moonbit-core\" @ion",
    ),
  )

  let empty = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: EmptyStream, type: document, contains: []}",
  )
  assert_true(empty.source.contains("from_ion_document_EmptyStream"))
  assert_true(!empty.source.contains("ConversionError"))
}

///|
test "generate raw ordered sequence validators with occurrence ranges" {
  let generated = @ion-schema-codegen.generate_code(
    "$ion_schema_2_0 type::{name: OrderedList, type: list, ordered_elements:[int, {type: string, occurs: optional}, {type: bool, occurs: range::[1, 2]}]} type::{name: OrderedSexp, type: sexp, ordered_elements:[symbol, {type: int, occurs: 2}]} type::{name: OrderedDocument, type: document, ordered_elements:[string]}",
  )
  assert_true(
    generated.source.contains(
      "pub type OrderedList = Array[@ion_model.IonValue]",
    ),
  )
  assert_true(
    generated.source.contains("ion_schema_codegen_validate_ordered_OrderedList"),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_ordered_matches_OrderedSexp_1",
    ),
  )
  assert_true(
    generated.source.contains(
      "ion_schema_codegen_validate_ordered_OrderedDocument",
    ),
  )
}
