"Metadata before the version marker is outside the schema."
$ion_schema_2_0
schema_header::{
  user_reserved_fields: {type: [description]},
  _owner: "schema maintainers"
}
type::{
  name: Positive,
  type: int,
  valid_values: range::[1, max],
  description: "Positive integer, imported without metadata leakage."
}
schema_footer::{_source: "business schema"}
"Metadata after the footer is outside the schema."
