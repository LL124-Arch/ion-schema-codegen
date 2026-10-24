///|
// A document always fails annotations, so the generated failure needs only the
// presence of that constraint. Validate the original schema first, then omit
// private predicates that would otherwise be emitted without any caller.
fn codegen_reachable_types(
  types : Array[NamedType],
) -> Array[NamedType] raise SchemaError {
  let candidates : Array[NamedType] = []
  let active : Array[String] = []
  for target in types {
    if !target.is_inline {
      active.push(target.name)
    }
    let annotations = if named_type_is_document(target, types) {
      target.annotation_constraints.map(_ => {
        allowed: [],
        closed: false,
        required: false,
        standard_type_ref: None,
      })
    } else {
      target.annotation_constraints
    }
    candidates.push({ ..target, annotation_constraints: annotations, })
  }
  let mut index = 0
  while index < active.length() {
    match find_named_type(candidates, active[index]) {
      Some(target) =>
        for reference in referenced_type_names(target, true) {
          if !active.contains(reference) {
            active.push(reference)
          }
        }
      None => ()
    }
    index += 1
  }
  candidates.filter(target => active.contains(target.name))
}
