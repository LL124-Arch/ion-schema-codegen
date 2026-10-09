$ion_schema_2_0
type::{name: Positive, type: int, valid_values: range::[1, max]}
type::{name: BelowTen, type: int, valid_values: range::[min, 9]}
type::{name: PositiveBelowTen, all_of: [Positive], all_of: [BelowTen]}
type::{name: PositiveBelowTenAlias, type: PositiveBelowTen}
type::{name: PositiveBelowTenList, type: list, element: PositiveBelowTenAlias}
type::{name: PositiveBelowTenRecord, type: struct, fields: closed::{value: {type: PositiveBelowTenAlias, occurs: required}}}
type::{name: MaybeInt, all_of: [$any, $null_or::int]}
type::{name: MaybeTypedInt, all_of: [$any, $null_or::$int]}
type::{name: InlineEven, all_of: [{type: int, valid_values: [2, 4]}]}
type::{name: MaybeInlineEven, all_of: [$null_or::{type: int, valid_values: [2]}]}
type::{name: InlineIntList, all_of: [{type: list, element: {type: int, valid_values: [2, 4]}, container_length: range::[1, 3]}]}
type::{name: InlineRecord, all_of: [{type: struct, fields: closed::{id: {type: int, valid_values: [7], occurs: required}, label: {type: string, regex: "^[a-z]+$", occurs: optional}}}]}
type::{name: InlineAlias, all_of: [{type: Positive, valid_values: [2, 4]}]}
type::{name: MaybeInlineIntList, all_of: [$null_or::{type: list, element: {type: int, valid_values: [2, 4]}}]}
