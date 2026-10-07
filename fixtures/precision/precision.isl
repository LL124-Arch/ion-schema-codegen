$ion_schema_2_0
type::{name: PrecisionFour, type: decimal, precision: 4}
type::{name: PrecisionRange, type: decimal, precision: range::[2, 4]}
type::{name: BasePrecision, type: decimal, precision: range::[2, max]}
type::{name: AliasPrecision, type: BasePrecision, precision: 4}
type::{name: NullablePrecision, type: $decimal, precision: range::[min, 4]}
type::{name: PrecisionValues, type: list, element: PrecisionRange}
type::{name: PrecisionRecord, type: struct, fields: closed::{exact: {type: AliasPrecision, occurs: required}, values: {type: PrecisionValues, occurs: required}}}
type::{name: ExponentExact, type: decimal, exponent: -2}
type::{name: NullableExponent, type: $decimal, exponent: -2}
type::{name: ExponentRange, type: decimal, exponent: range::[min, -2]}
type::{name: BaseExponent, type: decimal, exponent: range::[exclusive::-4, exclusive::0]}
type::{name: AliasExponent, type: BaseExponent, exponent: -2}
type::{name: ExponentValues, type: list, element: ExponentRange}
type::{name: ExponentRecord, type: struct, fields: closed::{exact: {type: AliasExponent, occurs: required}, values: {type: ExponentValues, occurs: required}}}
