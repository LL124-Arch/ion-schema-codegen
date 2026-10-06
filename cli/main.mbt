///|
priv suberror CliError {
  CliError(String)
}

///|
impl Show for CliError with fn output(self, logger) {
  match self {
    CliError(message) => logger.write_string(message)
  }
}

///|
fn schema_error_message(error : @codegen.SchemaError) -> String {
  match error {
    @codegen.SchemaError::IonParse(message) => "Ion parse error: " + message
    @codegen.SchemaError::InvalidSchema(message) => "invalid schema: " + message
    @codegen.SchemaError::UnsupportedVersion(message) =>
      "unsupported schema version: " + message
    @codegen.SchemaError::UnsupportedFeature(message) =>
      "unsupported schema feature: " + message
    @codegen.SchemaError::DuplicateType(message) => "duplicate type: " + message
    @codegen.SchemaError::DuplicateField(type_name~, field_name~) =>
      "duplicate field " + type_name + "." + field_name
    @codegen.SchemaError::UnknownType(message) => "unknown type: " + message
    @codegen.SchemaError::CyclicTypeReference(message) =>
      "cyclic type reference: " + message
    @codegen.SchemaError::InvalidOccurs(message) =>
      "invalid field occurrence: " + message
    @codegen.SchemaError::InvalidIdentifier(message) =>
      "invalid generated identifier: " + message
    @codegen.SchemaError::IdentifierCollision(message) =>
      "generated identifier collision: " + message
  }
}

///|
async fn main {
  let args = @env.args()
  if args.length() != 3 {
    raise CliError(
      "usage: moon run --target native ./cli <schema.isl> <generated.mbt>",
    )
  }
  let input_path = args[1]
  let output_path = args[2]
  let generated = cli_generate_from_file(input_path)
  @fs.write_file(
    output_path,
    generated.source,
    create_mode=@fs.CreateMode::CreateOrTruncate,
  ) catch {
    _ => raise CliError("cannot write generated source: " + output_path)
  }
  @stdio.stdout.write("Generated \{output_path}\n")
  if generated.package_imports.length() > 0 {
    @stdio.stdout.write("Add these imports to the target package moon.pkg:\n")
    for package_import in generated.package_imports {
      @stdio.stdout.write("  \{package_import}\n")
    }
  }
}
