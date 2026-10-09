$ion_schema_2_0
type::{name: NumberOrText, any_of: [number, text]}
type::{name: NonNegativeSmall, type: int, valid_values: range::[0, 9]}
type::{name: NegativeSmall, type: int, valid_values: range::[-9, -1]}
type::{name: SignedSmall, any_of: [NonNegativeSmall, NegativeSmall]}
type::{name: Overlapping, any_of: [int, number]}
type::{name: MaybeInt, any_of: [$null_or::int, string]}
type::{name: NumberOrTextAlias, type: NumberOrText}
type::{name: ChoiceList, type: list, element: NumberOrTextAlias}
type::{name: ChoiceRecord, type: struct, fields: closed::{value: {type: NumberOrTextAlias, occurs: required}}}
type::{name: InlineNumberOrText, any_of: [{type: int, valid_values: [2, 4]}, string]}
type::{name: InlinePatternOrInt, any_of: [{type: string, regex: "^ion$"}, int]}
