$ion_schema_2_0
type::{name: UniqueInts, type: list, element: distinct::int}
type::{name: UniqueValues, type: list, element: distinct::$any}
type::{name: NullableUniqueValues, type: list, element: distinct::$null_or::int}
type::{name: UniqueExpression, type: sexp, element: distinct::$any}
type::{name: UniqueExpressionRecord, type: struct, fields: closed::{expression: {type: UniqueExpression, occurs: required}}}
type::{name: UniqueRecord, type: struct, element: distinct::$any}
type::{name: UniqueStream, type: document, element: distinct::$any}
type::{name: AllowedNames, type: symbol, valid_values: [alpha, beta]}
type::{name: NamedFields, type: struct, field_names: AllowedNames}
type::{name: UniqueFields, type: struct, field_names: distinct::AllowedNames}
type::{name: BaseFields, type: struct}
type::{name: UniqueFieldAlias, type: BaseFields, field_names: distinct::AllowedNames}
type::{name: FieldAliasHolder, type: struct, fields: closed::{record: {type: UniqueFieldAlias, occurs: required}}}
