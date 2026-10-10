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
type::{name: InlineConstrainedList, all_of: [{type: list, element: distinct::int, contains: [2], container_length: range::[2, 3]}]}
type::{name: InlineConstrainedRecord, all_of: [{type: struct, fields: {id: {type: int, occurs: required}}, element: distinct::int, field_names: distinct::symbol, contains: [2], container_length: range::[1, 3]}]}
type::{name: InlineRecordEnvelope, type: struct, fields: closed::{payload: {type: InlineConstrainedRecord, occurs: required}}}
type::{name: InlineOrderedList, all_of: [{type: list, ordered_elements: [{type: int, valid_values: [2, 4], occurs: required}, {type: string, regex: "^done$", occurs: optional}]}]}
type::{name: InlinePositiveBelowTen, all_of: [{type: int, all_of: [Positive, BelowTen]}]}
type::{name: InlineAnyPositiveOrString, all_of: [{any_of: [Positive, string]}]}
type::{name: InlineOneOf, all_of: [{one_of: [int, string]}]}
type::{name: InlineOneOfOverlap, all_of: [{one_of: [Positive, BelowTen]}]}
type::{name: InlineNotPositive, all_of: [{not: Positive}]}
type::{name: InlineNotExactTwo, all_of: [{not: {type: int, valid_values: [2]}}]}
type::{name: InlineLogicalList, all_of: [{type: list, element: {type: int, all_of: [Positive, BelowTen]}, container_length: range::[1, 2]}]}
type::{name: InlineLogicalRecord, all_of: [{type: struct, fields: closed::{choice: {any_of: [Positive, string], occurs: required}}}]}
type::{name: InlineNullableLogical, all_of: [$null_or::{any_of: [Positive, string]}]}
type::{name: InlineLogicalEnvelope, type: struct, fields: closed::{payload: {type: InlineLogicalList, occurs: required}}}
