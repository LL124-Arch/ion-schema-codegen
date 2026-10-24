///|
fn cli_validation_error(error : @codegen.ValidationError) -> String {
  match error {
    @codegen.ValidationError::UnknownType(name) =>
      "unknown validation type: " + name
    @codegen.ValidationError::InvalidLimits(message) =>
      "invalid validation limits: " + message
    @codegen.ValidationError::IonInput(message) =>
      "invalid Ion input: " + message
    @codegen.ValidationError::InputKind(message) => message
  }
}

///|
// Show the declared type and its file rather than resolver implementation names.
fn cli_validation_json(
  report : @codegen.ValidationReport,
  documents : Array[CliSchemaDocument],
) -> Json {
  let json = report.to_json()
  match json {
    Object(fields) =>
      match fields.get("diagnostics") {
        Some(Array(diagnostics)) =>
          for index in 0..<diagnostics.length() {
            match diagnostics[index] {
              Object(diagnostic) =>
                for document in documents {
                  for name in document.local_names {
                    if cli_emitted_type_name(document, name) ==
                      report.diagnostics[index].type_name {
                      diagnostic.set("type", name.to_json())
                      diagnostic.set("schema", document.path.to_json())
                    }
                  }
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  json
}

///|
async fn cli_validate_from_file(
  schema_path : String,
  type_name : String,
  data_path : String,
  document : Bool,
) -> (@codegen.ValidationReport, Json) raise CliError {
  let documents = cli_resolve_documents(schema_path)
  let flattened = cli_schema_values(documents)
  let validator = @codegen.SchemaValidator::from_ion_values(flattened) catch {
    error =>
      raise CliError(
        "schema validation setup failed: " + schema_error_message(error),
      )
  }
  let data : &@io.Data = @fs.read_file(data_path) catch {
    _ => raise CliError("cannot read Ion input: " + data_path)
  }
  let text = data.text() catch {
    _ => raise CliError("Ion input is not valid UTF-8: " + data_path)
  }
  let report = try {
    if document {
      validator.validate_document_text(type_name, text)
    } else {
      validator.validate_text(type_name, text)
    }
  } catch {
    error => raise CliError(cli_validation_error(error))
  }
  (report, cli_validation_json(report, documents))
}
