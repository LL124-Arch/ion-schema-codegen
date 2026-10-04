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
type::{name: Expression, type: sexp}
type::{name: Expressions, type: list, element: Expression}
type::{name: ExpressionRecord, type: struct, fields: closed::{expression: {type: Expression, occurs: required}}}
type::{name: AnyValue, type: any}
type::{name: AnyValues, type: list, element: AnyValue}
type::{name: AnyRecord, type: struct, fields: closed::{named_value: {type: AnyValue, occurs: required}, raw: {type: any, occurs: required}, optional_raw: {type: any, occurs: optional}}}
