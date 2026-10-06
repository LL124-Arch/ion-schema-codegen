///|
priv struct CliSchemaImport {
  id : String
  imported_type : String?
  as_name : String?
  target_path : String
}

///|
priv struct CliSchemaDocument {
  path : String
  prefix : String
  values : Array[@model.IonValue]
  imports : Array[CliSchemaImport]
  local_names : Array[String]
}

///|
fn cli_error_text(error : CliError) -> String {
  match error {
    CliError(message) => message
  }
}

///|
fn cli_annotation_is(value : @model.IonValue, expected : String) -> Bool {
  for annotation in value.annotations() {
    if annotation.text_value() == Some(expected) {
      return true
    }
  }
  false
}

///|
fn cli_symbol_text(value : @model.IonValue) -> String? {
  match value.without_annotations() {
    @model.IonValue::Symbol(symbol) => symbol.text_value()
    @model.IonValue::String(text) => Some(text)
    _ => None
  }
}

///|
fn cli_import_text(
  name : String,
  value : @model.IonValue,
  path : String,
) -> String raise CliError {
  if value.annotations().length() != 0 {
    raise CliError(
      "annotated import field " + name + " is not supported in " + path,
    )
  }
  match (name, value.without_annotations()) {
    ("id", @model.IonValue::String(text)) => text
    ("type" | "as", @model.IonValue::Symbol(symbol)) =>
      match symbol.text_value() {
        Some(text) => text
        None =>
          raise CliError("unresolved import field " + name + " in " + path)
      }
    ("id", _) => raise CliError("import id must be a string in " + path)
    _ => raise CliError("import field " + name + " must be a symbol in " + path)
  }
}

///|
fn cli_find_text(values : Array[(String, String)], key : String) -> String? {
  for (name, value) in values {
    if name == key {
      return Some(value)
    }
  }
  None
}

///|
fn cli_single_field(
  value : @model.IonValue,
  name : String,
  context : String,
) -> @model.IonValue? raise CliError {
  let fields = value.get_fields(name)
  match fields {
    [] => None
    [field] => Some(field)
    _ => raise CliError("duplicate " + name + " field in " + context)
  }
}

///|
fn cli_import_entry(
  value : @model.IonValue,
  path : String,
) -> CliSchemaImport raise CliError {
  let context = "schema import in " + path
  let fields = match value.without_annotations() {
    @model.IonValue::Struct(fields) => fields
    _ => raise CliError("import entry must be a struct in " + path)
  }
  if value.annotations().length() != 0 {
    raise CliError("annotated import entries are not supported in " + path)
  }
  let mut id : String? = None
  let mut imported_type : String? = None
  let mut as_name : String? = None
  for (symbol, field_value) in fields {
    let name = match symbol.text_value() {
      Some(name) => name
      None => raise CliError("unresolved import field name in " + path)
    }
    let text = match name {
      "id" | "type" | "as" => Some(cli_import_text(name, field_value, path))
      _ => raise CliError("unsupported import field " + name + " in " + path)
    }
    let text = match text {
      Some(text) => text
      None =>
        raise CliError(
          "import field " + name + " must be a string or symbol in " + path,
        )
    }
    match name {
      "id" => {
        if id is Some(_) {
          raise CliError("duplicate id field in " + context)
        }
        id = Some(text)
      }
      "type" => {
        if imported_type is Some(_) {
          raise CliError("duplicate type field in " + context)
        }
        imported_type = Some(text)
      }
      "as" => {
        if as_name is Some(_) {
          raise CliError("duplicate as field in " + context)
        }
        as_name = Some(text)
      }
      _ => ()
    }
  }
  let id = match id {
    Some(id) if id != "" => id
    Some(_) => raise CliError("import id must not be empty in " + path)
    None => raise CliError("import id is required in " + path)
  }
  if as_name is Some(_) && imported_type is None {
    raise CliError("as requires a selected type import in " + path)
  }
  { id, imported_type, as_name, target_path: "", }
}

///|
fn cli_schema_imports(
  values : Array[@model.IonValue],
  path : String,
) -> Array[CliSchemaImport] raise CliError {
  let imports : Array[CliSchemaImport] = []
  let mut header_count = 0
  let mut saw_type = false
  let mut saw_footer = false
  let mut value_index = 0
  for value in values {
    if value_index == 0 {
      value_index += 1
      continue
    }
    if saw_footer {
      raise CliError("schema_footer must be the final value in " + path)
    }
    if cli_annotation_is(value, "schema_header") {
      match value.annotations() {
        [annotation] if annotation.text_value() == Some("schema_header") => ()
        _ =>
          raise CliError(
            "schema_header must have only its ISL annotation in " + path,
          )
      }
      let header_fields = match value.without_annotations() {
        @model.IonValue::Struct(fields) => fields
        _ => raise CliError("schema_header must be a struct in " + path)
      }
      for (symbol, _) in header_fields {
        match symbol.text_value() {
          Some("imports") => ()
          Some(name) =>
            raise CliError(
              "unsupported schema_header field " + name + " in " + path,
            )
          None =>
            raise CliError("unresolved schema_header field name in " + path)
        }
      }
      header_count += 1
      if header_count > 1 {
        raise CliError("schema_header appears more than once in " + path)
      }
      if saw_type || saw_footer {
        raise CliError("schema_header must precede types in " + path)
      }
      match cli_single_field(value, "imports", "schema_header in " + path) {
        Some(imports_value) => {
          let entries = match imports_value.without_annotations() {
            @model.IonValue::List(entries) => entries
            _ =>
              raise CliError("schema_header imports must be a list in " + path)
          }
          if imports_value.annotations().length() != 0 {
            raise CliError(
              "annotated schema imports are not supported in " + path,
            )
          }
          for entry in entries {
            imports.push(cli_import_entry(entry, path))
          }
        }
        None => ()
      }
    } else if cli_annotation_is(value, "type") {
      match value.annotations() {
        [annotation] if annotation.text_value() == Some("type") => ()
        _ =>
          raise CliError(
            "type definition must have only its ISL annotation in " + path,
          )
      }
      saw_type = true
    } else if cli_annotation_is(value, "schema_footer") {
      match value.annotations() {
        [annotation] if annotation.text_value() == Some("schema_footer") => ()
        _ =>
          raise CliError(
            "schema_footer must have only its ISL annotation in " + path,
          )
      }
      match value.without_annotations() {
        @model.IonValue::Struct([]) => ()
        @model.IonValue::Struct(_) =>
          raise CliError("schema_footer must be empty in " + path)
        _ => raise CliError("schema_footer must be a struct in " + path)
      }
      if saw_footer {
        raise CliError("schema_footer appears more than once in " + path)
      }
      saw_footer = true
    } else {
      match value.without_annotations() {
        @model.IonValue::Symbol(symbol) if symbol.text_value() is Some(version) &&
          version.has_prefix("$ion_schema_") =>
          raise CliError("Ion Schema version marker must be first in " + path)
        _ => raise CliError("unsupported top-level value in " + path)
      }
    }
    value_index += 1
  }
  imports
}

///|
fn cli_schema_type_names(
  values : Array[@model.IonValue],
  path : String,
) -> Array[String] raise CliError {
  let names : Array[String] = []
  for value in values {
    if cli_annotation_is(value, "type") {
      let name_value = match
        cli_single_field(value, "name", "type definition in " + path) {
        Some(name) => name
        None => raise CliError("type definition is missing name in " + path)
      }
      let name = match name_value.without_annotations() {
        @model.IonValue::Symbol(symbol) => symbol.text_value()
        _ => None
      }
      let name = match name {
        Some(name) if name != "" => name
        _ => raise CliError("type name must be a non-empty symbol in " + path)
      }
      if names.contains(name) {
        raise CliError("duplicate type " + name + " in " + path)
      }
      names.push(name)
    }
  }
  names
}

///|
fn cli_normalize_path(path : String) -> String {
  let output = StringBuilder()
  for character in path {
    output.write_char(if character == '\\' { '/' } else { character })
  }
  output.to_string()
}

///|
fn cli_path_directory(path : String) -> String {
  let segments = cli_normalize_path(path).split("/").to_array()
  if segments.length() <= 1 {
    return "."
  }
  let parent = segments[:segments.length() - 1].to_owned()
  let directory = parent.join("/")
  if directory == "" {
    "/"
  } else {
    directory
  }
}

///|
fn cli_relative_import_path(
  id : String,
  importer : String,
) -> String raise CliError {
  let normalized = cli_normalize_path(id)
  if normalized.has_prefix("/") || normalized.contains(":") {
    raise CliError("import path must be relative to " + importer + ": " + id)
  }
  cli_normalize_path(cli_path_directory(importer) + "/" + normalized)
}

///|
fn cli_document_index(
  documents : Array[CliSchemaDocument],
  path : String,
) -> Int? {
  let mut index = 0
  for document in documents {
    if document.path == path {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn cli_path_in(paths : Array[String], path : String) -> Bool {
  for item in paths {
    if item == path {
      return true
    }
  }
  false
}

///|
async fn cli_load_document(
  requested_path : String,
  documents : Array[CliSchemaDocument],
  active_paths : Array[String],
) -> String raise CliError {
  let path = @fs.realpath(requested_path) catch {
    _ => raise CliError("cannot resolve schema file: " + requested_path)
  }
  if cli_path_in(active_paths, path) {
    let chain = active_paths.copy()
    chain.push(path)
    raise CliError("schema import cycle: " + chain.join(" -> "))
  }
  match cli_document_index(documents, path) {
    Some(_) => return path
    None => ()
  }
  let input_data : &@io.Data = @fs.read_file(path) catch {
    _ => raise CliError("cannot read schema file: " + path)
  }
  let source = input_data.text() catch {
    _ => raise CliError("schema file is not valid UTF-8: " + path)
  }
  let values = @ion.parse_text(source) catch {
    error =>
      raise CliError("Ion parse error in " + path + ": " + error.summary())
  }
  match values {
    [first, ..] =>
      match first.without_annotations() {
        @model.IonValue::Symbol(symbol) if symbol.text_value() ==
          Some("$ion_schema_2_0") => ()
        @model.IonValue::Symbol(symbol) if symbol.text_value() is Some(_) =>
          raise CliError("unsupported Ion Schema version in " + path)
        _ => raise CliError("missing $ion_schema_2_0 marker in " + path)
      }
    [] => raise CliError("missing $ion_schema_2_0 marker in " + path)
  }
  let imports = cli_schema_imports(values, path)
  let local_names = cli_schema_type_names(values, path)
  let index = documents.length()
  let prefix = if index == 0 {
    ""
  } else {
    "Imported" + index.to_string() + "_"
  }
  documents.push({ path, prefix, values, imports, local_names, })
  active_paths.push(path)
  let resolved_imports : Array[CliSchemaImport] = []
  for imported in imports {
    let requested_import = cli_relative_import_path(imported.id, path)
    let target_path = cli_load_document(
      requested_import, documents, active_paths,
    ) catch {
      error =>
        raise CliError(
          "import " +
          imported.id +
          " declared in " +
          path +
          " failed: " +
          cli_error_text(error),
        )
    }
    resolved_imports.push({ ..imported, target_path, })
  }
  let _ = active_paths.pop()
  documents[index] = { ..documents[index], imports: resolved_imports, }
  path
}

///|
fn cli_emitted_type_name(document : CliSchemaDocument, name : String) -> String {
  document.prefix + name
}

///|
fn cli_scope(
  document : CliSchemaDocument,
  documents : Array[CliSchemaDocument],
) -> Array[(String, String)] raise CliError {
  let scope : Array[(String, String)] = []
  for local_name in document.local_names {
    scope.push((local_name, cli_emitted_type_name(document, local_name)))
  }
  for imported in document.imports {
    let target_index = match
      cli_document_index(documents, imported.target_path) {
      Some(index) => index
      None =>
        raise CliError(
          "internal error resolving import " +
          imported.id +
          " from " +
          document.path,
        )
    }
    let target = documents[target_index]
    let selected = match imported.imported_type {
      Some(name) => {
        if !target.local_names.contains(name) {
          raise CliError(
            "type " +
            name +
            " imported by " +
            document.path +
            " is not declared in " +
            target.path,
          )
        }
        [name]
      }
      None => target.local_names
    }
    for imported_name in selected {
      let visible_name = match imported.as_name {
        Some(as_name) => as_name
        None => imported_name
      }
      if cli_find_text(scope, visible_name) is Some(_) {
        raise CliError(
          "imported type name " +
          visible_name +
          " conflicts in " +
          document.path,
        )
      }
      scope.push((visible_name, cli_emitted_type_name(target, imported_name)))
    }
  }
  scope
}

///|
fn cli_rewrite_reference(
  value : @model.IonValue,
  scope : Array[(String, String)],
) -> @model.IonValue {
  let rewritten = match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(name) =>
          match cli_find_text(scope, name) {
            Some(target) =>
              @model.IonValue::Symbol(@model.IonSymbol::from_text(target))
            None => value.without_annotations()
          }
        None => value.without_annotations()
      }
    _ => value.without_annotations()
  }
  rewritten.with_annotations(value.annotations())
}

///|
fn cli_rewrite_argument(
  value : @model.IonValue,
  scope : Array[(String, String)],
) -> @model.IonValue {
  match value.without_annotations() {
    @model.IonValue::Struct(fields) => {
      let rewritten_fields : Array[(@model.IonSymbol, @model.IonValue)] = []
      for (symbol, field_value) in fields {
        let rewritten_value = if symbol.text_value() == Some("type") {
          cli_rewrite_reference(field_value, scope)
        } else {
          field_value
        }
        rewritten_fields.push((symbol, rewritten_value))
      }
      @model.IonValue::Struct(rewritten_fields).with_annotations(
        value.annotations(),
      )
    }
    _ => cli_rewrite_reference(value, scope)
  }
}

///|
fn cli_rewrite_fields(
  value : @model.IonValue,
  scope : Array[(String, String)],
) -> @model.IonValue {
  match value.without_annotations() {
    @model.IonValue::Struct(fields) => {
      let rewritten_fields : Array[(@model.IonSymbol, @model.IonValue)] = []
      for (symbol, field_value) in fields {
        rewritten_fields.push(
          (symbol, cli_rewrite_argument(field_value, scope)),
        )
      }
      @model.IonValue::Struct(rewritten_fields).with_annotations(
        value.annotations(),
      )
    }
    _ => value
  }
}

///|
fn cli_rewrite_ordered_elements(
  value : @model.IonValue,
  scope : Array[(String, String)],
) -> @model.IonValue {
  match value.without_annotations() {
    @model.IonValue::List(elements) => {
      let rewritten : Array[@model.IonValue] = []
      for element in elements {
        rewritten.push(cli_rewrite_argument(element, scope))
      }
      @model.IonValue::List(rewritten).with_annotations(value.annotations())
    }
    _ => value
  }
}

///|
fn cli_rewrite_type(
  value : @model.IonValue,
  name : String,
  scope : Array[(String, String)],
) -> @model.IonValue {
  match value.without_annotations() {
    @model.IonValue::Struct(fields) => {
      let rewritten_fields : Array[(@model.IonSymbol, @model.IonValue)] = []
      for (symbol, field_value) in fields {
        let field_name = symbol.text_value()
        let rewritten_value = match field_name {
          Some("name") =>
            @model.IonValue::Symbol(@model.IonSymbol::from_text(name))
          Some("type") => cli_rewrite_reference(field_value, scope)
          Some("element") => cli_rewrite_argument(field_value, scope)
          Some("ordered_elements") =>
            cli_rewrite_ordered_elements(field_value, scope)
          Some("fields") => cli_rewrite_fields(field_value, scope)
          _ => field_value
        }
        rewritten_fields.push((symbol, rewritten_value))
      }
      @model.IonValue::Struct(rewritten_fields).with_annotations(
        value.annotations(),
      )
    }
    _ => value
  }
}

///|
fn cli_type_definition(name : String, target : String) -> @model.IonValue {
  @model.IonValue::Struct([
    (
      @model.IonSymbol::from_text("name"),
      @model.IonValue::Symbol(@model.IonSymbol::from_text(name)),
    ),
    (
      @model.IonSymbol::from_text("type"),
      @model.IonValue::Symbol(@model.IonSymbol::from_text(target)),
    ),
  ]).with_annotations([@model.IonSymbol::from_text("type")])
}

///|
fn cli_schema_values(
  documents : Array[CliSchemaDocument],
) -> Array[@model.IonValue] raise CliError {
  if documents.length() == 0 {
    raise CliError("no schema documents were loaded")
  }
  let output : Array[@model.IonValue] = [
    @model.IonValue::Symbol(@model.IonSymbol::from_text("$ion_schema_2_0")),
  ]
  let root = documents[0]

  // Keep root header fields other than imports so the library validator can
  // continue to reject unsupported schema metadata.
  for value in root.values {
    if cli_annotation_is(value, "schema_header") {
      let fields : Array[(@model.IonSymbol, @model.IonValue)] = []
      for (symbol, field_value) in value.fields() {
        if symbol.text_value() != Some("imports") {
          fields.push((symbol, field_value))
        }
      }
      output.push(
        @model.IonValue::Struct(fields).with_annotations(value.annotations()),
      )
    }
  }

  // Emit every imported document under a stable private namespace. Each file
  // gets a fresh lexical scope containing only its own declarations and its
  // direct imports.
  let mut document_index = 1
  while document_index < documents.length() {
    let document = documents[document_index]
    let scope = cli_scope(document, documents)
    for value in document.values {
      if cli_annotation_is(value, "type") {
        let original_name = match
          cli_single_field(value, "name", "type in " + document.path) {
          Some(name_value) => cli_symbol_text(name_value).unwrap_or("")
          None => ""
        }
        output.push(
          cli_rewrite_type(
            value,
            cli_emitted_type_name(document, original_name),
            scope,
          ),
        )
      }
    }
    document_index += 1
  }

  // Make only direct root imports visible to generated callers.
  let root_scope = cli_scope(root, documents)
  for (visible_name, emitted_name) in root_scope {
    if !root.local_names.contains(visible_name) {
      output.push(cli_type_definition(visible_name, emitted_name))
    }
  }

  for value in root.values {
    if cli_annotation_is(value, "type") {
      let original_name = match
        cli_single_field(value, "name", "type in " + root.path) {
        Some(name_value) => cli_symbol_text(name_value).unwrap_or("")
        None => ""
      }
      output.push(cli_rewrite_type(value, original_name, root_scope))
    }
  }
  for value in root.values {
    if cli_annotation_is(value, "schema_footer") {
      output.push(value)
    }
  }
  output
}

///|
async fn cli_generate_from_file(
  input_path : String,
) -> @codegen.GeneratedCode raise CliError {
  let documents : Array[CliSchemaDocument] = []
  let active_paths : Array[String] = []
  let _ = cli_load_document(input_path, documents, active_paths)
  for document in documents {
    let _ = cli_scope(document, documents)
  }
  let flattened = cli_schema_values(documents)
  @codegen.generate_code_from_ion_values(flattened) catch {
    error => {
      let paths : Array[String] = []
      for document in documents {
        paths.push(document.path)
      }
      let summary = schema_error_message(error)
      raise CliError(
        "schema generation failed for " + paths.join(", ") + ": " + summary,
      )
    }
  }
}
