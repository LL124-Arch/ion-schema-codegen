///|
/// Generate MoonBit type declarations for the supported ISL 2.0 subset.
///
/// The returned package imports must be added to the target package's
/// moon.pkg file. Conversion functions and list types are handled in later
/// development batches. Type names are converted to PascalCase; field names
/// lowercase an initial ASCII uppercase letter and replace hyphens with
/// underscores. Unsupported characters, reserved field names, and name
/// collisions are errors.
pub fn generate_code(source : String) -> GeneratedCode raise SchemaError {
  let schema = parse_schema(source)
  validate_type_references(schema.types)
  validate_codegen_subset(schema.types)

  let package_imports : Array[String] = []
  if uses_model_types(schema.types) {
    package_imports.push(
      "\"LL124-Arch/amazon-ion-moonbit-core/format_model\" @ion_model",
    )
  }
  if uses_bigint(schema.types) {
    package_imports.push("\"moonbitlang/core/bigint\"")
  }

  let output = StringBuilder()
  let mut first_type = true
  for named_type in schema.types {
    if !first_type {
      output.write_string("\n")
    }
    first_type = false
    write_named_type(output, named_type)
  }
  { source: output.to_string(), package_imports, }
}

///|
fn validate_codegen_subset(types : Array[NamedType]) -> Unit raise SchemaError {
  let generated_type_names : Array[(String, String)] = []
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
      TypeBody::List(_) =>
        raise SchemaError::UnsupportedFeature(
          "list code generation is not supported yet: type \{named_type.name}",
        )
    }
  }
}

///|
fn validate_codegen_reference(
  type_ref : TypeRef,
  context : String,
) -> Unit raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => ignore(moonbit_type_for_builtin(name, context))
    TypeRef::Named(name) =>
      raise SchemaError::UnsupportedFeature(
        "named type code generation is not supported yet: \{name} at \{context}",
      )
  }
}

///|
fn write_named_type(
  output : StringBuilder,
  named_type : NamedType,
) -> Unit raise SchemaError {
  output.write_string("///|\n")
  let generated_name = moonbit_type_identifier(named_type.name)
  match named_type.body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => {
      output.write_string("pub type ")
      output.write_string(generated_name)
      output.write_string(" = ")
      output.write_string(
        moonbit_type_for_reference(type_ref, "type \{named_type.name}"),
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
          moonbit_type_for_reference(
            field.type_ref,
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
    TypeBody::List(_) =>
      raise SchemaError::UnsupportedFeature(
        "list code generation is not supported yet: type \{named_type.name}",
      )
  }
}

///|
fn moonbit_type_for_reference(
  type_ref : TypeRef,
  context : String,
) -> String raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) => moonbit_type_for_builtin(name, context)
    TypeRef::Named(name) =>
      raise SchemaError::UnsupportedFeature(
        "named type code generation is not supported yet: \{name} at \{context}",
      )
  }
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
fn uses_bigint(types : Array[NamedType]) -> Bool {
  for named_type in types {
    match named_type.body {
      TypeBody::Scalar(TypeRef::Builtin("int"))
      | TypeBody::Alias(TypeRef::Builtin("int")) => return true
      TypeBody::Struct(fields) =>
        for field in fields {
          match field.type_ref {
            TypeRef::Builtin("int") => return true
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn uses_model_types(types : Array[NamedType]) -> Bool {
  for named_type in types {
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        if uses_model_type(type_ref) {
          return true
        }
      TypeBody::Struct(fields) =>
        for field in fields {
          if uses_model_type(field.type_ref) {
            return true
          }
        }
      TypeBody::List(_) => ()
    }
  }
  false
}

///|
fn uses_model_type(type_ref : TypeRef) -> Bool {
  match type_ref {
    TypeRef::Builtin("decimal" | "symbol" | "timestamp") => true
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
