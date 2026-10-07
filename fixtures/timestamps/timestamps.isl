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
type::{name: TimestampUtc, type: timestamp, timestamp_offset: ["+00:00"]}
type::{name: TimestampUnknownOffset, type: timestamp, timestamp_offset: ["-00:00"]}
type::{name: TimestampKnownOffsets, type: timestamp, timestamp_offset: ["+05:30", "-04:00"]}
type::{name: TimestampOffsetAlias, type: TimestampUtc, timestamp_offset: ["+00:00"]}
type::{name: TimestampNoAllowedOffset, type: timestamp, timestamp_offset: []}
type::{name: TimestampOffsetArray, type: list, element: TimestampKnownOffsets}
type::{name: TimestampOffsetRecord, type: struct, fields: closed::{value: {type: TimestampKnownOffsets, occurs: required}}}
