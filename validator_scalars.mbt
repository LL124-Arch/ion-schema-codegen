///|
fn validator_ranges(
  context : ValidatorContext,
  ranges : Array[IntegerRange],
  actual : Int?,
  path : Array[ValidationPathSegment],
  label : String,
  keyword : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  let mut valid = true
  for range in ranges {
    context.tick()
    match actual {
      Some(count) if count >= range.minimum &&
        (
          range.maximum is None ||
          (range.maximum is Some(maximum) && count <= maximum)
        ) => ()
      _ => {
        let expected = validator_occurs_text({
          min_count: range.minimum,
          max_count: range.maximum,
        })
        ignore(
          context.reject(
            label,
            path,
            keyword,
            expected,
            match actual {
              Some(count) => count.to_string()
              None => "inapplicable or null"
            },
            quiet,
          ),
        )
        valid = false
      }
    }
  }
  valid
}

///|
fn validator_check_scalars(
  context : ValidatorContext,
  target : NamedType,
  input : ValidatorInput,
  path : Array[ValidationPathSegment],
  label : String,
  quiet : Bool,
) -> Bool raise ValidatorStop {
  let value = match input {
    Value(value) => value
    Document(_) => @model.IonValue::Null(@model.IonNull::Null)
  }
  let mut valid = true
  match target.valid_values {
    Some(candidates) => {
      let mut matched = false
      for candidate in candidates {
        context.tick()
        if validator_support_valid_values_match(value, candidate) {
          matched = true
          break
        }
      }
      if !matched {
        ignore(
          context.reject(
            label,
            path,
            "valid_values",
            "allowed value or range",
            input.actual(),
            quiet,
          ),
        )
        valid = false
      }
    }
    None => ()
  }
  for
    (ranges, actual, keyword) in [
      (
        target.precision_ranges,
        validator_support_decimal_precision(value),
        "precision",
      ),
      (
        target.exponent_ranges,
        validator_support_decimal_exponent(value),
        "exponent",
      ),
      (
        target.timestamp_precision_ranges,
        validator_support_timestamp_precision(value),
        "timestamp_precision",
      ),
      (
        target.codepoint_lengths,
        validator_support_codepoint_length(value),
        "codepoint_length",
      ),
      (
        target.utf8_byte_lengths,
        validator_support_utf8_byte_length(value),
        "utf8_byte_length",
      ),
      (
        target.byte_lengths,
        match value.without_annotations() {
          @model.IonValue::Blob(bytes) | @model.IonValue::Clob(bytes) =>
            Some(bytes.length())
          _ => None
        },
        "byte_length",
      ),
    ] {
    if !validator_ranges(context, ranges, actual, path, label, keyword, quiet) {
      valid = false
    }
  }
  for offsets in target.timestamp_offsets {
    context.tick()
    if !validator_support_timestamp_offset_is_allowed(value, offsets) {
      ignore(
        context.reject(
          label,
          path,
          "timestamp_offset",
          "allowed timestamp offset",
          input.actual(),
          quiet,
        ),
      )
      valid = false
    }
  }
  for format in target.ieee754_float_formats {
    context.tick()
    if !validator_support_ieee754_float_compatible(value, format) {
      ignore(
        context.reject(
          label,
          path,
          "ieee754_float",
          format,
          input.actual(),
          quiet,
        ),
      )
      valid = false
    }
  }
  for regex in target.regex_constraints {
    context.tick()
    if !validator_support_regex_matches(value, regex.pattern) {
      ignore(
        context.reject(
          label,
          path,
          "regex",
          regex.pattern,
          input.actual(),
          quiet,
        ),
      )
      valid = false
    }
  }
  valid
}
