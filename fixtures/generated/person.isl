$ion_schema_2_0
type::{name: Person, type: struct, fields: closed::{
  id: {type: int, occurs: required},
  name: {type: string, occurs: required},
  enabled: bool,
  ratio: float,
  amount: decimal,
  code: symbol,
  created: timestamp,
  payload: blob,
  note: clob
}}
