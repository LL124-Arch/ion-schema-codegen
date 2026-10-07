$ion_schema_2_0
type::{name: TimestampYear, type: timestamp, timestamp_precision: year}
type::{name: TimestampSecond, type: timestamp, timestamp_precision: second}
type::{name: TimestampMillisecond, type: timestamp, timestamp_precision: millisecond}
type::{name: TimestampMicrosecond, type: timestamp, timestamp_precision: microsecond}
type::{name: TimestampNanosecond, type: timestamp, timestamp_precision: nanosecond}
type::{name: TimestampAliasYear, type: TimestampYear, timestamp_precision: year}
type::{name: TimestampArray, type: list, element: TimestampMillisecond}
type::{name: TimestampRecord, type: struct, fields: closed::{value: {type: TimestampMicrosecond, occurs: required}}}
