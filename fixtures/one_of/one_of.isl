$ion_schema_2_0
type::{name: IntegerOrText, one_of: [int, string]}
type::{name: OverlappingNumeric, one_of: [float, number]}
type::{name: RepeatedFloat, one_of: [float, float]}
type::{name: NullableOverlap, one_of: [$null_or::int, $null_or::float]}
type::{name: NullableTypedInt, one_of: [$null_or::$int, string]}
type::{name: IntegerOrTextAlias, type: IntegerOrText}
type::{name: ChoiceList, type: list, element: IntegerOrTextAlias}
type::{name: ChoiceRecord, type: struct, fields: closed::{value: {type: IntegerOrTextAlias, occurs: required}}}
