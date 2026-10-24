$ion_schema_2_0
"Open content between the version marker and the header."
schema_header::{
  imports: [{id: "common.isl", type: Positive, as: Quantity}],
  user_reserved_fields: {schema_header: [owner], type: [description], schema_footer: [revision]},
  owner: "MoonBit application"
}
type::{
  name: Limited,
  type: int,
  type: number,
  valid_values: range::[0, 100],
  valid_values: [1, 2, 3, 4],
  description: "All four constraints apply to the same Ion value."
}
type::{
  name: Order,
  type: struct,
  fields: {quantity: {type: Limited, occurs: required}},
  fields: closed::{quantity: {type: Quantity, occurs: required}},
  field_names: symbol,
  field_names: distinct::symbol
}
_note::"Interleaved user content does not become a type or a constraint."
type::{
  name: Values,
  type: list,
  element: number,
  element: distinct::int,
  ordered_elements: [{type: int, occurs: range::[1, 3]}],
  ordered_elements: [{type: Limited, occurs: range::[1, 3]}]
}
type::{
  name: Stream,
  type: document,
  type: document,
  element: number,
  element: distinct::int,
  ordered_elements: [{type: int, occurs: range::[1, 3]}],
  ordered_elements: [{type: Limited, occurs: range::[1, 3]}]
}
type::{name: StreamAlias, type: Stream}
schema_footer::{revision: "2026-10-24"}
