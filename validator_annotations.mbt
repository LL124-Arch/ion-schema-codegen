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
    if !constraint.standard_inline {
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
            label, annotation_path, "annotations", "allowed and required annotation set",
            "annotation mismatch", quiet,
          ),
        )
        valid = false
      }
      continue
    }
    if !validator_ranges(
        context,
        constraint.standard_container_lengths,
        Some(tokens.length()),
        annotation_path,
        label,
        "annotations.container_length",
        quiet,
      ) {
      valid = false
    }
    match constraint.standard_contains_values {
      Some(required) =>
        for name in required {
          let mut found = false
          for symbol in symbols {
            context.tick()
            if symbol.text_value() == Some(name) {
              found = true
              break
            }
          }
          if !found {
            ignore(
              context.reject(
                label, annotation_path, "annotations.contains", name, "missing",
                quiet,
              ),
            )
            valid = false
          }
        }
      None => ()
    }
    for index in 0..<tokens.length() {
      let token = tokens[index]
      let child_path = validator_path(annotation_path, Index(index))
      match constraint.standard_element_valid_values {
        Some(allowed) => {
          let mut found = false
          for name in allowed {
            context.tick()
            if symbols[index].text_value() == Some(name) {
              found = true
              break
            }
          }
          if !found {
            ignore(
              context.reject(
                label,
                child_path,
                "annotations.element.valid_values",
                "allowed symbol",
                symbols[index].display(),
                quiet,
              ),
            )
            valid = false
          }
        }
        None => ()
      }
      for regex in constraint.standard_element_regexes {
        context.tick()
        if !validator_support_regex_matches(token, regex.pattern) {
          ignore(
            context.reject(
              label,
              child_path,
              "annotations.element.regex",
              regex.pattern,
              symbols[index].display(),
              quiet,
            ),
          )
          valid = false
        }
      }
      if !validator_ranges(
          context,
          constraint.standard_element_codepoint_lengths,
          validator_support_codepoint_length(token),
          child_path,
          label,
          "annotations.element.codepoint_length",
          quiet,
        ) {
        valid = false
      }
      if !validator_ranges(
          context,
          constraint.standard_element_utf8_byte_lengths,
          validator_support_utf8_byte_length(token),
          child_path,
          label,
          "annotations.element.utf8_byte_length",
          quiet,
        ) {
        valid = false
      }
    }
    match constraint.standard_ordered_elements {
      Some(pattern) =>
        if !validator_ordered(
            context,
            pattern,
            tokens,
            annotation_path,
            depth + 1,
            label,
          ) {
          ignore(
            context.reject(
              label, annotation_path, "annotations.ordered_elements", "complete annotation sequence",
              "annotation mismatch", quiet,
            ),
          )
          valid = false
        }
      None => ()
    }
  }
  valid
}
