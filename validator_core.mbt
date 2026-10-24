///|
fn validator_check_ref(
  context : ValidatorContext,
  reference : TypeRef,
  input : ValidatorInput,
  path : Array[ValidationPathSegment],
  depth : Int,
  label : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  context.tick()
  if depth > context.limits.max_depth {
    raise Limit("max_depth")
  }
  match reference {
    TypeRef::NullOrBuiltin(name) | TypeRef::NullOrNamed(name) => {
      match input {
        Value(value) if validator_support_matches_type(value, "$null") =>
          return true
        _ => ()
      }
      let inner = match reference {
        TypeRef::NullOrBuiltin(_) => TypeRef::Builtin(name)
        _ => TypeRef::Named(name)
      }
      validator_check_ref(context, inner, input, path, depth + 1, label, quiet)
    }
    TypeRef::Builtin(name) => {
      let valid = match input {
        Value(value) => validator_support_matches_type(value, name)
        Document(_) => name == "document" || name == "any"
      }
      valid || context.reject(label, path, "type", name, input.actual(), quiet)
    }
    TypeRef::Named(name) =>
      match find_named_type(context.types, name) {
        Some(target) =>
          validator_check_named(
            context,
            target,
            input,
            path,
            depth + 1,
            if target.is_inline {
              label
            } else {
              name
            },
            quiet,
          )
        None =>
          context.reject(label, path, "type", name, "unresolved type", quiet)
      }
  }
}

///|
fn validator_check_named(
  context : ValidatorContext,
  target : NamedType,
  input : ValidatorInput,
  path : Array[ValidationPathSegment],
  depth : Int,
  label : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  context.tick()
  if depth > context.limits.max_depth {
    raise Limit("max_depth")
  }
  let base_valid = match target.body {
    TypeBody::Scalar(reference) | TypeBody::Alias(reference) =>
      validator_check_ref(
        context,
        reference,
        input,
        path,
        depth + 1,
        label,
        quiet,
      )
    TypeBody::List(_) =>
      match input {
        Value(value) if validator_support_matches_type(value, "list") => true
        _ => context.reject(label, path, "type", "list", input.actual(), quiet)
      }
    TypeBody::Struct(fields, is_open) =>
      validator_check_fields(
        context, fields, is_open, input, path, depth, label, quiet,
      )
  }
  if !base_valid {
    return false
  }
  let mut valid = validator_check_scalars(
    context, target, input, path, label, quiet,
  )
  if !validator_check_containers(
      context, target, input, path, depth, label, quiet,
    ) {
    valid = false
  }
  if !validator_check_annotations(
      context, target, input, path, depth, label, quiet,
    ) {
    valid = false
  }
  for reference in target.all_of {
    if !validator_check_ref(
        context,
        reference,
        input,
        path,
        depth + 1,
        label,
        quiet,
      ) {
      valid = false
    }
  }
  for branches in target.any_of {
    let mut matched = false
    for reference in branches {
      if validator_check_ref(
          context,
          reference,
          input,
          path,
          depth + 1,
          label,
          true,
        ) {
        matched = true
        break
      }
    }
    if !matched {
      ignore(
        context.reject(
          label,
          path,
          "any_of",
          "at least one matching type",
          input.actual(),
          quiet,
        ),
      )
      valid = false
    }
  }
  for branches in target.one_of {
    let mut matches = 0
    for reference in branches {
      if validator_check_ref(
          context,
          reference,
          input,
          path,
          depth + 1,
          label,
          true,
        ) {
        matches += 1
      }
    }
    if matches != 1 {
      ignore(
        context.reject(
          label,
          path,
          "one_of",
          "exactly one matching type",
          matches.to_string(),
          quiet,
        ),
      )
      valid = false
    }
  }
  for reference in target.not_constraints {
    if validator_check_ref(
        context,
        reference,
        input,
        path,
        depth + 1,
        label,
        true,
      ) {
      ignore(
        context.reject(
          label,
          path,
          "not",
          "nonmatching type",
          input.actual(),
          quiet,
        ),
      )
      valid = false
    }
  }
  valid
}

///|
fn validator_check_fields(
  context : ValidatorContext,
  specs : Array[FieldSpec],
  is_open : Bool,
  input : ValidatorInput,
  path : Array[ValidationPathSegment],
  depth : Int,
  label : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  let fields = match input {
    Value(value) =>
      match value.without_annotations() {
        @model.IonValue::Struct(fields) => fields
        _ =>
          return context.reject(
            label,
            path,
            "type",
            "struct",
            input.actual(),
            quiet,
          )
      }
    _ =>
      return context.reject(
        label,
        path,
        "type",
        "struct",
        input.actual(),
        quiet,
      )
  }
  let counts : Array[Int] = []
  for _ in specs {
    counts.push(0)
  }
  let mut valid = true
  let previous : Array[@model.IonSymbol] = []
  for (symbol, item) in fields {
    context.tick()
    let mut occurrence = 0
    for prior in previous {
      context.tick()
      if validator_support_symbols_equal(prior, symbol) {
        occurrence += 1
      }
    }
    previous.push(symbol)
    let child_path = validator_path(
      path,
      Field(name=symbol.text_value(), sid=symbol.sid_value(), occurrence~),
    )
    let mut known = false
    for index in 0..<specs.length() {
      context.tick()
      let spec = specs[index]
      if symbol.text_value() == Some(spec.name) {
        known = true
        counts[index] += 1
        if !validator_check_ref(
            context,
            spec.type_ref,
            Value(item),
            child_path,
            depth + 1,
            label,
            quiet,
          ) {
          valid = false
        }
      }
    }
    if !known && !is_open {
      ignore(
        context.reject(
          label,
          child_path,
          "fields.closed",
          "declared field",
          symbol.display(),
          quiet,
        ),
      )
      valid = false
    }
  }
  for index in 0..<specs.length() {
    let spec = specs[index]
    let count = counts[index]
    if count < spec.occurrence.min_count ||
      (spec.occurrence.max_count is Some(maximum) && count > maximum) {
      let occurrence = match spec.occurrence.max_count {
        Some(maximum) if count > maximum => maximum
        _ => count
      }
      let child_path = validator_path(
        path,
        Field(name=Some(spec.name), sid=None, occurrence~),
      )
      ignore(
        context.reject(
          label,
          child_path,
          "occurs",
          validator_occurs_text(spec.occurrence),
          count.to_string(),
          quiet,
        ),
      )
      valid = false
    }
  }
  valid
}

///|
fn validator_occurs_text(occurrence : FieldOccurrence) -> String {
  let maximum = match occurrence.max_count {
    Some(maximum) => maximum.to_string()
    None => "max"
  }
  occurrence.min_count.to_string() + ".." + maximum
}
