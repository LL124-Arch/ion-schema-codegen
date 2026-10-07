$ion_schema_2_0
type::{name: RequiredValues, type: list, contains: [tag::1, {a: 1, b: 2}, tag::1]}
type::{name: RequiredIntValues, type: list, element: int, contains: [3]}
type::{name: NullableIntValues, type: list, element: $null_or::int, contains: [1]}
type::{name: RequiredExpression, type: sexp, contains: [ready]}
type::{name: RequiredFields, type: struct, contains: [green]}
type::{name: RequiredStream, type: document, contains: [1, 2]}
type::{name: RequiredStreamAlias, type: RequiredStream, contains: [3]}
type::{name: BaseFields, type: struct}
type::{name: RequiredFieldsAlias, type: BaseFields, contains: [blue]}
type::{name: BaseValues, type: list, element: $any}
type::{name: AliasValues, type: BaseValues, contains: [4], contains: [4]}
type::{name: ContainsHolder, type: struct, fields: closed::{expression: {type: RequiredExpression, occurs: required}, values: {type: AliasValues, occurs: required}, record: {type: RequiredFieldsAlias, occurs: required}}}
