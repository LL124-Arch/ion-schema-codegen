///|
pub(all) suberror ValidationError {
  UnknownType(String)
  InvalidLimits(String)
  IonInput(String)
  InputKind(String)
}

///|
pub(all) enum ValidationStatus {
  Valid
  Invalid
  Incomplete
} derive(Eq)

///|
pub extend ValidationStatus with Eq::{equal, not_equal}

///|
/// Field occurrence is zero-based and distinguishes repeated Ion struct keys.
pub(all) enum ValidationPathSegment {
  Index(Int)
  Field(name~ : String?, sid~ : Int?, occurrence~ : Int)
  Annotations
} derive(Eq)

///|
pub extend ValidationPathSegment with Eq::{equal, not_equal}

///|
pub(all) struct ValidationDiagnostic {
  type_name : String
  path : Array[ValidationPathSegment]
  constraint : String
  expected : String
  actual : String
}

///|
pub(all) struct ValidationReport {
  status : ValidationStatus
  diagnostics : Array[ValidationDiagnostic]
  steps : Int
}

///|
/// Interpreter limits; parsing and regex-engine work are outside the step count.
pub(all) struct ValidationLimits {
  max_depth : Int
  max_nodes : Int
  max_steps : Int
  max_diagnostics : Int
}

///|
pub fn ValidationLimits::default() -> ValidationLimits {
  { max_depth: 64, max_nodes: 10000, max_steps: 100000, max_diagnostics: 100, }
}

///|
pub fn ValidationReport::is_valid(self : ValidationReport) -> Bool {
  self.status is Valid
}

///|
pub fn ValidationReport::to_json(self : ValidationReport) -> Json {
  let diagnostics : Array[Json] = []
  for diagnostic in self.diagnostics {
    let segments : Array[Json] = []
    for segment in diagnostic.path {
      segments.push(
        match segment {
          Index(index) => { "kind": "index", "index": index.to_json() }
          Annotations => { "kind": "annotations" }
          Field(name~, sid~, occurrence~) =>
            {
              "kind": "field",
              "name": match name {
                Some(name) => name.to_json()
                None => Json::null()
              },
              "sid": match sid {
                Some(sid) => sid.to_json()
                None => Json::null()
              },
              "occurrence": occurrence.to_json(),
            }
        },
      )
    }
    diagnostics.push({
      "type": diagnostic.type_name.to_json(),
      "path": Json::array(segments),
      "constraint": diagnostic.constraint.to_json(),
      "expected": diagnostic.expected.to_json(),
      "actual": diagnostic.actual.to_json(),
    })
  }
  {
    "status": (match self.status {
      Valid => "valid"
      Invalid => "invalid"
      Incomplete => "incomplete"
    }).to_json(),
    "diagnostics": Json::array(diagnostics),
    "steps": self.steps.to_json(),
  }
}

///|
pub struct SchemaValidator {
  priv types : Array[NamedType]
}

///|
priv enum ValidatorInput {
  Value(@model.IonValue)
  Document(Array[@model.IonValue])
}

///|
priv suberror ValidatorStop {
  Limit(String)
}

///|
priv struct ValidatorContext {
  types : Array[NamedType]
  limits : ValidationLimits
  diagnostics : Array[ValidationDiagnostic]
  mut steps : Int
  mut nodes : Int
}

///|
fn ValidatorContext::tick(self : ValidatorContext) -> Unit raise ValidatorStop {
  if self.steps >= self.limits.max_steps {
    raise Limit("max_steps")
  }
  self.steps += 1
}

///|
fn ValidatorContext::reject(
  self : ValidatorContext,
  label : String,
  path : Array[ValidationPathSegment],
  constraint : String,
  expected : String,
  actual : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  if !quiet {
    if self.diagnostics.length() >= self.limits.max_diagnostics {
      raise Limit("max_diagnostics")
    }
    self.diagnostics.push({
      type_name: label,
      path: path.copy(),
      constraint,
      expected,
      actual,
    })
  }
  false
}

///|
fn validator_path(
  path : Array[ValidationPathSegment],
  segment : ValidationPathSegment,
) -> Array[ValidationPathSegment] {
  let result = path.copy()
  result.push(segment)
  result
}

///|
fn ValidatorInput::actual(self : ValidatorInput) -> String {
  match self {
    Value(value) => validator_support_actual_type(value)
    Document(_) => "document"
  }
}

///|
fn ValidatorInput::values(self : ValidatorInput) -> Array[@model.IonValue]? {
  match self {
    Document(values) => Some(values)
    Value(value) =>
      match value.without_annotations() {
        @model.IonValue::List(values) | @model.IonValue::Sexp(values) =>
          Some(values)
        @model.IonValue::Struct(fields) => {
          let values : Array[@model.IonValue] = []
          for (_, value) in fields {
            values.push(value)
          }
          Some(values)
        }
        _ => None
      }
  }
}
