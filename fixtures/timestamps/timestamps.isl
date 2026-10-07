$ion_schema_2_0
type::{name: TimestampYear, type: timestamp, timestamp_precision: year}
type::{name: TimestampSecond, type: timestamp, timestamp_precision: second}
type::{name: TimestampMillisecond, type: timestamp, timestamp_precision: millisecond}
type::{name: TimestampMicrosecond, type: timestamp, timestamp_precision: microsecond}
type::{name: TimestampNanosecond, type: timestamp, timestamp_precision: nanosecond}
type::{name: TimestampAliasYear, type: TimestampYear, timestamp_precision: year}
type::{name: TimestampFractionSubMillisecond, type: timestamp, timestamp_precision: range::[exclusive::second, exclusive::millisecond]}
type::{name: TimestampMillisecondOrFiner, type: timestamp, timestamp_precision: range::[millisecond, max]}
type::{name: TimestampPrefixThroughDay, type: timestamp, timestamp_precision: range::[min, day]}
type::{name: TimestampFractionAlias, type: TimestampFractionSubMillisecond, timestamp_precision: range::[exclusive::second, exclusive::millisecond]}
type::{name: TimestampArray, type: list, element: TimestampMillisecond}
type::{name: TimestampRecord, type: struct, fields: closed::{value: {type: TimestampMicrosecond, occurs: required}}}
type::{name: TimestampRangeArray, type: list, element: TimestampFractionAlias}
type::{name: TimestampRangeRecord, type: struct, fields: closed::{value: {type: TimestampFractionAlias, occurs: required}}}
