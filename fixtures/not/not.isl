$ion_schema_2_0
type::{name: NotNumber, not: number}
type::{name: NotNumberAlias, type: NotNumber}
type::{name: NamedChoice, any_of: [int, string]}
type::{name: NotNamedChoice, not: NamedChoice}
type::{name: NotNamedChoiceAlias, type: NotNamedChoice}
type::{name: NotNullableInt, not: $null_or::int}
type::{name: NotNumberList, type: list, element: NotNumberAlias}
type::{name: NotNumberRecord, type: struct, fields: closed::{value: {type: NotNumberAlias, occurs: required}}}
