///|
fn validator_prepare(schema : Schema) -> SchemaValidator raise SchemaError {
  validate_type_references(schema.types)
  validate_recursive_alias_cycles(schema.types)
  validate_unguarded_type_cycles(schema.types)
  { types: schema.types, }
}

///|
/// Parse and prepare one supported ISL document once, without generating code.
/// File imports require the CLI or caller-provided resolved schema values.
pub fn SchemaValidator::new(
  source : String,
) -> SchemaValidator raise SchemaError {
  validator_prepare(parse_schema(source))
}

///|
/// Snapshot parsed schema values so later caller mutations cannot change rules.
pub fn SchemaValidator::from_ion_values(
  values : Array[@model.IonValue],
) -> SchemaValidator raise SchemaError {
  let context : ValidatorContext = {
    types: [],
    diagnostics: [],
    steps: 0,
    nodes: 0,
    limits: {
      max_depth: 256,
      max_nodes: 100000,
      max_steps: 1000000,
      max_diagnostics: 1,
    },
  }
  let copied : Array[@model.IonValue] = []
  for value in values {
    copied.push(
      validator_snapshot(context, value, 0) catch {
        Limit(name) =>
          raise SchemaError::InvalidSchema("schema snapshot exceeds " + name)
      },
    )
  }
  validator_prepare(parse_schema_values(copied))
}

///|
pub fn SchemaValidator::type_names(self : SchemaValidator) -> Array[String] {
  let names : Array[String] = []
  for named_type in self.types {
    if !named_type.is_inline {
      names.push(named_type.name)
    }
  }
  names
}

///|
pub fn SchemaValidator::validate(
  self : SchemaValidator,
  type_name : String,
  value : @model.IonValue,
  limits? : ValidationLimits = ValidationLimits::default(),
) -> ValidationReport raise ValidationError {
  self.run(type_name, Value(value), limits)
}

///|
pub fn SchemaValidator::validate_document(
  self : SchemaValidator,
  type_name : String,
  values : Array[@model.IonValue],
  limits? : ValidationLimits = ValidationLimits::default(),
) -> ValidationReport raise ValidationError {
  self.run(type_name, Document(values), limits)
}

///|
pub fn SchemaValidator::validate_text(
  self : SchemaValidator,
  type_name : String,
  text : String,
  limits? : ValidationLimits = ValidationLimits::default(),
) -> ValidationReport raise ValidationError {
  let values = @ion.parse_text(text) catch {
    error => raise ValidationError::IonInput(error.summary())
  }
  match values {
    [value] => self.validate(type_name, value, limits~)
    _ =>
      raise ValidationError::InputKind(
        "validate_text requires exactly one Ion value",
      )
  }
}

///|
pub fn SchemaValidator::validate_document_text(
  self : SchemaValidator,
  type_name : String,
  text : String,
  limits? : ValidationLimits = ValidationLimits::default(),
) -> ValidationReport raise ValidationError {
  let values = @ion.parse_text(text) catch {
    error => raise ValidationError::IonInput(error.summary())
  }
  self.validate_document(type_name, values, limits~)
}

///|
fn SchemaValidator::run(
  self : SchemaValidator,
  type_name : String,
  input : ValidatorInput,
  limits : ValidationLimits,
) -> ValidationReport raise ValidationError {
  if limits.max_depth <= 0 ||
    limits.max_depth > 256 ||
    limits.max_nodes <= 0 ||
    limits.max_nodes > 1000000 ||
    limits.max_steps <= 0 ||
    limits.max_steps > 10000000 ||
    limits.max_diagnostics <= 0 ||
    limits.max_diagnostics > 10000 {
    raise ValidationError::InvalidLimits(
      "positive limits required; maximum depth/nodes/steps/diagnostics: 256/1000000/10000000/10000",
    )
  }
  let target = match find_named_type(self.types, type_name) {
    Some(target) if !target.is_inline => target
    _ => raise ValidationError::UnknownType(type_name)
  }
  let document = named_type_is_document(target, self.types) catch {
    _ => raise ValidationError::UnknownType(type_name)
  }
  match (document, input) {
    (true, Value(_)) =>
      raise ValidationError::InputKind(
        "use validate_document for a document type",
      )
    (false, Document(_)) =>
      raise ValidationError::InputKind("use validate for a single-value type")
    _ => ()
  }
  let context : ValidatorContext = {
    types: self.types,
    limits,
    diagnostics: [],
    steps: 0,
    nodes: 0,
  }
  let status = try {
    let input = match input {
      Value(value) => Value(validator_snapshot(context, value, 0))
      Document(values) => {
        let copied : Array[@model.IonValue] = []
        for value in values {
          copied.push(validator_snapshot(context, value, 0))
        }
        Document(copied)
      }
    }
    if validator_check_named(context, target, input, [], 0, type_name, false) {
      Valid
    } else {
      Invalid
    }
  } catch {
    Limit(name) => {
      let diagnostic : ValidationDiagnostic = {
        type_name,
        path: [],
        constraint: "limit",
        expected: "complete validation within limits",
        actual: name,
      }
      if context.diagnostics.length() < limits.max_diagnostics {
        context.diagnostics.push(diagnostic)
      } else {
        context.diagnostics[context.diagnostics.length() - 1] = diagnostic
      }
      Incomplete
    }
  }
  { status, diagnostics: context.diagnostics, steps: context.steps, }
}

///|
fn validator_snapshot(
  context : ValidatorContext,
  value : @model.IonValue,
  depth : Int,
) -> @model.IonValue raise ValidatorStop {
  context.tick()
  if depth > context.limits.max_depth {
    raise Limit("max_depth")
  }
  if context.nodes >= context.limits.max_nodes {
    raise Limit("max_nodes")
  }
  context.nodes += 1
  match value {
    @model.IonValue::Annotated(annotations, inner) => {
      for _ in annotations {
        context.tick()
      }
      validator_snapshot(context, inner, depth + 1).with_annotations(
        annotations[:],
      )
    }
    @model.IonValue::List(items) | @model.IonValue::Sexp(items) => {
      let copied : Array[@model.IonValue] = []
      for item in items {
        copied.push(validator_snapshot(context, item, depth + 1))
      }
      match value {
        @model.IonValue::List(_) => @model.IonValue::List(copied)
        _ => @model.IonValue::Sexp(copied)
      }
    }
    @model.IonValue::Struct(fields) => {
      let copied : Array[(@model.IonSymbol, @model.IonValue)] = []
      for (symbol, item) in fields {
        copied.push((symbol, validator_snapshot(context, item, depth + 1)))
      }
      @model.IonValue::Struct(copied)
    }
    _ => value
  }
}
