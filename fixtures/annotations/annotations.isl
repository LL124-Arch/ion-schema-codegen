$ion_schema_2_0
type::{name: Tagged, type: $any, annotations: closed::required::[record, v1]}
type::{name: TaggedAlias, type: Tagged}
type::{name: OpenTagged, type: $any, annotations: required::[message]}
type::{name: TagList, type: list, element: TaggedAlias}
type::{name: TagRecord, type: struct, fields: closed::{payload: {type: TaggedAlias, occurs: required}}}
type::{name: Stream, type: document, annotations: closed::[]}
