$ion_schema_2_0

type::{
  name: Person,
  type: struct,
  fields: closed::{
    name: string,
    age: { type: int, occurs: required },
    nickname: { type: string, occurs: optional },
  },
}
