$ion_schema_2_0
type::{name: UniqueInts, type: list, element: distinct::int}
type::{name: UniqueValues, type: list, element: distinct::$any}
type::{name: NullableUniqueValues, type: list, element: distinct::$null_or::int}
type::{name: UniqueExpression, type: sexp, element: distinct::$any}
type::{name: UniqueExpressionRecord, type: struct, fields: closed::{expression: {type: UniqueExpression, occurs: required}}}
type::{name: UniqueRecord, type: struct, element: distinct::$any}
type::{name: UniqueStream, type: document, element: distinct::$any}
