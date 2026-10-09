///|
/// Check an ISL 2.0 document against the supported code-generation subset.
///
/// This validates syntax and references only. It does not validate Ion values
/// against the schema or generate MoonBit source.
pub fn check_schema(source : String) -> Unit raise SchemaError {
  let schema = parse_schema(source)
  validate_type_references(schema.types)
}

///|
fn parse_schema(source : String) -> Schema raise SchemaError {
  let values = @ion.parse_text(source) catch {
    error => raise SchemaError::IonParse(error.summary())
  }
  parse_schema_values(values)
}

///|
fn parse_schema_values(
  values : Array[@model.IonValue],
) -> Schema raise SchemaError {
  let rest = match values {
    [first, .. rest] =>
      match first.without_annotations() {
        @model.IonValue::Symbol(symbol) =>
          match symbol.text_value() {
            Some("$ion_schema_2_0") => rest
            Some(version) if version.has_prefix("$ion_schema_") =>
              raise SchemaError::UnsupportedVersion(
                "expected $ion_schema_2_0, found \{version}",
              )
            _ if has_late_schema_version(rest) =>
              raise SchemaError::InvalidSchema(
                "the Ion Schema version marker must be the first value",
              )
            _ =>
              raise SchemaError::UnsupportedVersion(
                "missing $ion_schema_2_0 version marker",
              )
          }
        _ if has_late_schema_version(rest) =>
          raise SchemaError::InvalidSchema(
            "the Ion Schema version marker must be the first value",
          )
        _ =>
          raise SchemaError::UnsupportedVersion(
            "missing $ion_schema_2_0 version marker",
          )
      }
    [] =>
      raise SchemaError::UnsupportedVersion(
        "missing $ion_schema_2_0 version marker",
      )
  }

  let types : Array[NamedType] = []
  let mut saw_header = false
  let mut saw_type = false
  let mut saw_footer = false
  for value in rest {
    if saw_footer {
      raise SchemaError::InvalidSchema(
        "schema_footer must be the final schema value",
      )
    }
    match value.without_annotations() {
      @model.IonValue::Symbol(symbol) if is_schema_version_symbol(symbol) =>
        raise SchemaError::InvalidSchema(
          "the Ion Schema version marker must be the first value",
        )
      _ => ()
    }
    if has_annotation(value, "schema_header") {
      if saw_header {
        raise SchemaError::InvalidSchema("schema_header may appear only once")
      }
      if saw_type {
        raise SchemaError::InvalidSchema(
          "schema_header must appear before type definitions",
        )
      }
      saw_header = true
      validate_schema_header(value)
    } else if has_annotation(value, "schema_footer") {
      saw_footer = true
      validate_schema_footer(value)
    } else if has_annotation(value, "type") {
      saw_type = true
      validate_type_annotations(value)
      let named_type = parse_named_type(value, types, false)
      if named_type.name.has_prefix("ion_schema_codegen_internal_inline_") {
        raise SchemaError::InvalidSchema(
          "type names beginning with ion_schema_codegen_internal_inline_ are reserved",
        )
      }
      if is_known_builtin(named_type.name) {
        raise SchemaError::InvalidSchema(
          "type name conflicts with a built-in type: \{named_type.name}",
        )
      }
      if contains_type(types, named_type.name) {
        raise SchemaError::DuplicateType(named_type.name)
      }
      types.push(named_type)
    } else {
      raise SchemaError::UnsupportedFeature(
        "top-level values must be type definitions, schema_header, or schema_footer",
      )
    }
  }

  { types, }
}

///|
fn parse_named_type(
  value : @model.IonValue,
  types : Array[NamedType],
  is_inline : Bool,
) -> NamedType raise SchemaError {
  let name_value = required_single_field(value, "name", "type definition")
  let name = symbol_text(name_value, "type name")
  if name == "" {
    raise SchemaError::InvalidSchema("type name must not be empty")
  }

  let type_fields = value.get_fields("type")
  if type_fields.length() > 1 {
    raise SchemaError::InvalidSchema("duplicate type field at type \{name}")
  }
  let type_value = match type_fields {
    [field] => Some(field)
    [] => None
    _ => None
  }
  let base_name = match type_value {
    Some(field) => type_symbol_name(field, "type \{name}")
    None => "$any"
  }
  let fields = value.get_fields("fields")
  let elements = value.get_fields("element")
  let contains_constraints = value.get_fields("contains")
  let field_names_fields = value.get_fields("field_names")
  let ordered_elements_fields = value.get_fields("ordered_elements")
  let valid_values_fields = value.get_fields("valid_values")
  let precision_fields = value.get_fields("precision")
  let exponent_fields = value.get_fields("exponent")
  let timestamp_precision_fields = value.get_fields("timestamp_precision")
  let timestamp_offset_fields = value.get_fields("timestamp_offset")
  let ieee754_float_fields = value.get_fields("ieee754_float")
  let regex_fields = value.get_fields("regex")
  let annotation_fields = value.get_fields("annotations")
  let container_length_fields = value.get_fields("container_length")
  let codepoint_length_fields = value.get_fields("codepoint_length")
  let utf8_byte_length_fields = value.get_fields("utf8_byte_length")
  let byte_length_fields = value.get_fields("byte_length")
  let all_of_fields = value.get_fields("all_of")
  let any_of_fields = value.get_fields("any_of")
  let one_of_fields = value.get_fields("one_of")
  let not_fields = value.get_fields("not")
  if type_value is None &&
    (
      fields.length() > 0 ||
      elements.length() > 0 ||
      field_names_fields.length() > 0 ||
      ordered_elements_fields.length() > 0
    ) {
    raise SchemaError::InvalidSchema(
      "type \{name} must explicitly declare type: struct or list for container constraints",
    )
  }
  if elements.length() > 1 {
    raise SchemaError::InvalidSchema(
      "element may appear at most once at type " + name,
    )
  }
  let (element_type, element_distinct) = match elements {
    [] => (None, false)
    [element] => {
      let (type_ref, distinct) = parse_type_argument_with_distinct(
        element,
        "element of " + name,
      )
      (Some(type_ref), distinct)
    }
    _ => (None, false)
  }
  let contains_values = match contains_constraints {
    [] => None
    constraints => {
      let values : Array[@model.IonValue] = []
      for constraint in constraints {
        for value in parse_contains_values(constraint, "contains of " + name) {
          values.push(value)
        }
      }
      Some(values)
    }
  }
  let (field_names_type, field_names_distinct) = match field_names_fields {
    [] => (None, false)
    [field_names] => {
      let (type_ref, distinct) = parse_type_argument_with_distinct(
        field_names,
        "field_names of " + name,
      )
      (Some(type_ref), distinct)
    }
    _ => (None, false)
  }
  let ordered_elements = match ordered_elements_fields {
    [] => None
    [ordered_value] =>
      Some(parse_ordered_elements(ordered_value, "type " + name))
    _ => None
  }
  validate_type_definition_fields(
    value,
    name,
    fields.length(),
    elements.length(),
    field_names_fields.length(),
    valid_values_fields.length(),
  )
  let valid_values = match valid_values_fields {
    [] => None
    [valid_values_value] =>
      Some(parse_valid_values(valid_values_value, "type \{name}"))
    _ =>
      raise SchemaError::InvalidSchema(
        "valid_values may appear at most once at type \{name}",
      )
  }
  let container_lengths : Array[IntegerRange] = []
  for container_length in container_length_fields {
    container_lengths.push(
      parse_integer_constraint_range(
        container_length,
        "container_length at type " + name,
      ),
    )
  }
  let codepoint_lengths = parse_integer_constraint_fields(
    codepoint_length_fields, "codepoint_length", name,
  )
  let utf8_byte_lengths = parse_integer_constraint_fields(
    utf8_byte_length_fields, "utf8_byte_length", name,
  )
  let byte_lengths = parse_integer_constraint_fields(
    byte_length_fields, "byte_length", name,
  )
  let all_of : Array[TypeRef] = []
  for constraint in all_of_fields {
    for
      type_ref in parse_type_reference_list(
        constraint,
        "all_of at type " + name,
        types,
      ) {
      all_of.push(type_ref)
    }
  }
  let any_of : Array[Array[TypeRef]] = []
  for constraint in any_of_fields {
    any_of.push(
      parse_type_reference_list(constraint, "any_of at type " + name, types),
    )
  }
  let one_of : Array[Array[TypeRef]] = []
  for constraint in one_of_fields {
    one_of.push(
      parse_type_reference_list(constraint, "one_of at type " + name, types),
    )
  }
  let not_constraints : Array[TypeRef] = []
  for constraint in not_fields {
    not_constraints.push(
      parse_logical_type_argument(constraint, "not at type " + name, types),
    )
  }
  let precision_ranges = parse_decimal_constraint_fields(
    precision_fields, "precision", name,
  )
  let exponent_ranges = parse_decimal_constraint_fields(
    exponent_fields, "exponent", name,
  )
  let timestamp_precision_ranges = parse_timestamp_precision_fields(
    timestamp_precision_fields, name,
  )
  let timestamp_offsets = parse_timestamp_offset_fields(
    timestamp_offset_fields, name,
  )
  let ieee754_float_formats = parse_ieee754_float_fields(
    ieee754_float_fields, name,
  )
  let regex_constraints = parse_regex_fields(regex_fields, name)
  let annotation_constraints = parse_annotation_fields(
    annotation_fields, name, types,
  )

  let body = match base_name {
    "struct" => {
      if valid_values is Some(_) {
        raise SchemaError::UnsupportedFeature(
          "valid_values is only supported on scalar types at type \{name}",
        )
      }
      if fields.length() > 1 {
        raise SchemaError::InvalidSchema(
          "type \{name} may declare at most one fields constraint",
        )
      }
      let (parsed_fields, is_open) = match fields {
        [] => ([], true)
        [field_constraint] => parse_fields(name, field_constraint)
        _ => ([], true)
      }
      TypeBody::Struct(parsed_fields, is_open)
    }
    "list" => {
      if valid_values is Some(_) {
        raise SchemaError::UnsupportedFeature(
          "valid_values is only supported on scalar types at type \{name}",
        )
      }
      if elements.length() != 1 &&
        !(elements.length() == 0 &&
        (ordered_elements is Some(_) || contains_values is Some(_))) {
        raise SchemaError::InvalidSchema(
          "type \{name} must declare element or ordered_elements",
        )
      }
      if fields.length() != 0 {
        raise SchemaError::InvalidSchema(
          "type \{name} cannot use fields with list",
        )
      }
      let list_element_type = match element_type {
        Some(type_ref) => type_ref
        None => TypeRef::Builtin("$any")
      }
      TypeBody::List(list_element_type)
    }
    _ => {
      if fields.length() != 0 {
        raise SchemaError::InvalidSchema(
          "scalar or alias type \{name} cannot use fields",
        )
      }
      let reference = match type_value {
        Some(field) => parse_type_reference(field, "type \{name}")
        None => TypeRef::Builtin("$any")
      }
      match reference {
        TypeRef::Builtin(_) => TypeBody::Scalar(reference)
        TypeRef::Named(_) => TypeBody::Alias(reference)
        TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) =>
          raise SchemaError::UnsupportedFeature(
            "$null_or cannot annotate a top-level named type",
          )
      }
    }
  }
  if is_inline &&
    !inline_type_definition_supported(
      value, body, element_type, field_names_type, ordered_elements, contains_values,
      precision_ranges, exponent_ranges, timestamp_precision_ranges, timestamp_offsets,
      ieee754_float_formats, regex_constraints, annotation_constraints, container_lengths,
      codepoint_lengths, utf8_byte_lengths, byte_lengths, all_of, any_of, one_of,
      not_constraints,
    ) {
    raise SchemaError::UnsupportedFeature(
      "inline type definitions currently support scalar types and their implemented value constraints at \{name}",
    )
  }
  {
    name,
    is_inline,
    body,
    element_type,
    element_distinct,
    contains_values,
    field_names_type,
    field_names_distinct,
    ordered_elements,
    valid_values,
    precision_ranges,
    exponent_ranges,
    timestamp_precision_ranges,
    timestamp_offsets,
    ieee754_float_formats,
    regex_constraints,
    annotation_constraints,
    all_of,
    any_of,
    one_of,
    not_constraints,
    container_lengths,
    codepoint_lengths,
    utf8_byte_lengths,
    byte_lengths,
  }
}

///|
fn inline_type_definition_supported(
  value : @model.IonValue,
  body : TypeBody,
  element_type : TypeRef?,
  field_names_type : TypeRef?,
  ordered_elements : Array[OrderedElementSpec]?,
  contains_values : Array[@model.IonValue]?,
  precision_ranges : Array[IntegerRange],
  exponent_ranges : Array[IntegerRange],
  timestamp_precision_ranges : Array[IntegerRange],
  timestamp_offsets : Array[Array[Int?]],
  ieee754_float_formats : Array[String],
  regex_constraints : Array[RegexConstraint],
  annotation_constraints : Array[AnnotationConstraint],
  container_lengths : Array[IntegerRange],
  codepoint_lengths : Array[IntegerRange],
  utf8_byte_lengths : Array[IntegerRange],
  byte_lengths : Array[IntegerRange],
  all_of : Array[TypeRef],
  any_of : Array[Array[TypeRef]],
  one_of : Array[Array[TypeRef]],
  not_constraints : Array[TypeRef],
) -> Bool {
  let fields = value.fields()
  for (symbol, _) in fields {
    match symbol.text_value() {
      Some(
        "name"
        | "type"
        | "valid_values"
        | "precision"
        | "exponent"
        | "timestamp_precision"
        | "timestamp_offset"
        | "ieee754_float"
        | "regex"
        | "annotations"
        | "codepoint_length"
        | "utf8_byte_length"
        | "byte_length"
        | "element"
        | "contains"
        | "ordered_elements"
        | "container_length"
      ) => ()
      _ => return false
    }
  }
  let has_scalar_constraints = precision_ranges.length() > 0 ||
    exponent_ranges.length() > 0 ||
    timestamp_precision_ranges.length() > 0 ||
    timestamp_offsets.length() > 0 ||
    ieee754_float_formats.length() > 0 ||
    regex_constraints.length() > 0 ||
    annotation_constraints.length() > 0 ||
    codepoint_lengths.length() > 0 ||
    utf8_byte_lengths.length() > 0 ||
    byte_lengths.length() > 0 ||
    value.get_fields("valid_values").length() > 0
  let has_type_algebra = all_of.length() > 0 ||
    any_of.length() > 0 ||
    one_of.length() > 0 ||
    not_constraints.length() > 0
  match body {
    TypeBody::Scalar(_) =>
      !has_type_algebra &&
      element_type is None &&
      field_names_type is None &&
      ordered_elements is None &&
      contains_values is None &&
      container_lengths.length() == 0
    TypeBody::List(_) =>
      !has_type_algebra &&
      !has_scalar_constraints &&
      value.get_fields("fields").length() == 0 &&
      field_names_type is None
    TypeBody::Alias(_) | TypeBody::Struct(_, _) => false
  }
}

///|
fn parse_integer_constraint_fields(
  values : Array[@model.IonValue],
  constraint : String,
  type_name : String,
) -> Array[IntegerRange] raise SchemaError {
  let ranges : Array[IntegerRange] = []
  for value in values {
    ranges.push(
      parse_integer_constraint_range(
        value,
        constraint + " at type " + type_name,
      ),
    )
  }
  ranges
}

///|
fn parse_integer_constraint_range(
  value : @model.IonValue,
  context : String,
) -> IntegerRange raise SchemaError {
  let occurrence = match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::Int(_) =>
          parse_occurs(value, context) catch {
            SchemaError::InvalidOccurs(_) =>
              raise SchemaError::InvalidSchema(
                "invalid integer range at " + context,
              )
            error => raise error
          }
        _ =>
          raise SchemaError::InvalidSchema(
            "expected a non-negative integer or range:: value at " + context,
          )
      }
    [annotation] if annotation.text_value() == Some("range") =>
      parse_occurs(value, context) catch {
        SchemaError::InvalidOccurs(_) =>
          raise SchemaError::InvalidSchema(
            "invalid integer range at " + context,
          )
        error => raise error
      }
    _ =>
      raise SchemaError::InvalidSchema(
        "expected an unannotated integer or range:: value at " + context,
      )
  }
  { minimum: occurrence.min_count, maximum: occurrence.max_count, }
}

///|
fn parse_decimal_constraint_fields(
  values : Array[@model.IonValue],
  constraint : String,
  type_name : String,
) -> Array[IntegerRange] raise SchemaError {
  let ranges : Array[IntegerRange] = []
  for value in values {
    ranges.push(
      parse_decimal_constraint_range(
        value,
        constraint + " at type " + type_name,
        constraint == "precision",
      ),
    )
  }
  ranges
}

///|
fn parse_timestamp_precision_fields(
  values : Array[@model.IonValue],
  type_name : String,
) -> Array[IntegerRange] raise SchemaError {
  let ranges : Array[IntegerRange] = []
  for value in values {
    let context = "timestamp_precision at type " + type_name
    match value.annotations() {
      [] => {
        let rank = parse_timestamp_precision_value(value, context)
        ranges.push({ minimum: rank, maximum: Some(rank), })
      }
      [annotation] if annotation.text_value() == Some("range") =>
        ranges.push(parse_timestamp_precision_range(value, context))
      _ =>
        raise SchemaError::InvalidSchema(
          "timestamp_precision must be a precision symbol or range:: value at " +
          context,
        )
    }
  }
  ranges
}

///|
fn parse_timestamp_precision_range(
  value : @model.IonValue,
  context : String,
) -> IntegerRange raise SchemaError {
  let bounds = match value.without_annotations() {
    @model.IonValue::List(bounds) => bounds
    _ =>
      raise SchemaError::InvalidSchema(
        "timestamp_precision range must be a list at " + context,
      )
  }
  let (minimum_value, minimum_exclusive, maximum_value, maximum_exclusive) = match
    bounds {
    [minimum, maximum] => {
      let (minimum_value, minimum_exclusive) = parse_timestamp_precision_endpoint(
        minimum, true, context,
      )
      let (maximum_value, maximum_exclusive) = parse_timestamp_precision_endpoint(
        maximum, false, context,
      )
      (minimum_value, minimum_exclusive, maximum_value, maximum_exclusive)
    }
    _ =>
      raise SchemaError::InvalidSchema(
        "timestamp_precision range must have two bounds at " + context,
      )
  }
  let minimum = match minimum_value {
    Some(value) => {
      let increment = if minimum_exclusive { 1 } else { 0 }
      value + increment
    }
    None => 0
  }
  let maximum = match maximum_value {
    Some(value) => {
      let decrement = if maximum_exclusive { 1 } else { 0 }
      Some(value - decrement)
    }
    None => None
  }
  match maximum {
    Some(maximum) if minimum > maximum =>
      raise SchemaError::InvalidSchema(
        "timestamp_precision range has no values at " + context,
      )
    _ => ()
  }
  { minimum, maximum, }
}

///|
fn parse_timestamp_precision_endpoint(
  value : @model.IonValue,
  is_minimum : Bool,
  context : String,
) -> (Int?, Bool) raise SchemaError {
  let (endpoint, exclusive) = match value.annotations() {
    [] => (value, false)
    [annotation] if annotation.text_value() == Some("exclusive") =>
      (value.without_annotations(), true)
    _ =>
      raise SchemaError::InvalidSchema(
        "timestamp_precision bounds may only use exclusive at " + context,
      )
  }
  let name = match endpoint {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(text) => text
        None =>
          raise SchemaError::InvalidSchema(
            "timestamp_precision bound must use a resolved symbol at " + context,
          )
      }
    _ =>
      raise SchemaError::InvalidSchema(
        "timestamp_precision bounds must be precision symbols or min/max at " +
        context,
      )
  }
  if name == "min" {
    if !is_minimum || exclusive {
      raise SchemaError::InvalidSchema(
        "min is only valid as an inclusive first timestamp_precision bound at " +
        context,
      )
    }
    return (Some(0), false)
  }
  if name == "max" {
    if is_minimum || exclusive {
      raise SchemaError::InvalidSchema(
        "max is only valid as an inclusive second timestamp_precision bound at " +
        context,
      )
    }
    return (None, false)
  }
  (Some(timestamp_precision_rank(name, context)), exclusive)
}

///|
fn parse_timestamp_precision_value(
  value : @model.IonValue,
  context : String,
) -> Int raise SchemaError {
  match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(name) => timestamp_precision_rank(name, context)
        None =>
          raise SchemaError::InvalidSchema(
            "timestamp_precision must use a resolved symbol at " + context,
          )
      }
    _ =>
      raise SchemaError::InvalidSchema(
        "timestamp_precision must be one of the precision symbols at " + context,
      )
  }
}

///|
fn timestamp_precision_rank(
  name : String,
  context : String,
) -> Int raise SchemaError {
  match name {
    "year" => 0
    "month" => 3
    "day" => 6
    "minute" => 9
    "second" => 12
    "millisecond" => 15
    "microsecond" => 18
    "nanosecond" => 21
    _ =>
      raise SchemaError::InvalidSchema(
        "unknown timestamp_precision value " + name + " at " + context,
      )
  }
}

///|
fn parse_timestamp_offset_fields(
  values : Array[@model.IonValue],
  type_name : String,
) -> Array[Array[Int?]] raise SchemaError {
  let constraints : Array[Array[Int?]] = []
  for value in values {
    let context = "timestamp_offset at type " + type_name
    if value.annotations().length() > 0 {
      raise SchemaError::InvalidSchema(
        "timestamp_offset must be an unannotated list at " + context,
      )
    }
    let values = match value.without_annotations() {
      @model.IonValue::List(values) => values
      _ =>
        raise SchemaError::InvalidSchema(
          "timestamp_offset must be a list of offset strings at " + context,
        )
    }
    let offsets : Array[Int?] = []
    for value in values {
      if value.annotations().length() > 0 {
        raise SchemaError::InvalidSchema(
          "timestamp_offset entries must be unannotated strings at " + context,
        )
      }
      let text = match value.without_annotations() {
        @model.IonValue::String(text) => text
        _ =>
          raise SchemaError::InvalidSchema(
            "timestamp_offset entries must be strings at " + context,
          )
      }
      offsets.push(parse_timestamp_offset_text(text, context))
    }
    constraints.push(offsets)
  }
  constraints
}

///|
fn parse_timestamp_offset_text(
  text : String,
  context : String,
) -> Int? raise SchemaError {
  let characters : Array[Char] = []
  for character in text {
    characters.push(character)
  }
  if characters.length() != 6 || characters[3] != ':' {
    raise SchemaError::InvalidSchema(
      "timestamp_offset must use [+|-]hh:mm form at " + context,
    )
  }
  if characters[0] != '+' && characters[0] != '-' {
    raise SchemaError::InvalidSchema(
      "timestamp_offset must begin with + or - at " + context,
    )
  }
  let hour = timestamp_offset_pair(characters[1], characters[2], context)
  let minute = timestamp_offset_pair(characters[4], characters[5], context)
  if hour > 23 || minute > 59 {
    raise SchemaError::InvalidSchema(
      "timestamp_offset hour must be 00–23 and minute 00–59 at " + context,
    )
  }
  if characters[0] == '-' && hour == 0 && minute == 0 {
    return None
  }
  let absolute_minutes = hour * 60 + minute
  Some(if characters[0] == '-' { -absolute_minutes } else { absolute_minutes })
}

///|
fn timestamp_offset_pair(
  tens : Char,
  ones : Char,
  context : String,
) -> Int raise SchemaError {
  let tens_value = tens.to_int() - '0'.to_int()
  let ones_value = ones.to_int() - '0'.to_int()
  if tens_value < 0 || tens_value > 9 || ones_value < 0 || ones_value > 9 {
    raise SchemaError::InvalidSchema(
      "timestamp_offset must contain decimal digits at " + context,
    )
  }
  tens_value * 10 + ones_value
}

///|
fn parse_ieee754_float_fields(
  values : Array[@model.IonValue],
  type_name : String,
) -> Array[String] raise SchemaError {
  let formats : Array[String] = []
  for value in values {
    let context = "ieee754_float at type " + type_name
    if value.annotations().length() > 0 {
      raise SchemaError::InvalidSchema(
        "ieee754_float must be an unannotated format symbol at " + context,
      )
    }
    let format = match value.without_annotations() {
      @model.IonValue::Symbol(symbol) =>
        match symbol.text_value() {
          Some(text) => text
          None =>
            raise SchemaError::InvalidSchema(
              "ieee754_float must use a resolved symbol at " + context,
            )
        }
      _ =>
        raise SchemaError::InvalidSchema(
          "ieee754_float must be binary16, binary32, or binary64 at " + context,
        )
    }
    match format {
      "binary16" | "binary32" | "binary64" => formats.push(format)
      _ =>
        raise SchemaError::InvalidSchema(
          "unknown ieee754_float format " + format + " at " + context,
        )
    }
  }
  formats
}

///|
fn parse_regex_fields(
  values : Array[@model.IonValue],
  type_name : String,
) -> Array[RegexConstraint] raise SchemaError {
  let constraints : Array[RegexConstraint] = []
  for value in values {
    let context = "regex at type " + type_name
    let mut ignore_case = false
    let mut multiline = false
    for annotation in value.annotations() {
      match annotation.text_value() {
        Some("i") if !ignore_case => ignore_case = true
        Some("m") if !multiline => multiline = true
        Some("i" | "m") =>
          raise SchemaError::InvalidSchema(
            "regex flags must not be repeated at " + context,
          )
        Some(flag) =>
          raise SchemaError::InvalidSchema(
            "unsupported regex flag " + flag + " at " + context,
          )
        None =>
          raise SchemaError::InvalidSchema(
            "regex flags must be resolved symbols at " + context,
          )
      }
    }
    let pattern = match value.without_annotations() {
      @model.IonValue::String(pattern) => pattern
      _ =>
        raise SchemaError::InvalidSchema(
          "regex must be a string with optional i/m flags at " + context,
        )
    }
    let normalized_pattern = normalize_isl_regex(
      pattern, ignore_case, multiline, context,
    )
    constraints.push({ pattern: normalized_pattern, })
  }
  constraints
}

///|
fn parse_annotation_fields(
  values : Array[@model.IonValue],
  type_name : String,
  types : Array[NamedType],
) -> Array[AnnotationConstraint] raise SchemaError {
  let constraints : Array[AnnotationConstraint] = []
  for value in values {
    let context = "annotations at type " + type_name
    if has_annotation(value, "closed") || has_annotation(value, "required") {
      constraints.push(parse_simple_annotation_constraint(value, context))
    } else {
      match value.without_annotations() {
        @model.IonValue::Struct(_) =>
          constraints.push(parse_standard_annotation_constraint(value, context))
        _ => {
          let type_ref = parse_logical_type_argument(value, context, types)
          constraints.push({
            allowed: [],
            closed: false,
            required: false,
            standard_type_ref: Some(type_ref),
            standard_inline: false,
            standard_container_lengths: [],
            standard_contains_values: None,
            standard_element_valid_values: None,
            standard_element_regexes: [],
            standard_element_codepoint_lengths: [],
            standard_element_utf8_byte_lengths: [],
            standard_ordered_elements: None,
          })
        }
      }
    }
  }
  constraints
}

///|
fn parse_standard_annotation_constraint(
  value : @model.IonValue,
  context : String,
) -> AnnotationConstraint raise SchemaError {
  if value.annotations().length() > 0 {
    raise SchemaError::UnsupportedFeature(
      "annotated standard annotations type arguments are not supported at " +
      context,
    )
  }
  validate_allowed_fields(
    value,
    ["container_length", "contains", "element", "ordered_elements"],
    context,
  )
  let contains_values : Array[String] = []
  let contains_fields = value.get_fields("contains")
  for contains_value in contains_fields {
    for required in parse_contains_values(contains_value, context) {
      if required.annotations().length() > 0 {
        raise SchemaError::InvalidSchema(
          "annotations contains values must be unannotated symbols at \{context}",
        )
      }
      match required.without_annotations() {
        @model.IonValue::Symbol(symbol) =>
          match symbol.text_value() {
            Some(text) =>
              if !contains_values.contains(text) {
                contains_values.push(text)
              }
            None =>
              raise SchemaError::UnsupportedFeature(
                "unresolved symbols in annotations contains are not supported at \{context}",
              )
          }
        _ =>
          raise SchemaError::InvalidSchema(
            "annotations contains values must be symbols at \{context}",
          )
      }
    }
  }
  let element_values : Array[String] = []
  let element_regexes : Array[RegexConstraint] = []
  let element_codepoint_lengths : Array[IntegerRange] = []
  let element_utf8_byte_lengths : Array[IntegerRange] = []
  let mut has_element_valid_values = false
  let element_fields = value.get_fields("element")
  for element_value in element_fields {
    if element_value.annotations().length() > 0 {
      raise SchemaError::UnsupportedFeature(
        "annotated annotations element expressions are not supported at " +
        context,
      )
    }
    validate_allowed_fields(
      element_value,
      ["valid_values", "regex", "codepoint_length", "utf8_byte_length"],
      context,
    )
    let valid_values_fields = element_value.get_fields("valid_values")
    if valid_values_fields.length() > 0 {
      has_element_valid_values = true
    }
    let regex_fields = element_value.get_fields("regex")
    let codepoint_fields = element_value.get_fields("codepoint_length")
    let utf8_fields = element_value.get_fields("utf8_byte_length")
    if valid_values_fields.length() == 0 &&
      regex_fields.length() == 0 &&
      codepoint_fields.length() == 0 &&
      utf8_fields.length() == 0 {
      raise SchemaError::InvalidSchema(
        "annotations element requires a supported constraint at " + context,
      )
    }
    for regex in parse_regex_fields(regex_fields, context) {
      element_regexes.push(regex)
    }
    for
      length in parse_integer_constraint_fields(
        codepoint_fields, "codepoint_length", context,
      ) {
      element_codepoint_lengths.push(length)
    }
    for
      length in parse_integer_constraint_fields(
        utf8_fields, "utf8_byte_length", context,
      ) {
      element_utf8_byte_lengths.push(length)
    }
    for valid_values_field in valid_values_fields {
      for valid_value in parse_valid_values(valid_values_field, context) {
        if valid_value.annotations().length() > 0 {
          raise SchemaError::InvalidSchema(
            "annotations element valid_values must be unannotated symbols at " +
            context,
          )
        }
        match valid_value.without_annotations() {
          @model.IonValue::Symbol(symbol) =>
            match symbol.text_value() {
              Some(text) =>
                if !element_values.contains(text) {
                  element_values.push(text)
                }
              None =>
                raise SchemaError::UnsupportedFeature(
                  "unresolved symbols in annotations element valid_values are not supported at " +
                  context,
                )
            }
          _ =>
            raise SchemaError::InvalidSchema(
              "annotations element valid_values must contain only symbols at " +
              context,
            )
        }
      }
    }
  }
  {
    allowed: [],
    closed: false,
    required: false,
    standard_type_ref: None,
    standard_inline: true,
    standard_container_lengths: parse_integer_constraint_fields(
      value.get_fields("container_length"),
      "container_length",
      context,
    ),
    standard_contains_values: if contains_fields.length() > 0 {
      Some(contains_values)
    } else {
      None
    },
    standard_element_valid_values: if has_element_valid_values {
      Some(element_values)
    } else {
      None
    },
    standard_element_regexes: element_regexes,
    standard_element_codepoint_lengths: element_codepoint_lengths,
    standard_element_utf8_byte_lengths: element_utf8_byte_lengths,
    standard_ordered_elements: match value.get_fields("ordered_elements") {
      [] => None
      [ordered_value] => Some(parse_ordered_elements(ordered_value, context))
      _ =>
        raise SchemaError::InvalidSchema(
          "ordered_elements may appear at most once at " + context,
        )
    },
  }
}

///|
fn parse_simple_annotation_constraint(
  value : @model.IonValue,
  context : String,
) -> AnnotationConstraint raise SchemaError {
  let mut closed = false
  let mut required = false
  for annotation in value.annotations() {
    match annotation.text_value() {
      Some("closed") if !closed => closed = true
      Some("required") if !required => required = true
      Some("closed" | "required") =>
        raise SchemaError::InvalidSchema(
          "annotations modifiers must not be repeated at " + context,
        )
      Some(modifier) =>
        raise SchemaError::UnsupportedFeature(
          "unsupported annotations modifier " + modifier + " at " + context,
        )
      None =>
        raise SchemaError::InvalidSchema(
          "annotations modifiers must be resolved symbols at " + context,
        )
    }
  }
  if !closed && !required {
    raise SchemaError::InvalidSchema(
      "simple annotations must use closed and/or required at " + context,
    )
  }
  let allowed_values = match value.without_annotations() {
    @model.IonValue::List(values) => values
    _ =>
      raise SchemaError::InvalidSchema(
        "simple annotations must be a list of symbols at " + context,
      )
  }
  let allowed : Array[String] = []
  for allowed_value in allowed_values {
    if allowed_value.annotations().length() > 0 {
      raise SchemaError::InvalidSchema(
        "annotation symbols must be unannotated at " + context,
      )
    }
    let symbol = match allowed_value.without_annotations() {
      @model.IonValue::Symbol(symbol) =>
        match symbol.text_value() {
          Some(text) => text
          None =>
            raise SchemaError::InvalidSchema(
              "annotation symbols must have text at " + context,
            )
        }
      _ =>
        raise SchemaError::InvalidSchema(
          "simple annotations must contain only symbols at " + context,
        )
    }
    if !contains_string(allowed, symbol) {
      allowed.push(symbol)
    }
  }
  {
    allowed,
    closed,
    required,
    standard_type_ref: None,
    standard_inline: false,
    standard_container_lengths: [],
    standard_contains_values: None,
    standard_element_valid_values: None,
    standard_element_regexes: [],
    standard_element_codepoint_lengths: [],
    standard_element_utf8_byte_lengths: [],
    standard_ordered_elements: None,
  }
}

///|
fn normalize_isl_regex(
  pattern : String,
  ignore_case : Bool,
  multiline : Bool,
  context : String,
) -> String raise SchemaError {
  let characters : Array[Char] = []
  for character in pattern {
    characters.push(character)
  }
  let output = StringBuilder()
  if ignore_case {
    output.write_string("(?i:")
  }
  let mut in_character_class = false
  let mut index = 0
  while index < characters.length() {
    let character = characters[index]
    if character == '\\' {
      if index + 1 >= characters.length() {
        raise SchemaError::InvalidSchema(
          "regex ends with an unescaped backslash at " + context,
        )
      }
      let escaped = characters[index + 1]
      match escaped {
        'd' if in_character_class => output.write_string("0-9")
        's' if in_character_class => output.write_string(" \\f\\n\\r\\t")
        'w' if in_character_class => output.write_string("A-Za-z0-9_")
        'D' | 'S' | 'W' if in_character_class =>
          raise SchemaError::UnsupportedFeature(
            "complemented regex classes inside character classes are not supported at " +
            context,
          )
        'd' => output.write_string("[0-9]")
        'D' => output.write_string("[^0-9]")
        's' => output.write_string("[ \\f\\n\\r\\t]")
        'S' => output.write_string("[^ \\f\\n\\r\\t]")
        'w' => output.write_string("[A-Za-z0-9_]")
        'W' => output.write_string("[^A-Za-z0-9_]")
        '.'
        | '^'
        | '$'
        | '|'
        | '?'
        | '*'
        | '+'
        | '\\'
        | '['
        | ']'
        | '('
        | ')'
        | '{'
        | '}' => {
          output.write_char('\\')
          output.write_char(escaped)
        }
        _ =>
          raise SchemaError::UnsupportedFeature(
            "unsupported regex escape \\" +
            escaped.to_string() +
            " at " +
            context,
          )
      }
      index += 2
      continue
    }
    if character == '[' && !in_character_class {
      in_character_class = true
      output.write_char(character)
    } else if character == ']' && in_character_class {
      in_character_class = false
      output.write_char(character)
    } else if character == '(' &&
      index + 1 < characters.length() &&
      characters[index + 1] == '?' {
      raise SchemaError::UnsupportedFeature(
        "regex lookaround and special groups are outside the supported subset at " +
        context,
      )
    } else if character == '.' && !in_character_class {
      output.write_string("[^\\n\\r\\u2028\\u2029]")
    } else if character == '^' && !in_character_class && multiline {
      output.write_string("(^|\\n|\\r|\\u2028|\\u2029)")
    } else if character == '$' && !in_character_class && multiline {
      output.write_string("($|\\n|\\r|\\u2028|\\u2029)")
    } else {
      output.write_char(character)
    }
    index += 1
  }
  if in_character_class {
    raise SchemaError::InvalidSchema(
      "unterminated regex character class at " + context,
    )
  }
  if ignore_case {
    output.write_char(')')
  }
  let normalized = output.to_string()
  let _compiled = @string.Regex(normalized) catch {
    _ => raise SchemaError::InvalidSchema("invalid regex pattern at " + context)
  }
  normalized
}

///|
fn parse_decimal_constraint_range(
  value : @model.IonValue,
  context : String,
  requires_positive_minimum : Bool,
) -> IntegerRange raise SchemaError {
  match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::Int(count) => {
          let exact = decimal_constraint_int(count, context)
          if requires_positive_minimum && exact < 1 {
            raise SchemaError::InvalidSchema(
              "precision must be at least 1 at " + context,
            )
          }
          { minimum: exact, maximum: Some(exact), }
        }
        _ =>
          raise SchemaError::InvalidSchema(
            "expected an integer or range:: value at " + context,
          )
      }
    [annotation] if annotation.text_value() == Some("range") => {
      let (minimum_value, maximum_value) = match value.without_annotations() {
        @model.IonValue::List([minimum, maximum]) => (minimum, maximum)
        _ =>
          raise SchemaError::InvalidSchema(
            "integer range must contain exactly two bounds at " + context,
          )
      }
      let (minimum, minimum_exclusive) = parse_decimal_constraint_endpoint(
        minimum_value, true, context,
      )
      let (maximum, maximum_exclusive) = parse_decimal_constraint_endpoint(
        maximum_value, false, context,
      )
      if minimum is None && maximum is None {
        raise SchemaError::InvalidSchema(
          "integer range cannot use both min and max at " + context,
        )
      }
      if requires_positive_minimum {
        match minimum {
          Some(explicit_minimum) if explicit_minimum < 1 =>
            raise SchemaError::InvalidSchema(
              "precision range minimum must be at least 1 at " + context,
            )
          _ => ()
        }
      }
      if minimum_exclusive && minimum == Some(2147483647) {
        raise SchemaError::InvalidSchema(
          "exclusive integer range minimum exceeds the supported range at " +
          context,
        )
      }
      if maximum_exclusive && maximum == Some(-2147483648) {
        raise SchemaError::InvalidSchema(
          "exclusive integer range maximum is below the supported range at " +
          context,
        )
      }
      let effective_minimum = match minimum {
        Some(bound) => bound + (if minimum_exclusive { 1 } else { 0 })
        None => if requires_positive_minimum { 1 } else { -2147483648 }
      }
      let effective_maximum = match maximum {
        Some(bound) => Some(bound - (if maximum_exclusive { 1 } else { 0 }))
        None => None
      }
      match effective_maximum {
        Some(bound) if bound < effective_minimum =>
          raise SchemaError::InvalidSchema(
            "integer range has no values at " + context,
          )
        _ => ()
      }
      { minimum: effective_minimum, maximum: effective_maximum, }
    }
    _ =>
      raise SchemaError::InvalidSchema(
        "expected an unannotated integer or range:: value at " + context,
      )
  }
}

///|
fn parse_decimal_constraint_endpoint(
  value : @model.IonValue,
  is_minimum : Bool,
  context : String,
) -> (Int?, Bool) raise SchemaError {
  let exclusive = match value.annotations() {
    [] => false
    [annotation] if annotation.text_value() == Some("exclusive") => true
    _ =>
      raise SchemaError::InvalidSchema(
        "integer range bounds may only use exclusive at " + context,
      )
  }
  match value.without_annotations() {
    @model.IonValue::Int(bound) =>
      (Some(decimal_constraint_int(bound, context)), exclusive)
    @model.IonValue::Symbol(symbol) => {
      let expected = if is_minimum { "min" } else { "max" }
      if exclusive || symbol.text_value() != Some(expected) {
        raise SchemaError::InvalidSchema(
          "integer range must use min as its lower bound and max as its upper bound at " +
          context,
        )
      }
      (None, false)
    }
    _ =>
      raise SchemaError::InvalidSchema(
        "integer range bounds must be integers or min/max at " + context,
      )
  }
}

///|
fn decimal_constraint_int(
  value : @bigint.BigInt,
  context : String,
) -> Int raise SchemaError {
  if value.compare_int(-2147483648) < 0 || value.compare_int(2147483647) > 0 {
    raise SchemaError::InvalidSchema(
      "integer constraint bound exceeds the supported range at " + context,
    )
  }
  value.to_int()
}

///|
fn parse_valid_values(
  value : @model.IonValue,
  context : String,
) -> Array[@model.IonValue] raise SchemaError {
  match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::List(values) => values
        _ =>
          raise SchemaError::InvalidSchema(
            "valid_values must be an Ion list at \{context}",
          )
      }
    [annotation] if annotation.text_value() == Some("range") =>
      match value.without_annotations() {
        @model.IonValue::List(_) => [value]
        _ =>
          raise SchemaError::InvalidSchema(
            "valid_values range must be a two-bound Ion list at \{context}",
          )
      }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "annotated valid_values sets are not supported at \{context}",
      )
  }
}

///|
fn parse_contains_values(
  value : @model.IonValue,
  context : String,
) -> Array[@model.IonValue] raise SchemaError {
  match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::List(values) => values
        _ =>
          raise SchemaError::InvalidSchema(
            "contains must be an Ion list at \{context}",
          )
      }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "annotated contains lists are not supported at \{context}",
      )
  }
}

///|
fn parse_fields(
  type_name : String,
  fields_value : @model.IonValue,
) -> (Array[FieldSpec], Bool) raise SchemaError {
  let is_open = match fields_value.annotations() {
    [annotation] if annotation.text_value() == Some("closed") => false
    [] => true
    _ =>
      raise SchemaError::UnsupportedFeature(
        "fields annotations must contain only closed for type \{type_name}",
      )
  }

  let fields = match fields_value.without_annotations() {
    @model.IonValue::Struct(fields) => fields
    _ =>
      raise SchemaError::InvalidSchema(
        "fields constraint for type \{type_name} must be a struct",
      )
  }

  let result : Array[FieldSpec] = []
  for (symbol, value) in fields {
    let field_name = match symbol.text_value() {
      Some(text) => text
      None =>
        raise SchemaError::UnsupportedFeature(
          "unresolved field name in type \{type_name}",
        )
    }
    if field_name == "" {
      raise SchemaError::InvalidSchema(
        "field name in type \{type_name} must not be empty",
      )
    }
    if contains_field(result, field_name) {
      raise SchemaError::DuplicateField(type_name~, field_name~)
    }
    let (type_ref, occurrence) = parse_type_argument(
      value,
      "field \{type_name}.\{field_name}",
    )
    result.push({ name: field_name, type_ref, occurrence, })
  }
  (result, is_open)
}

///|
fn parse_type_argument(
  value : @model.IonValue,
  context : String,
) -> (TypeRef, FieldOccurrence) raise SchemaError {
  match value {
    @model.IonValue::Struct(_) => {
      if value.annotations().length() != 0 {
        raise SchemaError::UnsupportedFeature(
          "annotated inline type arguments are not supported at \{context}",
        )
      }
      validate_allowed_fields(value, ["type", "occurs"], context)
      let type_value = required_single_field(value, "type", context)
      let type_ref = parse_type_argument_reference(type_value, context)
      let occurrence_values = value.get_fields("occurs")
      let occurrence = match occurrence_values {
        [] => { min_count: 0, max_count: Some(1), }
        [occurs_value] => {
          let occurs = parse_occurs(occurs_value, context)
          if is_null_or_reference(type_ref) {
            raise SchemaError::InvalidOccurs(
              "$null_or cannot be combined with explicit occurs at \{context}",
            )
          }
          occurs
        }
        _ =>
          raise SchemaError::InvalidOccurs(
            "occurs may appear at most once at \{context}",
          )
      }
      (type_ref, occurrence)
    }
    _ =>
      (
        parse_type_argument_reference(value, context),
        { min_count: 0, max_count: Some(1), },
      )
  }
}

///|
fn parse_type_argument_reference(
  value : @model.IonValue,
  context : String,
) -> TypeRef raise SchemaError {
  match value.annotations() {
    [] => parse_type_reference(value, context)
    [annotation] if annotation.text_value() == Some("$null_or") => {
      let inner = parse_type_reference(value.without_annotations(), context)
      match inner {
        TypeRef::Builtin(name) => TypeRef::NullOrBuiltin(name)
        TypeRef::Named(name) => TypeRef::NullOrNamed(name)
        TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) =>
          raise SchemaError::UnsupportedFeature(
            "nested $null_or annotations are not supported at \{context}",
          )
      }
    }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "only $null_or annotated type arguments are supported at \{context}",
      )
  }
}

///|
fn parse_type_reference_list(
  value : @model.IonValue,
  context : String,
  types : Array[NamedType],
) -> Array[TypeRef] raise SchemaError {
  let values = match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::List(values) => values
        _ => raise SchemaError::InvalidSchema("\{context} must be an Ion list")
      }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "annotated type reference lists are not supported at \{context}",
      )
  }
  if values.length() == 0 {
    raise SchemaError::InvalidSchema("\{context} must not be empty")
  }
  let result : Array[TypeRef] = []
  let mut index = 0
  for item in values {
    result.push(
      parse_logical_type_argument(item, "\{context}[\{index}]", types),
    )
    index += 1
  }
  result
}

///|
fn parse_logical_type_argument(
  value : @model.IonValue,
  context : String,
  types : Array[NamedType],
) -> TypeRef raise SchemaError {
  match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::Symbol(symbol) =>
          match symbol.text_value() {
            Some(name) if name == "struct" ||
              name == "list" ||
              name == "text" ||
              name == "lob" => TypeRef::Builtin(name)
            Some(_) => parse_type_reference(value, context)
            None =>
              raise SchemaError::UnsupportedFeature(
                "unresolved type argument at \{context}",
              )
          }
        @model.IonValue::Struct(fields) => {
          if value.get_fields("id").length() > 0 {
            raise SchemaError::UnsupportedFeature(
              "inline imports require CLI file resolution at {context}",
            )
          }
          if value.get_fields("name").length() > 0 {
            raise SchemaError::InvalidSchema(
              "inline type definitions cannot declare name at {context}",
            )
          }
          let mut inline_name = "ion_schema_codegen_internal_inline_" +
            types.length().to_string()
          while contains_type(types, inline_name) {
            inline_name = inline_name + "_"
          }
          let inline_fields : Array[(@model.IonSymbol, @model.IonValue)] = [
            (
              @model.IonSymbol::from_text("name"),
              @model.IonValue::Symbol(@model.IonSymbol::from_text(inline_name)),
            ),
          ]
          for (symbol, field_value) in fields {
            inline_fields.push((symbol, field_value))
          }
          let inline_value = @model.IonValue::Struct(inline_fields).with_annotations([
              @model.IonSymbol::from_text("type"),
            ],
          )
          let inline_type = parse_named_type(inline_value, types, true)
          types.push(inline_type)
          TypeRef::Named(inline_name)
        }
        _ =>
          raise SchemaError::InvalidSchema(
            "expected a type symbol at \{context}",
          )
      }
    [annotation] if annotation.text_value() == Some("$null_or") => {
      let inner = parse_logical_type_argument(
        value.without_annotations(),
        context,
        types,
      )
      nullable_type_reference(inner)
    }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "only $null_or annotated type arguments are supported at \{context}",
      )
  }
}

///|
fn parse_type_argument_with_distinct(
  value : @model.IonValue,
  context : String,
) -> (TypeRef, Bool) raise SchemaError {
  let annotations = value.annotations()
  match annotations {
    [] => (parse_type_argument_reference(value, context), false)
    [distinct] if distinct.text_value() == Some("distinct") =>
      (parse_type_reference(value.without_annotations(), context), true)
    [null_or] if null_or.text_value() == Some("$null_or") =>
      (
        nullable_type_reference(
          parse_type_reference(value.without_annotations(), context),
        ),
        false,
      )
    [distinct, null_or] if distinct.text_value() == Some("distinct") &&
      null_or.text_value() == Some("$null_or") =>
      (
        nullable_type_reference(
          parse_type_reference(value.without_annotations(), context),
        ),
        true,
      )
    _ =>
      raise SchemaError::UnsupportedFeature(
        "type arguments support only distinct and $null_or modifiers at " +
        context,
      )
  }
}

///|
fn nullable_type_reference(type_ref : TypeRef) -> TypeRef {
  match type_ref {
    TypeRef::Builtin(name) => TypeRef::NullOrBuiltin(name)
    TypeRef::Named(name) => TypeRef::NullOrNamed(name)
    TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) => type_ref
  }
}

///|
fn parse_ordered_elements(
  value : @model.IonValue,
  context : String,
) -> Array[OrderedElementSpec] raise SchemaError {
  let values = match value.annotations() {
    [] =>
      match value.without_annotations() {
        @model.IonValue::List(values) => values
        _ =>
          raise SchemaError::InvalidSchema(
            "ordered_elements must be an Ion list at " + context,
          )
      }
    _ =>
      raise SchemaError::UnsupportedFeature(
        "annotated ordered_elements lists are not supported at " + context,
      )
  }
  let result : Array[OrderedElementSpec] = []
  let mut index = 0
  for item in values {
    let item_context = "ordered_elements[" +
      index.to_string() +
      "] at " +
      context
    let (type_ref, occurrence) = parse_ordered_type_argument(item, item_context)
    result.push({ type_ref, occurrence, })
    index += 1
  }
  result
}

///|
fn parse_ordered_type_argument(
  value : @model.IonValue,
  context : String,
) -> (TypeRef, FieldOccurrence) raise SchemaError {
  match value.without_annotations() {
    @model.IonValue::Struct(_) => {
      if value.annotations().length() > 0 {
        raise SchemaError::UnsupportedFeature(
          "annotated ordered_elements type arguments are not supported at " +
          context,
        )
      }
      validate_allowed_fields(value, ["type", "occurs"], context)
      let type_ref = parse_type_argument_reference(
        required_single_field(value, "type", context),
        context,
      )
      let occurrence_values = value.get_fields("occurs")
      let occurrence = match occurrence_values {
        [] => { min_count: 1, max_count: Some(1), }
        [occurs_value] => {
          if is_null_or_reference(type_ref) {
            raise SchemaError::InvalidOccurs(
              "$null_or cannot be combined with explicit occurs at " + context,
            )
          }
          parse_occurs(occurs_value, context)
        }
        _ =>
          raise SchemaError::InvalidOccurs(
            "occurs may appear at most once at " + context,
          )
      }
      (type_ref, occurrence)
    }
    _ =>
      (
        parse_type_argument_reference(value, context),
        { min_count: 1, max_count: Some(1), },
      )
  }
}

///|
fn parse_occurs(
  value : @model.IonValue,
  context : String,
) -> FieldOccurrence raise SchemaError {
  match value.annotations() {
    [annotation] if annotation.text_value() == Some("range") =>
      parse_occurs_range(value, context)
    [] =>
      match value.without_annotations() {
        @model.IonValue::Symbol(symbol) =>
          match symbol.text_value() {
            Some("required") => { min_count: 1, max_count: Some(1), }
            Some("optional") => { min_count: 0, max_count: Some(1), }
            Some(name) =>
              raise SchemaError::InvalidOccurs(
                "expected required, optional, a non-negative integer, or range at \{context}; found \{name}",
              )
            None =>
              raise SchemaError::InvalidOccurs(
                "occurs must be a resolved symbol at \{context}",
              )
          }
        @model.IonValue::Int(count) => {
          let exact = parse_occurs_count(count, context)
          { min_count: exact, max_count: Some(exact), }
        }
        _ =>
          raise SchemaError::InvalidOccurs(
            "expected required, optional, a non-negative integer, or range at \{context}",
          )
      }
    _ =>
      raise SchemaError::InvalidOccurs(
        "occurs must be an unannotated symbol, integer, or range:: list at \{context}",
      )
  }
}

///|
fn parse_occurs_range(
  value : @model.IonValue,
  context : String,
) -> FieldOccurrence raise SchemaError {
  let (minimum, maximum) = match value.without_annotations() {
    @model.IonValue::List([minimum, maximum]) => (minimum, maximum)
    _ =>
      raise SchemaError::InvalidOccurs(
        "occurs range must contain exactly two bounds at \{context}",
      )
  }
  let (minimum_value, minimum_exclusive) = parse_occurs_endpoint(
    minimum, true, context,
  )
  let (maximum_value, maximum_exclusive) = parse_occurs_endpoint(
    maximum, false, context,
  )
  if minimum_value is None && maximum_value is None {
    raise SchemaError::InvalidOccurs(
      "occurs range cannot use both min and max at \{context}",
    )
  }
  if minimum_exclusive && minimum_value == Some(2147483647) {
    raise SchemaError::InvalidOccurs(
      "exclusive occurs minimum exceeds the maximum supported MoonBit array length at \{context}",
    )
  }
  let min_count = match minimum_value {
    Some(count) => count + (if minimum_exclusive { 1 } else { 0 })
    None => 0
  }
  let max_count = match maximum_value {
    Some(count) => Some(count - (if maximum_exclusive { 1 } else { 0 }))
    None => None
  }
  match max_count {
    Some(maximum_count) if maximum_count < min_count =>
      raise SchemaError::InvalidOccurs(
        "occurs range has no non-negative integer values at \{context}",
      )
    _ => ()
  }
  { min_count, max_count, }
}

///|
fn parse_occurs_endpoint(
  value : @model.IonValue,
  is_minimum : Bool,
  context : String,
) -> (Int?, Bool) raise SchemaError {
  let exclusive = match value.annotations() {
    [] => false
    [annotation] if annotation.text_value() == Some("exclusive") => true
    _ =>
      raise SchemaError::InvalidOccurs(
        "range bounds may only use the exclusive annotation at \{context}",
      )
  }
  match value.without_annotations() {
    @model.IonValue::Symbol(symbol) => {
      let expected = if is_minimum { "min" } else { "max" }
      if exclusive || symbol.text_value() != Some(expected) {
        raise SchemaError::InvalidOccurs(
          "occurs range must use min as its lower bound and max as its upper bound at \{context}",
        )
      }
      (None, false)
    }
    @model.IonValue::Int(count) =>
      (Some(parse_occurs_count(count, context)), exclusive)
    _ =>
      raise SchemaError::InvalidOccurs(
        "occurs range bounds must be non-negative integers or min/max at \{context}",
      )
  }
}

///|
fn parse_occurs_count(
  count : @bigint.BigInt,
  context : String,
) -> Int raise SchemaError {
  if count.compare_int(0) < 0 {
    raise SchemaError::InvalidOccurs(
      "occurs counts must be non-negative at \{context}",
    )
  }
  if count.compare_int(2147483647) > 0 {
    raise SchemaError::InvalidOccurs(
      "occurs count exceeds the maximum supported MoonBit array length at \{context}",
    )
  }
  count.to_int()
}

///|
fn is_null_or_reference(type_ref : TypeRef) -> Bool {
  match type_ref {
    TypeRef::NullOrBuiltin(_) | TypeRef::NullOrNamed(_) => true
    _ => false
  }
}

///|
fn parse_type_reference(
  value : @model.IonValue,
  context : String,
) -> TypeRef raise SchemaError {
  if value.annotations().length() != 0 {
    raise SchemaError::UnsupportedFeature(
      "annotated or nullable type arguments are not supported at \{context}",
    )
  }
  let name = symbol_text(value, context)
  if is_supported_scalar(name) {
    TypeRef::Builtin(name)
  } else if name == "struct" || name == "list" {
    raise SchemaError::InvalidSchema(
      "\{name} requires its matching fields or element constraint at \{context}",
    )
  } else if is_known_builtin(name) {
    raise SchemaError::UnsupportedFeature(
      "built-in type \{name} is not supported at \{context}",
    )
  } else {
    TypeRef::Named(name)
  }
}

///|
fn type_symbol_name(
  value : @model.IonValue,
  context : String,
) -> String raise SchemaError {
  if value.annotations().length() != 0 {
    raise SchemaError::UnsupportedFeature(
      "annotated type names are not supported at \{context}",
    )
  }
  symbol_text(value, context)
}

///|
fn symbol_text(
  value : @model.IonValue,
  context : String,
) -> String raise SchemaError {
  match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some(text) => text
        None =>
          raise SchemaError::UnsupportedFeature(
            "unresolved symbol at \{context}",
          )
      }
    _ =>
      raise SchemaError::InvalidSchema("expected an Ion symbol at \{context}")
  }
}

///|
fn required_single_field(
  value : @model.IonValue,
  name : String,
  context : String,
) -> @model.IonValue raise SchemaError {
  match value.get_fields(name) {
    [field] => field
    [] =>
      raise SchemaError::InvalidSchema("missing \{name} field at \{context}")
    _ =>
      raise SchemaError::InvalidSchema("duplicate \{name} field at \{context}")
  }
}

///|
fn validate_type_definition_fields(
  value : @model.IonValue,
  type_name : String,
  fields_count : Int,
  elements_count : Int,
  field_names_count : Int,
  valid_values_count : Int,
) -> Unit raise SchemaError {
  validate_allowed_fields(
    value,
    [
      "name", "type", "fields", "element", "field_names", "ordered_elements", "valid_values",
      "contains", "precision", "exponent", "timestamp_precision", "timestamp_offset",
      "ieee754_float", "regex", "container_length", "codepoint_length", "utf8_byte_length",
      "byte_length", "annotations", "all_of", "any_of", "one_of", "not",
    ],
    "type \{type_name}",
  )
  if fields_count > 1 ||
    elements_count > 1 ||
    field_names_count > 1 ||
    valid_values_count > 1 ||
    value.get_fields("ordered_elements").length() > 1 {
    raise SchemaError::InvalidSchema(
      "duplicate fields or constraints at type \{type_name}",
    )
  }
}

///|
fn validate_allowed_fields(
  value : @model.IonValue,
  allowed : Array[String],
  context : String,
) -> Unit raise SchemaError {
  for (symbol, _) in value.fields() {
    let name = match symbol.text_value() {
      Some(text) => text
      None =>
        raise SchemaError::UnsupportedFeature(
          "unresolved field symbol at \{context}",
        )
    }
    if !contains_string(allowed, name) {
      raise SchemaError::UnsupportedFeature(
        "unsupported field or constraint \{name} at \{context}",
      )
    }
  }
}

///|
fn validate_schema_header(value : @model.IonValue) -> Unit raise SchemaError {
  validate_single_annotation(value, "schema_header")
  for (symbol, _) in value.fields() {
    match symbol.text_value() {
      Some("imports") =>
        raise SchemaError::UnsupportedFeature(
          "schema imports require the file-based CLI; generate_code accepts a single schema",
        )
      Some(name) =>
        raise SchemaError::UnsupportedFeature(
          "schema_header field \{name} is not supported",
        )
      None =>
        raise SchemaError::UnsupportedFeature(
          "unresolved schema_header field name",
        )
    }
  }
  match value.without_annotations() {
    @model.IonValue::Struct(_) => ()
    _ => raise SchemaError::InvalidSchema("schema_header must be a struct")
  }
}

///|
fn validate_schema_footer(value : @model.IonValue) -> Unit raise SchemaError {
  validate_single_annotation(value, "schema_footer")
  match value.without_annotations() {
    @model.IonValue::Struct([]) => ()
    @model.IonValue::Struct(_) =>
      raise SchemaError::UnsupportedFeature(
        "schema_footer fields are not supported",
      )
    _ => raise SchemaError::InvalidSchema("schema_footer must be a struct")
  }
}

///|
fn validate_type_annotations(value : @model.IonValue) -> Unit raise SchemaError {
  validate_single_annotation(value, "type")
  match value.without_annotations() {
    @model.IonValue::Struct(_) => ()
    _ => raise SchemaError::InvalidSchema("type definition must be a struct")
  }
}

///|
fn validate_single_annotation(
  value : @model.IonValue,
  expected : String,
) -> Unit raise SchemaError {
  match value.annotations() {
    [annotation] if annotation.text_value() == Some(expected) => ()
    _ =>
      raise SchemaError::InvalidSchema(
        "expected only the \{expected} annotation",
      )
  }
}

///|
fn has_annotation(value : @model.IonValue, expected : String) -> Bool {
  for annotation in value.annotations() {
    if annotation.text_value() == Some(expected) {
      return true
    }
  }
  false
}

///|
fn is_schema_version_symbol(symbol : @model.IonSymbol) -> Bool {
  match symbol.text_value() {
    Some(text) => text.has_prefix("$ion_schema_")
    None => false
  }
}

///|
fn has_late_schema_version(values : ArrayView[@model.IonValue]) -> Bool {
  for value in values {
    match value.without_annotations() {
      @model.IonValue::Symbol(symbol) if is_schema_version_symbol(symbol) =>
        return true
      _ => ()
    }
  }
  false
}

///|
fn supports_container_length(
  types : Array[NamedType],
  body : TypeBody,
) -> Bool raise SchemaError {
  match body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => true
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Struct(_) | ResolvedType::List(_) => true
        ResolvedType::Scalar(name) =>
          contains_string(
            ["sexp", "document", "$list", "$sexp", "$struct"],
            name,
          )
      }
  }
}

///|
fn supports_integer_content_length(
  types : Array[NamedType],
  body : TypeBody,
  allowed_types : Array[String],
) -> Bool raise SchemaError {
  match body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => false
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar(name) => contains_string(allowed_types, name)
        ResolvedType::Struct(_) | ResolvedType::List(_) => false
      }
  }
}

///|
fn supports_element_constraint(
  types : Array[NamedType],
  named_type : NamedType,
) -> Bool raise SchemaError {
  match named_type.body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => true
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Struct(_) | ResolvedType::List(_) => true
        ResolvedType::Scalar(name) =>
          contains_string(["sexp", "$sexp", "document"], name)
      }
  }
}

///|
fn supports_field_names_constraint(
  types : Array[NamedType],
  named_type : NamedType,
) -> Bool raise SchemaError {
  match named_type.body {
    TypeBody::Struct(_, _) => true
    TypeBody::List(_) => false
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Struct(_) => true
        ResolvedType::Scalar("struct" | "$struct") => true
        ResolvedType::Scalar(_) | ResolvedType::List(_) => false
      }
  }
}

///|
fn supports_contains_constraint(
  types : Array[NamedType],
  named_type : NamedType,
) -> Bool raise SchemaError {
  match named_type.body {
    TypeBody::Struct(_, _) | TypeBody::List(_) => true
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Struct(_) | ResolvedType::List(_) => true
        ResolvedType::Scalar(name) =>
          contains_string(
            ["list", "$list", "sexp", "$sexp", "struct", "$struct", "document"],
            name,
          )
      }
  }
}

///|
fn supports_decimal_constraints(
  types : Array[NamedType],
  body : TypeBody,
) -> Bool raise SchemaError {
  match body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar("decimal" | "$decimal") => true
        ResolvedType::Scalar(_)
        | ResolvedType::Struct(_)
        | ResolvedType::List(_) => false
      }
    TypeBody::Struct(_, _) | TypeBody::List(_) => false
  }
}

///|
fn supports_timestamp_constraints(
  types : Array[NamedType],
  body : TypeBody,
) -> Bool raise SchemaError {
  match body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar("timestamp" | "$timestamp") => true
        ResolvedType::Scalar(_)
        | ResolvedType::Struct(_)
        | ResolvedType::List(_) => false
      }
    TypeBody::Struct(_, _) | TypeBody::List(_) => false
  }
}

///|
fn supports_ieee754_float_constraint(
  types : Array[NamedType],
  body : TypeBody,
) -> Bool raise SchemaError {
  match body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar("float" | "$float") => true
        ResolvedType::Scalar(_)
        | ResolvedType::Struct(_)
        | ResolvedType::List(_) => false
      }
    TypeBody::Struct(_, _) | TypeBody::List(_) => false
  }
}

///|
fn supports_regex_constraint(
  types : Array[NamedType],
  body : TypeBody,
) -> Bool raise SchemaError {
  match body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::Scalar("string" | "symbol" | "$string" | "$symbol") =>
          true
        ResolvedType::Scalar(_)
        | ResolvedType::Struct(_)
        | ResolvedType::List(_) => false
      }
    TypeBody::Struct(_, _) | TypeBody::List(_) => false
  }
}

///|
fn supports_annotations_constraint(
  types : Array[NamedType],
  body : TypeBody,
) -> Bool raise SchemaError {
  let type_ref = match body {
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) => type_ref
    TypeBody::Struct(_, _) | TypeBody::List(_) => return false
  }
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar("document") => true
    ResolvedType::Scalar(_) => is_raw_ion_value_reference(type_ref, types)
    ResolvedType::Struct(_) | ResolvedType::List(_) => false
  }
}

///|
fn supports_ordered_elements(
  types : Array[NamedType],
  named_type : NamedType,
) -> Bool raise SchemaError {
  match named_type.body {
    TypeBody::List(_) => true
    TypeBody::Struct(_, _) => false
    TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
      match resolve_type_ref(types, type_ref) {
        ResolvedType::List(_) => true
        ResolvedType::Struct(_) => false
        ResolvedType::Scalar(name) =>
          contains_string(["sexp", "$sexp", "document"], name)
      }
  }
}

///|
fn validate_type_references(types : Array[NamedType]) -> Unit raise SchemaError {
  for named_type in types {
    match named_type.ordered_elements {
      Some(ordered_elements) => {
        if !supports_ordered_elements(types, named_type) {
          raise SchemaError::UnsupportedFeature(
            "ordered_elements applies only to list, sexp, or document values at type " +
            named_type.name,
          )
        }
        for ordered_element in ordered_elements {
          validate_type_reference(
            types,
            ordered_element.type_ref,
            "ordered_elements of " + named_type.name,
          )
        }
      }
      None => ()
    }
    match named_type.element_type {
      Some(element_type) => {
        if !supports_element_constraint(types, named_type) {
          raise SchemaError::UnsupportedFeature(
            "element applies only to list, sexp, struct, or document values at type " +
            named_type.name,
          )
        }
        validate_type_reference(
          types,
          element_type,
          "element of " + named_type.name,
        )
      }
      None => ()
    }
    match named_type.field_names_type {
      Some(field_names_type) => {
        if !supports_field_names_constraint(types, named_type) {
          raise SchemaError::UnsupportedFeature(
            "field_names applies only to struct values at type " +
            named_type.name,
          )
        }
        validate_type_reference(
          types,
          field_names_type,
          "field_names of " + named_type.name,
        )
      }
      None => ()
    }
    match named_type.contains_values {
      Some(_) =>
        if !supports_contains_constraint(types, named_type) {
          raise SchemaError::UnsupportedFeature(
            "contains applies only to list, sexp, struct, or document values at type " +
            named_type.name,
          )
        }
      None => ()
    }
    if (
        named_type.precision_ranges.length() > 0 ||
        named_type.exponent_ranges.length() > 0
      ) &&
      !supports_decimal_constraints(types, named_type.body) {
      raise SchemaError::UnsupportedFeature(
        "precision and exponent apply only to decimal values at type " +
        named_type.name,
      )
    }
    if (
        named_type.timestamp_precision_ranges.length() > 0 ||
        named_type.timestamp_offsets.length() > 0
      ) &&
      !supports_timestamp_constraints(types, named_type.body) {
      raise SchemaError::UnsupportedFeature(
        "timestamp_precision and timestamp_offset apply only to timestamp values at type " +
        named_type.name,
      )
    }
    if named_type.ieee754_float_formats.length() > 0 &&
      !supports_ieee754_float_constraint(types, named_type.body) {
      raise SchemaError::UnsupportedFeature(
        "ieee754_float applies only to float values at type " + named_type.name,
      )
    }
    if named_type.regex_constraints.length() > 0 &&
      !supports_regex_constraint(types, named_type.body) {
      raise SchemaError::UnsupportedFeature(
        "regex applies only to string or symbol values at type " +
        named_type.name,
      )
    }
    if named_type.annotation_constraints.length() > 0 &&
      !supports_annotations_constraint(types, named_type.body) {
      raise SchemaError::UnsupportedFeature(
        "annotations currently requires an IonValue-backed type at type " +
        named_type.name,
      )
    }
    for constraint in named_type.annotation_constraints {
      match constraint.standard_type_ref {
        Some(type_ref) =>
          validate_type_reference(
            types,
            type_ref,
            "annotations of " + named_type.name,
          )
        None => ()
      }
      match constraint.standard_ordered_elements {
        Some(ordered_elements) =>
          for ordered_element in ordered_elements {
            validate_type_reference(
              types,
              ordered_element.type_ref,
              "annotations ordered_elements of " + named_type.name,
            )
          }
        None => ()
      }
    }
    if named_type.container_lengths.length() > 0 &&
      !supports_container_length(types, named_type.body) {
      raise SchemaError::UnsupportedFeature(
        "container_length applies only to list, sexp, struct, or document at type " +
        named_type.name,
      )
    }
    if (
        named_type.codepoint_lengths.length() > 0 ||
        named_type.utf8_byte_lengths.length() > 0
      ) &&
      !supports_integer_content_length(types, named_type.body, [
        "string", "symbol", "$string", "$symbol",
      ]) {
      raise SchemaError::UnsupportedFeature(
        "codepoint_length and utf8_byte_length apply only to string or symbol values at type " +
        named_type.name,
      )
    }
    if named_type.byte_lengths.length() > 0 &&
      !supports_integer_content_length(types, named_type.body, [
        "blob", "clob", "$blob", "$clob",
      ]) {
      raise SchemaError::UnsupportedFeature(
        "byte_length applies only to blob or clob values at type " +
        named_type.name,
      )
    }
    if named_type.all_of.length() > 0 ||
      named_type.any_of.length() > 0 ||
      named_type.one_of.length() > 0 ||
      named_type.not_constraints.length() > 0 {
      match named_type.body {
        TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
          if is_document_reference(types, type_ref) {
            raise SchemaError::UnsupportedFeature(
              "type algebra on document streams is not supported at type " +
              named_type.name,
            )
          }
        TypeBody::Struct(_, _) | TypeBody::List(_) => ()
      }
      for type_ref in named_type.all_of {
        validate_type_algebra_reference(
          types,
          type_ref,
          "all_of of " + named_type.name,
        )
        if is_document_reference(types, type_ref) {
          raise SchemaError::UnsupportedFeature(
            "document stream type arguments are not supported in type algebra at type " +
            named_type.name,
          )
        }
      }
      for branches in named_type.any_of {
        for type_ref in branches {
          validate_type_algebra_reference(
            types,
            type_ref,
            "any_of of " + named_type.name,
          )
          if is_document_reference(types, type_ref) {
            raise SchemaError::UnsupportedFeature(
              "document stream type arguments are not supported in type algebra at type " +
              named_type.name,
            )
          }
        }
      }
      for branches in named_type.one_of {
        for type_ref in branches {
          validate_type_algebra_reference(
            types,
            type_ref,
            "one_of of " + named_type.name,
          )
          if is_document_reference(types, type_ref) {
            raise SchemaError::UnsupportedFeature(
              "document stream type arguments are not supported in type algebra at type " +
              named_type.name,
            )
          }
        }
      }
      for type_ref in named_type.not_constraints {
        validate_type_algebra_reference(
          types,
          type_ref,
          "not of " + named_type.name,
        )
        if is_document_reference(types, type_ref) {
          raise SchemaError::UnsupportedFeature(
            "document stream type arguments are not supported in type algebra at type " +
            named_type.name,
          )
        }
      }
    }
    if named_type.valid_values is Some(valid_values) {
      match named_type.body {
        TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
          if !is_valid_values_target(types, type_ref) {
            raise SchemaError::UnsupportedFeature(
              "valid_values is supported only for scalar Ion types at type \{named_type.name}",
            )
          }
        TypeBody::Struct(_, _) | TypeBody::List(_) =>
          raise SchemaError::UnsupportedFeature(
            "valid_values is supported only for scalar Ion types at type \{named_type.name}",
          )
      }
      match named_type.body {
        TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
          for candidate in valid_values {
            match candidate.annotations() {
              [] => ()
              [annotation] if annotation.text_value() == Some("range") =>
                validate_valid_values_range(
                  types,
                  type_ref,
                  candidate,
                  "type \{named_type.name}",
                )
              _ =>
                raise SchemaError::UnsupportedFeature(
                  "valid_values entries must be unannotated values or range:: constraints at type \{named_type.name}",
                )
            }
          }
        TypeBody::Struct(_, _) | TypeBody::List(_) => ()
      }
    }
    match named_type.body {
      TypeBody::Scalar(type_ref) | TypeBody::Alias(type_ref) =>
        validate_type_reference(types, type_ref, named_type.name)
      TypeBody::List(type_ref) =>
        validate_type_reference(
          types,
          type_ref,
          "element of \{named_type.name}",
        )
      TypeBody::Struct(fields, _) =>
        for field in fields {
          let occurrence = if field.occurrence.min_count == 1 &&
            field.occurrence.max_count == Some(1) {
            "required"
          } else if field.occurrence.min_count == 0 &&
            field.occurrence.max_count == Some(1) {
            "optional"
          } else {
            "repeated"
          }
          validate_type_reference(
            types,
            field.type_ref,
            "\{occurrence} field \{named_type.name}.\{field.name}",
          )
        }
    }
  }
}

///|
fn is_valid_values_target(types : Array[NamedType], type_ref : TypeRef) -> Bool {
  is_valid_values_target_with_depth(types, type_ref, types.length())
}

///|
fn is_valid_values_target_with_depth(
  types : Array[NamedType],
  type_ref : TypeRef,
  remaining : Int,
) -> Bool {
  if remaining < 0 {
    return false
  }
  match type_ref {
    TypeRef::Builtin(name) => is_valid_values_scalar_name(name)
    TypeRef::Named(name) =>
      match find_named_type(types, name) {
        Some(named_type) =>
          match named_type.body {
            TypeBody::Scalar(inner) | TypeBody::Alias(inner) =>
              is_valid_values_target_with_depth(types, inner, remaining - 1)
            TypeBody::Struct(_, _) | TypeBody::List(_) => false
          }
        None => false
      }
    TypeRef::NullOrBuiltin(name) => is_valid_values_scalar_name(name)
    TypeRef::NullOrNamed(name) =>
      match find_named_type(types, name) {
        Some(named_type) =>
          match named_type.body {
            TypeBody::Scalar(inner) | TypeBody::Alias(inner) =>
              is_valid_values_target_with_depth(types, inner, remaining - 1)
            TypeBody::Struct(_, _) | TypeBody::List(_) => false
          }
        None => false
      }
  }
}

///|
fn is_valid_values_scalar_name(name : String) -> Bool {
  contains_string(
    [
      "bool", "int", "float", "decimal", "string", "symbol", "timestamp", "blob",
      "number", "clob", "$null", "$bool", "$int", "$float", "$decimal", "$string",
      "$symbol", "$timestamp", "$blob", "$clob", "$number", "$text", "$lob",
    ],
    name,
  )
}

///|
fn validate_valid_values_range(
  types : Array[NamedType],
  type_ref : TypeRef,
  range : @model.IonValue,
  context : String,
) -> Unit raise SchemaError {
  match range.without_annotations() {
    @model.IonValue::List([minimum, maximum]) => {
      let (minimum_kind, _) = parse_range_endpoint(minimum, true, context)
      let (maximum_kind, _) = parse_range_endpoint(maximum, false, context)
      if minimum_kind == "min" && maximum_kind == "max" {
        raise SchemaError::InvalidSchema(
          "a valid_values range cannot use both min and max at " + context,
        )
      }
      let range_kind = if minimum_kind == "min" {
        maximum_kind
      } else if maximum_kind == "max" {
        minimum_kind
      } else if minimum_kind == maximum_kind {
        minimum_kind
      } else {
        raise SchemaError::InvalidSchema(
          "valid_values range bounds must have the same Ion type at " + context,
        )
      }
      if !valid_values_range_type(types, type_ref, range_kind) {
        raise SchemaError::InvalidSchema(
          "a " +
          range_kind +
          " valid_values range does not apply to the declared type at " +
          context,
        )
      }
    }
    _ =>
      raise SchemaError::InvalidSchema(
        "valid_values range must contain exactly two bounds at " + context,
      )
  }
}

///|
fn parse_range_endpoint(
  value : @model.IonValue,
  is_minimum : Bool,
  context : String,
) -> (String, Bool) raise SchemaError {
  let exclusive = match value.annotations() {
    [] => false
    [annotation] if annotation.text_value() == Some("exclusive") => true
    _ =>
      raise SchemaError::UnsupportedFeature(
        "range bounds may only use the exclusive annotation at " + context,
      )
  }
  let kind = match value.without_annotations() {
    @model.IonValue::Symbol(symbol) =>
      match symbol.text_value() {
        Some("min") => "min"
        Some("max") => "max"
        _ =>
          raise SchemaError::InvalidSchema(
            "range symbol bounds must be min or max at " + context,
          )
      }
    @model.IonValue::Int(_) => "int"
    @model.IonValue::Decimal(_) => "decimal"
    @model.IonValue::Float(number) =>
      if number.is_nan() || number.is_inf() {
        raise SchemaError::InvalidSchema(
          "range bounds must be finite numbers at " + context,
        )
      } else {
        "float"
      }
    @model.IonValue::Timestamp(_) => "timestamp"
    _ =>
      raise SchemaError::InvalidSchema(
        "range bounds must be numbers, timestamps, min, or max at " + context,
      )
  }
  if kind == "min" && !is_minimum {
    raise SchemaError::InvalidSchema(
      "min is only valid as the first range bound at " + context,
    )
  }
  if kind == "max" && is_minimum {
    raise SchemaError::InvalidSchema(
      "max is only valid as the second range bound at " + context,
    )
  }
  if (kind == "min" || kind == "max") && exclusive {
    raise SchemaError::InvalidSchema(
      "min and max cannot use the exclusive annotation at " + context,
    )
  }
  (kind, exclusive)
}

///|
fn valid_values_range_type(
  types : Array[NamedType],
  type_ref : TypeRef,
  range_kind : String,
) -> Bool raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar(name) =>
      if contains_string(["int", "float", "decimal"], range_kind) {
        contains_string(
          [
            "int", "float", "decimal", "number", "$int", "$float", "$decimal", "$number",
          ],
          name,
        )
      } else {
        name == "timestamp" || name == "$timestamp"
      }
    ResolvedType::Struct(_) | ResolvedType::List(_) => false
  }
}

///|
fn validate_type_reference(
  types : Array[NamedType],
  type_ref : TypeRef,
  context : String,
) -> Unit raise SchemaError {
  match type_ref {
    TypeRef::Builtin(name) =>
      if !is_supported_scalar(name) {
        raise SchemaError::UnsupportedFeature(
          "unsupported built-in type \{name} at \{context}",
        )
      }
    TypeRef::Named(name) if contains_type(types, name) => ()
    TypeRef::Named(name) =>
      raise SchemaError::UnknownType("unknown type \{name} at \{context}")
    TypeRef::NullOrBuiltin(name) =>
      if !is_supported_scalar(name) {
        raise SchemaError::UnsupportedFeature(
          "unsupported nullable built-in type \{name} at \{context}",
        )
      }
    TypeRef::NullOrNamed(name) if contains_type(types, name) => ()
    TypeRef::NullOrNamed(name) =>
      raise SchemaError::UnknownType("unknown type \{name} at \{context}")
  }
}

///|
fn is_document_reference(
  types : Array[NamedType],
  type_ref : TypeRef,
) -> Bool raise SchemaError {
  match resolve_type_ref(types, type_ref) {
    ResolvedType::Scalar("document") => true
    _ => false
  }
}

///|
fn validate_type_algebra_reference(
  types : Array[NamedType],
  type_ref : TypeRef,
  context : String,
) -> Unit raise SchemaError {
  match type_ref {
    TypeRef::Builtin("text" | "lob") | TypeRef::NullOrBuiltin("text" | "lob") =>
      ()
    _ => validate_type_reference(types, type_ref, context)
  }
}

///|
fn is_supported_scalar(name : String) -> Bool {
  contains_string(
    [
      "bool", "int", "float", "decimal", "string", "symbol", "timestamp", "blob",
      "clob", "sexp", "any", "$any", "number", "document", "struct", "list", "$null",
      "$bool", "$int", "$float", "$decimal", "$string", "$symbol", "$timestamp",
      "$blob", "$clob", "$list", "$sexp", "$struct", "$number", "$text", "$lob",
    ],
    name,
  )
}

///|
fn is_known_builtin(name : String) -> Bool {
  contains_string(
    [
      "any", "$any", "null", "$null", "nothing", "lob", "$lob", "number", "$number",
      "text", "$text", "sexp", "$sexp", "document", "$document", "$blob", "$bool",
      "$clob", "$decimal", "$float", "$int", "$string", "$symbol", "$timestamp",
      "$list", "$struct",
    ],
    name,
  ) ||
  is_supported_scalar(name) ||
  name == "struct" ||
  name == "list"
}

///|
fn contains_type(types : Array[NamedType], name : String) -> Bool {
  for named_type in types {
    if named_type.name == name {
      return true
    }
  }
  false
}

///|
fn contains_field(fields : Array[FieldSpec], name : String) -> Bool {
  for field in fields {
    if field.name == name {
      return true
    }
  }
  false
}

///|
fn contains_string(values : Array[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}
