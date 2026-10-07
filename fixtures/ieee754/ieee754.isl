$ion_schema_2_0
type::{name: HalfFloat, type: float, ieee754_float: binary16}
type::{name: SingleFloat, type: float, ieee754_float: binary32}
type::{name: DoubleFloat, type: float, ieee754_float: binary64}
type::{name: HalfFloatAlias, type: HalfFloat, ieee754_float: binary16}
type::{name: FloatArray, type: list, element: HalfFloatAlias}
type::{name: FloatRecord, type: struct, fields: closed::{measurement: {type: HalfFloatAlias, occurs: required}}}
