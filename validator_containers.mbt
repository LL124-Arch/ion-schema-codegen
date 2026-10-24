///|
fn validator_check_containers(
  context : ValidatorContext,
  target : NamedType,
  input : ValidatorInput,
  path : Array[ValidationPathSegment],
  depth : Int,
  label : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  let values = input.values()
  let length = match input {
    Document(items) => Some(items.length())
    Value(value) => validator_support_container_length(value)
  }
  let mut valid = validator_ranges(
    context,
    target.container_lengths,
    length,
    path,
    label,
    "container_length",
    quiet,
  )
  match values {
    Some(items) => {
      match target.contains_values {
        Some(required) =>
          for expected in required {
            let mut found = false
            for item in items {
              context.tick()
              if validator_support_values_equal(item, expected) {
                found = true
                break
              }
            }
            if !found {
              ignore(
                context.reject(
                  label, path, "contains", "required Ion value", "missing", quiet,
                ),
              )
              valid = false
            }
          }
        None => ()
      }
      if target.element_distinct {
        for index in 0..<items.length() {
          for prior in 0..<index {
            context.tick()
            if validator_support_values_equal(items[index], items[prior]) {
              ignore(
                context.reject(
                  label,
                  validator_container_path(context, input, path, index),
                  "element.distinct",
                  "unique Ion value",
                  "duplicate",
                  quiet,
                ),
              )
              valid = false
              break
            }
          }
        }
      }
      match target.element_type {
        Some(reference) =>
          match input {
            Value(value) =>
              match value.without_annotations() {
                @model.IonValue::Struct(fields) => {
                  let previous : Array[@model.IonSymbol] = []
                  for (symbol, item) in fields {
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
                      Field(
                        name=symbol.text_value(),
                        sid=symbol.sid_value(),
                        occurrence~,
                      ),
                    )
                    if !validator_check_ref(
                        context,
                        reference,
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
                _ =>
                  for index in 0..<items.length() {
                    if !validator_check_ref(
                        context,
                        reference,
                        Value(items[index]),
                        validator_path(path, Index(index)),
                        depth + 1,
                        label,
                        quiet,
                      ) {
                      valid = false
                    }
                  }
              }
            Document(_) =>
              for index in 0..<items.length() {
                if !validator_check_ref(
                    context,
                    reference,
                    Value(items[index]),
                    validator_path(path, Index(index)),
                    depth + 1,
                    label,
                    quiet,
                  ) {
                  valid = false
                }
              }
          }
        None => ()
      }
      match target.ordered_elements {
        Some(pattern) =>
          if !validator_ordered(context, pattern, items, path, depth + 1, label) {
            ignore(
              context.reject(
                label,
                path,
                "ordered_elements",
                "complete ordered sequence",
                input.actual(),
                quiet,
              ),
            )
            valid = false
          }
        None => ()
      }
    }
    None =>
      for
        (present, keyword) in [
          (target.contains_values is Some(_), "contains"),
          (target.element_type is Some(_), "element"),
          (target.ordered_elements is Some(_), "ordered_elements"),
        ] {
        if present {
          ignore(
            context.reject(
              label,
              path,
              keyword,
              "non-null container",
              input.actual(),
              quiet,
            ),
          )
          valid = false
        }
      }
  }
  match target.field_names_type {
    Some(reference) =>
      match input {
        Value(value) =>
          match value.without_annotations() {
            @model.IonValue::Struct(fields) => {
              let previous : Array[@model.IonSymbol] = []
              for (symbol, _) in fields {
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
                  Field(
                    name=symbol.text_value(),
                    sid=symbol.sid_value(),
                    occurrence~,
                  ),
                )
                if target.field_names_distinct && occurrence > 0 {
                  ignore(
                    context.reject(
                      label,
                      child_path,
                      "field_names.distinct",
                      "unique field name",
                      symbol.display(),
                      quiet,
                    ),
                  )
                  valid = false
                }
                if !validator_check_ref(
                    context,
                    reference,
                    Value(@model.IonValue::Symbol(symbol)),
                    child_path,
                    depth + 1,
                    label,
                    quiet,
                  ) {
                  valid = false
                }
              }
            }
            _ => {
              ignore(
                context.reject(
                  label,
                  path,
                  "field_names",
                  "non-null struct",
                  input.actual(),
                  quiet,
                ),
              )
              valid = false
            }
          }
        _ => {
          ignore(
            context.reject(
              label,
              path,
              "field_names",
              "non-null struct",
              input.actual(),
              quiet,
            ),
          )
          valid = false
        }
      }
    None => ()
  }
  valid
}

///|
fn validator_container_path(
  context : ValidatorContext,
  input : ValidatorInput,
  path : Array[ValidationPathSegment],
  index : Int,
) -> Array[ValidationPathSegment] raise ValidatorStop {
  match input {
    Value(value) =>
      match value.without_annotations() {
        @model.IonValue::Struct(fields) => {
          let symbol = fields[index].0
          let mut occurrence = 0
          for prior in 0..<index {
            context.tick()
            if validator_support_symbols_equal(fields[prior].0, symbol) {
              occurrence += 1
            }
          }
          validator_path(
            path,
            Field(name=symbol.text_value(), sid=symbol.sid_value(), occurrence~),
          )
        }
        _ => validator_path(path, Index(index))
      }
    _ => validator_path(path, Index(index))
  }
}

///|
fn validator_ordered(
  context : ValidatorContext,
  pattern : Array[OrderedElementSpec],
  values : Array[@model.IonValue],
  path : Array[ValidationPathSegment],
  depth : Int,
  label : String,
) -> Bool raise ValidatorStop {
  let count = values.length()
  // Check before allocation; multiplication cannot overflow this bounded budget.
  if count >= context.limits.max_steps ||
    pattern.length() >= context.limits.max_steps ||
    pattern.length() + 1 >
    (context.limits.max_steps - context.steps) / (count + 1) {
    raise Limit("max_steps")
  }
  let possible : Array[Array[Bool]] = []
  for _ in 0..<=pattern.length() {
    let row : Array[Bool] = []
    for _ in 0..<=count {
      context.tick()
      row.push(false)
    }
    possible.push(row)
  }
  possible[pattern.length()][count] = true
  let mut index = pattern.length()
  while index > 0 {
    index -= 1
    let spec = pattern[index]
    let matches : Array[Bool] = []
    for offset in 0..<count {
      matches.push(
        validator_check_ref(
          context,
          spec.type_ref,
          Value(values[offset]),
          validator_path(path, Index(offset)),
          depth + 1,
          label,
          true,
        ),
      )
    }
    for start in 0..<=count {
      let maximum = match spec.occurrence.max_count {
        Some(maximum) if maximum < count - start => maximum
        _ => count - start
      }
      for consumed in 0..<=maximum {
        context.tick()
        if consumed > 0 && !matches[start + consumed - 1] {
          break
        }
        if consumed >= spec.occurrence.min_count &&
          possible[index + 1][start + consumed] {
          possible[index][start] = true
          break
        }
      }
    }
  }
  possible[0][0]
}
