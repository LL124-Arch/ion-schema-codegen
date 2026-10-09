$ion_schema_2_0
schema_header::{imports: [
  {id: "base.isl"},
  {id: "child.isl", type: Envelope, as: ImportedEnvelope}
]}
type::{name: ImportedExample, type: struct, fields: closed::{
  shared: {type: Shared, occurs: required},
  extra: {type: Extra, occurs: required},
  envelope: {type: ImportedEnvelope, occurs: required}
}}
type::{name: NotShared, not: Shared}
