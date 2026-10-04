$ion_schema_2_0
type::{name: Person, type: struct, fields: closed::{
  primary: {type: Address, occurs: required},
  addresses: {type: AddressList, occurs: required},
  scores: {type: Scores, occurs: required},
  nickname: {type: string, occurs: optional}
}}
type::{name: AddressList, type: list, element: Address}
type::{name: Scores, type: list, element: Score}
type::{name: Address, type: struct, fields: closed::{city: string}}
type::{name: Score, type: int}
