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
type::{name: NullableValue, type: $any}
type::{name: NullableValues, type: list, element: NullableValue}
type::{name: NullableRecord, type: struct, fields: closed::{value: {type: $any, occurs: required}, optional: {type: NullableValue, occurs: optional}}}
type::{name: EventStream, type: document}
type::{name: EventStreamAlias, type: EventStream}
type::{name: NullableInt, type: $int}
type::{name: NullableInts, type: list, element: NullableInt}
type::{name: NullableNominals, type: struct, fields: closed::{typed_int: {type: NullableInt, occurs: required}, plain_null: {type: $null, occurs: required}, maybe_text: $null_or::string, maybe_typed_int: $null_or::$int, optional_boolean: {type: $bool, occurs: optional}}}
type::{name: MaybeNumbers, type: list, element: $null_or::int}
type::{name: OccurrenceRecord, type: struct, fields: closed::{
  fixed: {type: string, occurs: 2},
  bounded: {type: int, occurs: range::[2, 4]},
  optional_name: {type: string, occurs: range::[0, 1]},
  at_least_one: {type: bool, occurs: range::[1, max]}
}}
type::{name: OpenRecord, type: struct, fields:{
  known: {type: string, occurs: required}
}}
type::{name: AllowedScore, type: int, valid_values: [10, 20]}
type::{name: AllowedScoreAlias, type: AllowedScore}
type::{name: AllowedScores, type: list, element: AllowedScoreAlias}
type::{name: ScoredRecord, type: struct, fields: closed::{
  score: {type: AllowedScoreAlias, occurs: required}
}}
