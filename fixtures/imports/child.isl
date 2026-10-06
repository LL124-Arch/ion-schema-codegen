$ion_schema_2_0
schema_header::{imports: [
  {id: "base.isl", type: Shared, as: ChildShared}
]}
type::{name: Envelope, type: struct, fields: closed::{
  value: {type: ChildShared, occurs: required}
}}
