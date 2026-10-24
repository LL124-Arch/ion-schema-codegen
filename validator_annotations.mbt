///|
fn validator_check_annotations(
  context : ValidatorContext,
  target : NamedType,
  input : ValidatorInput,
  path : Array[ValidationPathSegment],
  depth : Int,
  label : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  let mut valid = true
  let annotation_path = validator_path(path, Annotations)
  for constraint in target.annotation_constraints {
    context.tick()
    let symbols = match input {
      Value(value) => value.annotations()
      Document(_) => {
        ignore(
          context.reject(
            label, annotation_path, "annotations", "annotatable Ion value", "document",
            quiet,
          ),
        )
        valid = false
        continue
      }
    }
    let tokens : Array[@model.IonValue] = []
    for symbol in symbols {
      context.tick()
      tokens.push(@model.IonValue::Symbol(symbol))
    }
    match constraint.standard_type_ref {
      Some(reference) => {
        if !validator_check_ref(
            context,
            reference,
            Value(@model.IonValue::List(tokens)),
            annotation_path,
            depth + 1,
            label,
            quiet,
          ) {
          valid = false
        }
        continue
      }
      None => ()
    }
    let value = match input {
      Value(value) => value
      _ => @model.IonValue::Null(@model.IonNull::Null)
    }
    if !validator_support_annotations_match(
        value,
        constraint.allowed,
        constraint.closed,
        constraint.required,
      ) {
      ignore(
        context.reject(
          label,
          annotation_path,
          "annotations",
          (if constraint.closed { "closed " } else { "" }) +
          (if constraint.required { "required " } else { "" }) +
          constraint.allowed.join(","),
          symbols.map(symbol => symbol.display()).join("::"),
          quiet,
        ),
      )
      valid = false
    }
  }
  valid
}
