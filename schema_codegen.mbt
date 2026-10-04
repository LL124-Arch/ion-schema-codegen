///|
/// Generate MoonBit types and Ion conversions for the supported ISL 2.0 subset.
///
/// The returned package imports must be added to the target package's
/// moon.pkg file. Type names are converted to PascalCase; field names
/// lowercase an initial ASCII uppercase letter and replace hyphens with
/// underscores. Unsupported characters, reserved field names, and name
/// collisions are errors.
pub fn generate_code(source : String) -> GeneratedCode raise SchemaError {
  let schema = parse_schema(source)
  validate_type_references(schema.types)
  validate_codegen_subset(schema.types)
  let ordered_types = order_named_types(schema.types)

  let package_imports : Array[String] = []
  if uses_model_types(schema.types) || has_conversion_types(schema.types) {
    package_imports.push(
      "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
    )
  }
  if uses_bigint(schema.types) {
    package_imports.push("\"moonbitlang/core/bigint\"")
  }

  let output = StringBuilder()
  if has_conversion_types(schema.types) {
    write_conversion_error(output)
    output.write_string("\n")
    write_ion_type_helpers(output)
    if has_nested_conversion_types(schema.types) {
      output.write_string("\n")
      write_prefix_error_helper(output)
    }
    output.write_string("\n")
  }
  let mut first_type = true
  for named_type in ordered_types {
    if !first_type {
      output.write_string("\n")
    }
    first_type = false
    write_named_type(output, named_type, schema.types)
    match named_type.body {
      TypeBody::Struct(fields) => {
        output.write_string("\n")
        write_struct_conversions(output, named_type, fields, schema.types)
      }
      TypeBody::List(element_type) => {
        output.write_string("\n")
        write_list_conversions(output, named_type, element_type, schema.types)
      }
      _ => ()
    }
  }
  { source: output.to_string(), package_imports, }
}

///|
fn validate_codegen_subset(types : Array[NamedType]) -> Unit raise SchemaError {
  let generated_type_names : Array[(String, String)] = []
  let has_conversions = has_conversion_types(types)
  for named_type in types {
    let generated_name = moonbit_type_identifier(named_type.name)
    if is_builtin_output_type(generated_name) {
      raise SchemaError::InvalidIdentifier(
        "type name \{named_type.name} maps to built-in MoonBit type \{generated_name}",
      )
    }
    match find_generated_name(generated_type_names, generated_name) {
      Some((original, _)) =>
        raise SchemaError::IdentifierCollision(
          "type names \{original} and \{named_type.name} both map to \{generated_name}",
        )
      None => ()
    }
    generated_type_names.push((named_type.name, generated_name))

    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        validate_codegen_reference(type_ref, "type \{named_type.name}")
      TypeBody::Struct(fields) => {
        let generated_fields : Array[(String, String)] = []
        for field in fields {
          let generated_field = moonbit_field_identifier(
            field.name,
            "field \{named_type.name}.\{field.name}",
          )
          if is_moonbit_reserved_word(generated_field) {
            raise SchemaError::InvalidIdentifier(
              "field \{named_type.name}.\{field.name} maps to reserved MoonBit word \{generated_field}",
            )
          }
          match find_generated_name(generated_fields, generated_field) {
            Some((original, _)) =>
              raise SchemaError::IdentifierCollision(
                "fields \{named_type.name}.\{original} and \{named_type.name}.\{field.name} both map to \{generated_field}",
              )
            None => ()
          }
          generated_fields.push((field.name, generated_field))
          validate_codegen_reference(
            field.type_ref,
            "field \{named_type.name}.\{field.name}",
          )
        }
      }
      TypeBody::List(type_ref) =>
        validate_codegen_reference(type_ref, "element of \{named_type.name}")
    }
  }
  if has_conversions &&
    find_generated_name(generated_type_names, "ConversionError")
    is Some((original, _)) {
    raise SchemaError::IdentifierCollision(
      "type name \{original} maps to ConversionError, which is reserved for generated conversion errors",
    )
  }
}

///|
fn validate_codegen_reference(
  type_ref : TypeRef,
  context : String,
) -> Unit raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => ignore(moonbit_type_for_builtin(name, context))
    TypeRef::Named(_) => ()
  }
}

///|
fn write_named_type(
  output : StringBuilder,
  named_type : NamedType,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  output.write_string("///|\n")
  let generated_name = moonbit_type_identifier(named_type.name)
  match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => {
      output.write_string("pub type ")
      output.write_string(generated_name)
      output.write_string(" = ")
      output.write_string(
        moonbit_type_for_reference_in(
          type_ref,
          types,
          "type \{named_type.name}",
        ),
      )
      output.write_string("\n")
    }
    TypeBody::Struct(fields) => {
      output.write_string("pub(all) struct ")
      output.write_string(generated_name)
      if fields.length() == 0 {
        output.write_string(" {}\n")
        return
      }
      output.write_string(" {\n")
      for field in fields {
        output.write_string("  ")
        output.write_string(
          moonbit_field_identifier(
            field.name,
            "field \{named_type.name}.\{field.name}",
          ),
        )
        output.write_string(" : ")
        output.write_string(
          moonbit_type_for_reference_in(
            field.type_ref,
            types,
            "field \{named_type.name}.\{field.name}",
          ),
        )
        match field.occurrence {
          FieldOccurrence::Required => ()
          FieldOccurrence::Optional => output.write_string("?")
        }
        output.write_string("\n")
      }
      output.write_string("}\n")
    }
    TypeBody::List(element_type) => {
      output.write_string("pub type ")
      output.write_string(generated_name)
      output.write_string(" = Array[")
      output.write_string(
        moonbit_type_for_reference_in(
          element_type,
          types,
          "element of \{named_type.name}",
        ),
      )
      output.write_string("]\n")
    }
  }
}

///|
fn write_conversion_error(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\npub(all) suberror ConversionError {\n  TypeMismatch(path~ : String, expected~ : String, actual~ : String)\n  MissingRequiredField(path~ : String)\n  DuplicateField(path~ : String)\n  UnknownField(path~ : String)\n  UnknownSymbol(path~ : String, sid~ : Int)\n  NullNotAllowed(path~ : String)\n  AnnotatedValueNotSupported(path~ : String)\n}\n",
  )
}

///|
fn write_ion_type_helpers(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_kind_name(kind : @ion_model.IonNull) -> String {\n  match kind {\n    @ion_model.IonNull::Null => \"null\"\n    @ion_model.IonNull::Bool => \"bool\"\n    @ion_model.IonNull::Int => \"int\"\n    @ion_model.IonNull::Float => \"float\"\n    @ion_model.IonNull::Decimal => \"decimal\"\n    @ion_model.IonNull::Timestamp => \"timestamp\"\n    @ion_model.IonNull::Symbol => \"symbol\"\n    @ion_model.IonNull::String => \"string\"\n    @ion_model.IonNull::Blob => \"blob\"\n    @ion_model.IonNull::Clob => \"clob\"\n    @ion_model.IonNull::List => \"list\"\n    @ion_model.IonNull::Sexp => \"sexp\"\n    @ion_model.IonNull::Struct => \"struct\"\n  }\n}\n\n///|\nfn ion_schema_codegen_actual_type(value : @ion_model.IonValue) -> String {\n  let kind = value.kind()\n  match (value.is_null(), kind) {\n    (true, @ion_model.IonNull::Null) => \"null\"\n    (true, typed_kind) => \"null.\\{ion_schema_codegen_kind_name(typed_kind)}\"\n    (false, actual_kind) => ion_schema_codegen_kind_name(actual_kind)\n  }\n}\n",
  )
}

///|
fn write_prefix_error_helper(output : StringBuilder) -> Unit {
  output.write_string(
    "///|\nfn ion_schema_codegen_prefix_error(\n  error : ConversionError,\n  prefix : String,\n) -> ConversionError {\n  match error {\n    ConversionError::TypeMismatch(path~, expected~, actual~) =>\n      ConversionError::TypeMismatch(\n        path=prefix + path,\n        expected~,\n        actual~,\n      )\n    ConversionError::MissingRequiredField(path~) =>\n      ConversionError::MissingRequiredField(path=prefix + path)\n    ConversionError::DuplicateField(path~) =>\n      ConversionError::DuplicateField(path=prefix + path)\n    ConversionError::UnknownField(path~) =>\n      ConversionError::UnknownField(path=prefix + path)\n    ConversionError::UnknownSymbol(path~, sid~) =>\n      ConversionError::UnknownSymbol(path=prefix + path, sid~)\n    ConversionError::NullNotAllowed(path~) =>\n      ConversionError::NullNotAllowed(path=prefix + path)\n    ConversionError::AnnotatedValueNotSupported(path~) =>\n      ConversionError::AnnotatedValueNotSupported(path=prefix + path)\n  }\n}\n",
  )
}

///|
fn write_struct_conversions(
  output : StringBuilder,
  named_type : NamedType,
  fields : Array[FieldSpec],
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let value_local_prefix = generated_value_local_prefix(fields)
  output.write_string("///|\n/// Convert an Ion struct to ")
  output.write_string(generated_name)
  output.write_string(" with field-level diagnostics.\npub fn ")
  output.write_string(generated_name)
  output.write_string("::from_ion(\n  value : @ion_model.IonValue,\n) -> ")
  output.write_string(generated_name)
  output.write_string(" raise ConversionError {\n")
  output.write_string("  let type_path = \"")
  output.write_string(named_type.name)
  output.write_string("\"\n")
  output.write_string(
    "  if value.is_null() {\n    raise ConversionError::NullNotAllowed(path=type_path)\n  }\n",
  )
  output.write_string(
    "  if value.annotations().length() > 0 {\n    raise ConversionError::AnnotatedValueNotSupported(path=type_path)\n  }\n",
  )
  output.write_string(
    "  let input_fields = match value.without_annotations() {\n    @ion_model.IonValue::Struct(fields) => fields\n    _ =>\n      raise ConversionError::TypeMismatch(\n        path=type_path,\n        expected=\"struct\",\n        actual=ion_schema_codegen_actual_type(value),\n      )\n  }\n",
  )
  let mut index = 0
  for _field in fields {
    output.write_string("  let mut input_field_")
    output.write_string(index.to_string())
    output.write_string(" : @ion_model.IonValue? = None\n")
    index += 1
  }
  output.write_string("  for (field_symbol, field_value) in input_fields {\n")
  output.write_string("    match field_symbol.text_value() {\n")
  output.write_string("      Some(field_name) =>\n        match field_name {\n")
  index = 0
  for field in fields {
    output.write_string("          \"")
    output.write_string(field.name)
    output.write_string("\" => {\n            if input_field_")
    output.write_string(index.to_string())
    output.write_string(
      " is Some(_) {\n              raise ConversionError::DuplicateField(path=\"",
    )
    output.write_string(named_type.name)
    output.write_char('.')
    output.write_string(field.name)
    output.write_string("\")\n            }\n            input_field_")
    output.write_string(index.to_string())
    output.write_string(" = Some(field_value)\n          }\n")
    index += 1
  }
  output.write_string(
    "          _ => raise ConversionError::UnknownField(path=\"",
  )
  output.write_string(named_type.name)
  output.write_string(".\" + field_name)\n        }\n")
  output.write_string(
    "      None =>\n        raise ConversionError::UnknownSymbol(\n          path=\"",
  )
  output.write_string(named_type.name)
  output.write_string(
    ".<field>\",\n          sid=field_symbol.sid_value().unwrap_or(0),\n        )\n",
  )
  output.write_string("    }\n  }\n")

  index = 0
  for field in fields {
    let value_local = value_local_prefix + index.to_string()
    let ion_type_name = expected_ion_type(field.type_ref, types)
    let moonbit_base_type = moonbit_type_for_reference_in(
      field.type_ref,
      types,
      "field \{named_type.name}.\{field.name}",
    )
    let moonbit_type = match field.occurrence {
      FieldOccurrence::Optional => moonbit_base_type + "?"
      FieldOccurrence::Required => moonbit_base_type
    }
    let declaration = "  let " +
      value_local +
      " : " +
      moonbit_type +
      " = match input_field_" +
      index.to_string() +
      " {"
    if declaration.length() > 80 {
      output.write_string(
        "  let " +
        value_local +
        " : " +
        moonbit_type +
        " = match\n    input_field_" +
        index.to_string() +
        " {\n",
      )
    } else {
      output.write_string(declaration + "\n")
    }
    output.write_string(
      "    Some(field_value) => {\n      if field_value.annotations().length() > 0 {\n        raise ConversionError::AnnotatedValueNotSupported(path=\"",
    )
    output.write_string(named_type.name)
    output.write_char('.')
    output.write_string(field.name)
    output.write_string(
      "\")\n      }\n      if field_value.is_null() {\n        raise ConversionError::NullNotAllowed(path=\"",
    )
    output.write_string(named_type.name)
    output.write_char('.')
    output.write_string(field.name)
    output.write_string("\")\n      }\n")
    match resolve_type_ref(types, field.type_ref) {
      ResolvedType::Scalar(scalar_name) => {
        output.write_string(
          "      match field_value.without_annotations() {\n        ",
        )
        output.write_string(ion_value_variant(scalar_name))
        output.write_string("(converted_value) => ")
        match field.occurrence {
          FieldOccurrence::Optional =>
            output.write_string("Some(converted_value)")
          FieldOccurrence::Required => output.write_string("converted_value")
        }
        output.write_string(
          "\n        _ =>\n          raise ConversionError::TypeMismatch(\n            path=\"",
        )
        output.write_string(named_type.name)
        output.write_char('.')
        output.write_string(field.name)
        output.write_string("\",\n            expected=\"")
        output.write_string(ion_type_name)
        output.write_string(
          "\",\n            actual=ion_schema_codegen_actual_type(field_value),\n          )\n      }\n",
        )
      }
      ResolvedType::Struct(_) | ResolvedType::List(_) => {
        if is_optional_field(field.occurrence) {
          output.write_string("      Some(")
        } else {
          output.write_string("      ")
        }
        output.write_string(
          ion_from_expression(
            field.type_ref,
            "field_value",
            types,
            "\"" + named_type.name + "." + field.name + ".\"",
          ),
        )
        if is_optional_field(field.occurrence) {
          output.write_char(')')
        }
        output.write_string("\n")
      }
    }
    output.write_string("    }\n")
    match field.occurrence {
      FieldOccurrence::Optional => output.write_string("    None => None\n")
      FieldOccurrence::Required => {
        output.write_string(
          "    None => raise ConversionError::MissingRequiredField(path=\"",
        )
        output.write_string(named_type.name)
        output.write_char('.')
        output.write_string(field.name)
        output.write_string("\")\n")
      }
    }
    output.write_string("  }\n")
    index += 1
  }

  output.write_string("  {")
  if fields.length() > 0 {
    output.write_string("\n")
    index = 0
    for field in fields {
      let field_identifier = moonbit_field_identifier(
        field.name,
        "field \{named_type.name}.\{field.name}",
      )
      let value_local = value_local_prefix + index.to_string()
      output.write_string("    ")
      output.write_string(field_identifier)
      output.write_string(": ")
      output.write_string(value_local)
      output.write_string(",\n")
      index += 1
    }
    output.write_string("  ")
  }
  output.write_string("}\n}\n\n")

  output.write_string("///|\n/// Convert ")
  output.write_string(generated_name)
  output.write_string(" into an Ion struct in schema field order.\npub fn ")
  output.write_string(generated_name)
  output.write_string("::to_ion(self : ")
  output.write_string(generated_name)
  output.write_string(
    ") -> @ion_model.IonValue {\n  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []\n",
  )
  for field in fields {
    let field_identifier = moonbit_field_identifier(
      field.name,
      "field \{named_type.name}.\{field.name}",
    )
    match field.occurrence {
      FieldOccurrence::Required => {
        let ion_expression = ion_value_expression(
          field.type_ref,
          "self." +
          moonbit_field_identifier(
            field.name,
            "field \{named_type.name}.\{field.name}",
          ),
          types,
        )
        let pair = "(@ion_model.IonSymbol::from_text(\"" +
          field.name +
          "\"), " +
          ion_expression +
          ")"
        output.write_string("  output_fields.push(\n")
        if pair.length() + 5 > 80 {
          output.write_string("    (\n      @ion_model.IonSymbol::from_text(\"")
          output.write_string(field.name)
          output.write_string("\"),\n      ")
          output.write_string(ion_expression)
          output.write_string(",\n    ),\n  )\n")
        } else {
          output.write_string("    " + pair + ",\n  )\n")
        }
      }
      FieldOccurrence::Optional => {
        output.write_string("  match self.")
        output.write_string(field_identifier)
        output.write_string(
          " {\n    Some(field_value) =>\n      output_fields.push(\n        (\n          @ion_model.IonSymbol::from_text(\"",
        )
        output.write_string(field.name)
        output.write_string("\"),\n          ")
        output.write_string(
          ion_value_expression(field.type_ref, "field_value", types),
        )
        output.write_string(",\n        ),\n      )\n    None => ()\n  }\n")
      }
    }
  }
  output.write_string("  @ion_model.IonValue::Struct(output_fields)\n}\n")
}

///|
fn write_list_conversions(
  output : StringBuilder,
  named_type : NamedType,
  element_type : TypeRef,
  types : Array[NamedType],
) -> Unit raise SchemaError {
  let generated_name = moonbit_type_identifier(named_type.name)
  let element_moonbit_type = moonbit_type_for_reference_in(
    element_type,
    types,
    "element of \{named_type.name}",
  )
  let expected_type = expected_ion_type(element_type, types)
  output.write_string("///|\n/// Convert an Ion list to ")
  output.write_string(generated_name)
  output.write_string(" with element-level diagnostics.\npub fn ")
  output.write_string("from_ion_")
  output.write_string(generated_name)
  output.write_string("(\n  value : @ion_model.IonValue,\n) -> ")
  output.write_string(generated_name)
  output.write_string(" raise ConversionError {\n")
  output.write_string("  let type_path = \"")
  output.write_string(named_type.name)
  output.write_string("\"\n")
  output.write_string(
    "  if value.is_null() {\n    raise ConversionError::NullNotAllowed(path=type_path)\n  }\n",
  )
  output.write_string(
    "  if value.annotations().length() > 0 {\n    raise ConversionError::AnnotatedValueNotSupported(path=type_path)\n  }\n",
  )
  output.write_string(
    "  let input_elements = match value.without_annotations() {\n    @ion_model.IonValue::List(elements) => elements\n    _ =>\n      raise ConversionError::TypeMismatch(\n        path=type_path,\n        expected=\"list\",\n        actual=ion_schema_codegen_actual_type(value),\n      )\n  }\n",
  )
  output.write_string("  let converted : ")
  output.write_string(generated_name)
  output.write_string(" = []\n  let mut index = 0\n")
  output.write_string("  for element in input_elements {\n")
  output.write_string(
    "    let element_path = type_path + \"[\" + index.to_string() + \"]\"\n",
  )
  output.write_string(
    "    if element.annotations().length() > 0 {\n      raise ConversionError::AnnotatedValueNotSupported(path=element_path)\n    }\n",
  )
  output.write_string(
    "    if element.is_null() {\n      raise ConversionError::NullNotAllowed(path=element_path)\n    }\n",
  )
  output.write_string("    let item : ")
  output.write_string(element_moonbit_type)
  output.write_string(" = ")
  match resolve_type_ref(types, element_type) {
    ResolvedType::Scalar(scalar_name) => {
      output.write_string("match element.without_annotations() {\n      ")
      output.write_string(ion_value_variant(scalar_name))
      output.write_string(
        "(item) => item\n      _ =>\n        raise ConversionError::TypeMismatch(\n          path=element_path,\n          expected=\"",
      )
      output.write_string(expected_type)
      output.write_string(
        "\",\n          actual=ion_schema_codegen_actual_type(element),\n        )\n    }\n",
      )
    }
    ResolvedType::Struct(_) | ResolvedType::List(_) =>
      output.write_string(
        ion_from_expression(
          element_type, "element", types, "element_path + \".\"",
        ) +
        "\n",
      )
  }
  output.write_string(
    "    converted.push(item)\n    index += 1\n  }\n  converted\n}\n\n",
  )

  output.write_string("///|\n/// Convert ")
  output.write_string(generated_name)
  output.write_string(" into an Ion list.\npub fn ")
  output.write_string("to_ion_")
  output.write_string(generated_name)
  output.write_string("(items : ")
  output.write_string(generated_name)
  output.write_string(
    ") -> @ion_model.IonValue {\n  let output_elements : Array[@ion_model.IonValue] = []\n  for element in items {\n    output_elements.push(",
  )
  output.write_string(ion_value_expression(element_type, "element", types))
  output.write_string(
    ")\n  }\n  @ion_model.IonValue::List(output_elements)\n}\n",
  )
}

///|
fn generated_value_local_prefix(
  fields : Array[FieldSpec],
) -> String raise SchemaError {
  let mut prefix = "ion_schema_codegen_value_"
  let mut has_collision = true
  while has_collision {
    has_collision = false
    let mut value_index = 0
    for _field in fields {
      let local_name = prefix + value_index.to_string()
      let mut field_index = 0
      for field in fields {
        let field_identifier = moonbit_field_identifier(
          field.name,
          "field \{field.name}",
        )
        if field_identifier == local_name {
          has_collision = true
        }
        if "input_field_" + field_index.to_string() == local_name {
          has_collision = true
        }
        field_index += 1
      }
      value_index += 1
    }
    if has_collision {
      prefix = prefix + "_"
    }
  }
  prefix
}

///|
fn is_optional_field(occurrence : FieldOccurrence) -> Bool {
  match occurrence {
    FieldOccurrence::Optional => true
    FieldOccurrence::Required => false
  }
}

///|
fn ion_value_variant(name : String) -> String raise SchemaError {
  match name {
    "bool" => "@ion_model.IonValue::Bool"
    "int" => "@ion_model.IonValue::Int"
    "float" => "@ion_model.IonValue::Float"
    "decimal" => "@ion_model.IonValue::Decimal"
    "string" => "@ion_model.IonValue::String"
    "symbol" => "@ion_model.IonValue::Symbol"
    "timestamp" => "@ion_model.IonValue::Timestamp"
    "blob" => "@ion_model.IonValue::Blob"
    "clob" => "@ion_model.IonValue::Clob"
    _ =>
      raise SchemaError::UnsupportedFeature(
        "no Ion value mapping for scalar type \{name}",
      )
  }
}

///|
priv enum ResolvedType {
  Scalar(String)
  Struct(String)
  List(String)
}

///|
fn moonbit_type_for_reference_in(
  type_ref : TypeRef,
  types : Array[NamedType],
  context : String,
) -> String raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => moonbit_type_for_builtin(name, context)
    TypeRef::Named(name) => {
      ignore(find_named_type(types, name))
      moonbit_type_identifier(name)
    }
  }
}

///|
fn find_named_type(types : Array[NamedType], name : String) -> NamedType? {
  for named_type in types {
    if named_type.name == name {
      return Some(named_type)
    }
  }
  None
}

///|
fn resolve_type_ref(
  types : Array[NamedType],
  type_ref : TypeRef,
) -> ResolvedType raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => ResolvedType::Scalar(name)
    TypeRef::Named(name) =>
      match find_named_type(types, name) {
        Some(named_type) =>
          match named_type.body {
            TypeBody::Scalar(target) | TypeBody::Alias(target) =>
              resolve_type_ref(types, target)
            TypeBody::Struct(_) => ResolvedType::Struct(name)
            TypeBody::List(_) => ResolvedType::List(name)
          }
        None => raise SchemaError::UnknownType("unknown type \{name}")
      }
  }
}

///|
fn expected_ion_type(
  type_ref : TypeRef,
  types : Array[NamedType],
) -> String raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar(name) => name
    ResolvedType::Struct(_) => "struct"
    ResolvedType::List(_) => "list"
  }
}

///|
fn ion_from_expression(
  type_ref : TypeRef,
  value_expression : String,
  types : Array[NamedType],
  error_prefix : String,
) -> String raise SchemaError {
  let from_expression = match resolve_type_ref(types, type_ref) {
    ResolvedType::Struct(name) =>
      moonbit_type_identifier(name) + "::from_ion(" + value_expression + ")"
    ResolvedType::List(name) =>
      "from_ion_" + moonbit_type_identifier(name) + "(" + value_expression + ")"
    ResolvedType::Scalar(_) =>
      raise SchemaError::UnsupportedFeature(
        "internal named conversion requested for scalar type",
      )
  }
  "try " +
  from_expression +
  " catch { error =>\n  raise ion_schema_codegen_prefix_error(error, " +
  error_prefix +
  ")\n}"
}

///|
fn ion_value_expression(
  type_ref : TypeRef,
  value_expression : String,
  types : Array[NamedType],
) -> String raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar(name) =>
      ion_value_variant(name) + "(" + value_expression + ")"
    ResolvedType::Struct(name) =>
      moonbit_type_identifier(name) + "::to_ion(" + value_expression + ")"
    ResolvedType::List(name) =>
      "to_ion_" + moonbit_type_identifier(name) + "(" + value_expression + ")"
  }
}

///|
fn order_named_types(
  types : Array[NamedType],
) -> Array[NamedType] raise SchemaError {
  let ordered : Array[NamedType] = []
  let visited : Array[String] = []
  for named_type in types {
    visit_named_type(named_type.name, types, [], visited, ordered)
  }
  ordered
}

///|
fn visit_named_type(
  name : String,
  types : Array[NamedType],
  path : Array[String],
  visited : Array[String],
  ordered : Array[NamedType],
) -> Unit raise SchemaError {
  if contains_string(visited, name) {
    return
  }
  if contains_string(path, name) {
    let mut start = 0
    let mut index = 0
    for item in path {
      if item == name {
        start = index
        break
      }
      index += 1
    }
    let chain = StringBuilder()
    index = 0
    for item in path {
      if index >= start {
        if chain.to_string() != "" {
          chain.write_string(" -> ")
        }
        chain.write_string(item)
      }
      index += 1
    }
    chain.write_string(" -> ")
    chain.write_string(name)
    raise SchemaError::CyclicTypeReference(chain.to_string())
  }
  let named_type = match find_named_type(types, name) {
    Some(found) => found
    None => raise SchemaError::UnknownType("unknown type \{name}")
  }
  let next_path : Array[String] = []
  for item in path {
    next_path.push(item)
  }
  next_path.push(name)
  for dependency in referenced_type_names(named_type.body) {
    visit_named_type(dependency, types, next_path, visited, ordered)
  }
  visited.push(name)
  ordered.push(named_type)
}

///|
fn referenced_type_names(body : TypeBody) -> Array[String] {
  let names : Array[String] = []
  match body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match type_ref {
        TypeRef::Named(name) => names.push(name)
        TypeRef::Builtin(_) => ()
      }
    TypeBody::List(type_ref) =>
      match type_ref {
        TypeRef::Named(name) => names.push(name)
        TypeRef::Builtin(_) => ()
      }
    TypeBody::Struct(fields) =>
      for field in fields {
        match field.type_ref {
          TypeRef::Named(name) => names.push(name)
          TypeRef::Builtin(_) => ()
        }
      }
  }
  names
}

///|
fn moonbit_type_for_builtin(
  name : String,
  context : String,
) -> String raise SchemaError {
  match name {
    "bool" => "Bool"
    "int" => "@bigint.BigInt"
    "float" => "Float"
    "decimal" => "@ion_model.IonDecimal"
    "string" => "String"
    "symbol" => "@ion_model.IonSymbol"
    "timestamp" => "@ion_model.IonTimestamp"
    "blob" | "clob" => "Bytes"
    _ =>
      raise SchemaError::UnsupportedFeature(
        "no MoonBit type mapping for \{name} at \{context}",
      )
  }
}

///|
fn uses_bigint(types : Array[NamedType]) -> Bool raise SchemaError {
  for named_type in types {
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        if matches_int(resolve_type_ref(types, type_ref)) {
          return true
        }
      TypeBody::Struct(fields) =>
        for field in fields {
          if matches_int(resolve_type_ref(types, field.type_ref)) {
            return true
          }
        }
      TypeBody::List(type_ref) =>
        if matches_int(resolve_type_ref(types, type_ref)) {
          return true
        }
    }
  }
  false
}

///|
fn uses_model_types(types : Array[NamedType]) -> Bool raise SchemaError {
  for named_type in types {
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        if matches_model_type(resolve_type_ref(types, type_ref)) {
          return true
        }
      TypeBody::Struct(_) => return true
      TypeBody::List(_) => return true
    }
  }
  false
}

///|
fn has_conversion_types(types : Array[NamedType]) -> Bool {
  for named_type in types {
    match named_type.body {
      TypeBody::Struct(_) | TypeBody::List(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn has_nested_conversion_types(
  types : Array[NamedType],
) -> Bool raise SchemaError {
  for named_type in types {
    match named_type.body {
      TypeBody::Struct(fields) =>
        for field in fields {
          match resolve_type_ref(types, field.type_ref) {
            ResolvedType::Struct(_) | ResolvedType::List(_) => return true
            ResolvedType::Scalar(_) => ()
          }
        }
      TypeBody::List(element_type) =>
        match resolve_type_ref(types, element_type) {
          ResolvedType::Struct(_) | ResolvedType::List(_) => return true
          ResolvedType::Scalar(_) => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn matches_int(resolved : ResolvedType) -> Bool {
  match resolved {
    ResolvedType::Scalar("int") => true
    _ => false
  }
}

///|
fn matches_model_type(resolved : ResolvedType) -> Bool {
  match resolved {
    ResolvedType::Scalar("decimal" | "symbol" | "timestamp") => true
    _ => false
  }
}

///|
fn moonbit_type_identifier(name : String) -> String raise SchemaError {
  if name == "" {
    raise SchemaError::InvalidIdentifier("empty type name")
  }
  let output = StringBuilder()
  let mut first = true
  let mut capitalize = true
  let mut previous_separator = false
  for character in name {
    if character == '_' || character == '-' {
      if first || previous_separator {
        raise SchemaError::InvalidIdentifier(
          "type name \{name} has a leading or repeated separator",
        )
      }
      capitalize = true
      previous_separator = true
    } else if is_identifier_character(character) {
      if first && character.is_ascii_digit() {
        output.write_string("T_")
      } else if first && !character.is_ascii() {
        output.write_string("T_")
      }
      if capitalize && character.is_ascii_lowercase() {
        output.write_char(character.to_ascii_uppercase())
      } else {
        output.write_char(character)
      }
      first = false
      capitalize = false
      previous_separator = false
    } else {
      raise SchemaError::InvalidIdentifier(
        "type name \{name} contains a character that cannot be represented in a MoonBit identifier",
      )
    }
  }
  if previous_separator {
    raise SchemaError::InvalidIdentifier(
      "type name \{name} ends with a separator",
    )
  }
  output.to_string()
}

///|
fn moonbit_field_identifier(
  name : String,
  context : String,
) -> String raise SchemaError {
  if name == "" {
    raise SchemaError::InvalidIdentifier("\{context} has an empty name")
  }
  let output = StringBuilder()
  let mut first = true
  for character in name {
    if character == '-' {
      output.write_char('_')
      first = false
    } else if is_identifier_character(character) {
      if first && character.is_ascii_digit() {
        output.write_string("field_")
      }
      if first && character.is_ascii_uppercase() {
        output.write_char(character.to_ascii_lowercase())
      } else {
        output.write_char(character)
      }
      first = false
    } else {
      raise SchemaError::InvalidIdentifier(
        "\{context} contains a character that cannot be represented in a MoonBit identifier",
      )
    }
  }
  let result = output.to_string()
  if result == "_" {
    raise SchemaError::InvalidIdentifier(
      "\{context} maps to the reserved wildcard identifier _",
    )
  }
  result
}

///|
fn is_identifier_character(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '_' ||
  is_moonbit_non_ascii_identifier_character(character)
}

///|
fn is_moonbit_non_ascii_identifier_character(character : Char) -> Bool {
  let code = character.to_int()
  code
  is (0x00A1..=0x00AC
  | 0x00AE..=0x02AF
  | 0x1100..=0x11FF
  | 0x1E00..=0x1EFF
  | 0x2070..=0x209F
  | 0x2150..=0x218F
  | 0x2E80..=0x2EFF
  | 0x2FF0..=0x2FFF
  | 0x3001..=0x30FF
  | 0x31C0..=0x9FFF
  | 0xAC00..=0xD7FF
  | 0xF900..=0xFAFF
  | 0xFE00..=0xFE0F
  | 0xFE30..=0xFE4F
  | 0x1F000..=0x1FBFF
  | 0x20000..=0x2A6DF
  | 0x2A700..=0x2EBEF
  | 0x2F800..=0x2FA1F
  | 0x30000..=0x323AF
  | 0xE0100..=0xE01EF)
}

///|
fn is_builtin_output_type(name : String) -> Bool {
  name == "Bool" ||
  name == "Float" ||
  name == "String" ||
  name == "Bytes" ||
  name == "Option"
}

///|
fn is_moonbit_reserved_word(name : String) -> Bool {
  contains_string(
    [
      "as", "else", "extern", "fn", "if", "let", "const", "match", "using", "mut",
      "type", "struct", "enum", "extenum", "trait", "derive", "while", "break", "continue",
      "import", "return", "throw", "raise", "try", "catch", "pub", "priv", "proof_assert",
      "proof_let", "readonly", "true", "false", "test", "loop", "for", "in", "impl",
      "with", "guard", "async", "is", "suberror", "and", "letrec", "enumview", "noraise",
      "nocancel", "defer", "lexscan", "where", "declare", "nobreak", "extend", "try!",
      "guard!", "module", "move", "ref", "static", "super", "unsafe", "use", "await",
      "dyn", "abstract", "do", "final", "macro", "override", "typeof", "virtual",
      "yield", "local", "method", "alias", "assert", "package", "recur", "isnot",
      "define", "downcast", "inherit", "member", "namespace", "upcast", "void", "lazy",
      "include", "mixin", "protected", "sealed", "constructor", "atomic", "volatile",
      "anyframe", "anytype", "asm", "comptime", "errdefer", "export", "opaque", "orelse",
      "resume", "threadlocal", "unreachable", "dynclass", "dynobj", "dynrec", "var",
      "finally", "noasync", "assume",
    ],
    name,
  )
}

///|
fn find_generated_name(
  names : Array[(String, String)],
  generated_name : String,
) -> (String, String)? {
  for item in names {
    if item.1 == generated_name {
      return Some(item)
    }
  }
  None
}
