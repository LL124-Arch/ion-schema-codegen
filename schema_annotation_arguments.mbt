///|
// ISL evaluates annotations over a known domain: a non-null list of non-null,
// unannotated symbols. Lower anonymous predicates to raw Ion-backed types in
// that domain, so their constraints use the same AST as ordinary types. The
// domain restriction is safe inside every logical branch, including `not`.
// Declared `type` constraints remain independent conjuncts, never overwritten.
fn annotation_type_argument(
  value : @model.IonValue,
  list_domain : Bool,
) -> @model.IonValue {
  let fields = match value.without_annotations() {
    @model.IonValue::Struct(fields) => fields
    _ => return value
  }
  if value.get_fields("id").length() > 0 {
    return value
  }
  let output : Array[(@model.IonSymbol, @model.IonValue)] = [
    (
      @model.IonSymbol::from_text("type"),
      @model.IonValue::Symbol(
        @model.IonSymbol::from_text(
          if list_domain {
            "$list"
          } else {
            "$symbol"
          },
        ),
      ),
    ),
  ]
  for (symbol, argument) in fields {
    let rewritten = match symbol.text_value() {
      Some("type") => {
        output.push(
          (
            @model.IonSymbol::from_text("all_of"),
            @model.IonValue::List([
              annotation_type_argument(argument, list_domain),
            ]),
          ),
        )
        continue
      }
      Some("all_of" | "any_of" | "one_of") =>
        annotation_argument_list(argument, list_domain)
      Some("not") => annotation_type_argument(argument, list_domain)
      Some("element") if list_domain =>
        annotation_type_argument(argument, false)
      Some("ordered_elements") if list_domain =>
        annotation_argument_list(argument, false)
      Some("annotations") => annotation_type_argument(argument, true)
      // contains/valid_values are literal Ion data; never rewrite their fields.
      _ => argument
    }
    output.push((symbol, rewritten))
  }
  @model.IonValue::Struct(output).with_annotations(value.annotations())
}

///|
fn annotation_argument_list(
  value : @model.IonValue,
  list_domain : Bool,
) -> @model.IonValue {
  match value.without_annotations() {
    @model.IonValue::List(items) =>
      @model.IonValue::List(
        items.map(item => annotation_type_argument(item, list_domain)),
      ).with_annotations(value.annotations())
    _ => value
  }
}
