///|
fn show_policy(
  name : String,
  source : String,
  check : (@ion_model.IonValue) -> Unit raise ConversionError,
) -> Unit {
  let values = @ion.parse_text(source) catch { _ => [] }
  let value = match values {
    [value] => value
    _ => abort("example requires one Ion value")
  }
  let accepted = try {
    check(value)
    true
  } catch {
    _ => false
  }
  println(
    Json::object(
      Map([("case", name.to_json()), ("accepted", accepted.to_json())]),
    ).stringify(),
  )
}

///|
fn main {
  for
    (name, source, check) in [
      (
        "approved_record", "record::approved::v1::{id:1}", validate_annotations_Envelope,
      ),
      ("draft_record", "record::draft::{id:1}", validate_annotations_Envelope),
      (
        "overlapping_stages", "record::approved::draft::1", validate_annotations_Envelope,
      ),
      (
        "duplicate_tags", "record::approved::approved::1", validate_annotations_Envelope,
      ),
      ("wrong_order", "approved::record::1", validate_annotations_Envelope),
      (
        "unsupported_token", "record::approved::other::1", validate_annotations_Envelope,
      ),
      (
        "element_intersection", "approved::1", validate_annotations_RepeatedElement,
      ),
      (
        "element_outside_intersection", "record::1", validate_annotations_RepeatedElement,
      ),
      ("value_intersection", "approved::1", validate_annotations_RepeatedValues),
      (
        "value_outside_intersection", "draft::1", validate_annotations_RepeatedValues,
      ),
      ("exact_sequence", "record::v2::1", validate_annotations_ExactSequence),
      (
        "reversed_exact_sequence", "v2::record::1", validate_annotations_ExactSequence,
      ),
      (
        "required_prefix", "record::record::1", validate_annotations_OrderedMinimum,
      ),
      (
        "bad_required_prefix", "other::record::1", validate_annotations_OrderedMinimum,
      ),
      ("nullable_inline", "record::null", validate_annotations_NullableInline),
      ("missing_required_symbol", "null", validate_annotations_NullableInline),
      (
        "unannotated_symbol_tokens", "record::approved::1", validate_annotations_NestedAnnotations,
      ),
      ("public_token", "record::1", validate_annotations_PublicTokens),
      ("private_token", "internal_secret::1", validate_annotations_PublicTokens),
      ("empty_predicate", "1", validate_annotations_AnyAnnotations),
      ("list_conjunction", "record::v1::1", validate_annotations_AllOfPolicy),
      (
        "inline_import_element", "approved::draft::1", validate_annotations_ImportedTokens,
      ),
      (
        "inline_import_rejects_unknown", "other::1", validate_annotations_ImportedTokens,
      ),
      ("import_scope", "record::1", validate_annotations_ImportedList),
      ("literal_is_not_import", "record::1", validate_annotations_LiteralSafe),
    ] {
    show_policy(name, source, check)
  }
  show_policy("imported_field_names", "{payload:{approved:1,draft:2}}", value => {
    ignore(WorkflowMessage::from_ion(value))
  })
  show_policy("unknown_field_name", "{payload:{unknown:1}}", value => {
    ignore(WorkflowMessage::from_ion(value))
  })
  show_policy("typed_audit_record", "{payload:record::approved::v1::{id:1}}", value => {
    ignore(AuditRecord::from_ion(value))
  })
  let stream_accepted = try {
    ignore(from_ion_document_AnnotationFreeStream([]))
    true
  } catch {
    _ => false
  }
  println(
    Json::object(
      Map([
        ("case", "document_has_no_annotations"),
        ("accepted", stream_accepted.to_json()),
      ]),
    ).stringify(),
  )
}
