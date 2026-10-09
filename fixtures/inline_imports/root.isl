$ion_schema_2_0
type::{name: InlineAll, all_of: [{id: "base.isl", type: LimitedInt}]}
type::{name: InlineAny, any_of: [{id: "base.isl", type: LimitedInt}, string]}
type::{name: InlineOne, one_of: [{id: "base.isl", type: LimitedInt}, string]}
type::{name: InlineNot, not: {id: "base.isl", type: LimitedInt}}
type::{name: InlineNullableNot, not: $null_or::{id: "base.isl", type: LimitedInt}}
type::{name: InlineRecord, type: struct, fields: closed::{count: {type: InlineAll, occurs: required}}}
type::{name: InlineList, type: list, element: InlineAll}
