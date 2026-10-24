$ion_schema_2_0
schema_header::{imports:[
  {id:"common.isl",type:StageToken,as:Stage},
  {id:"common.isl",type:BasePolicy,as:Base}
]}
// Audit records start with record, carry one workflow stage, and may carry
// version tags. The entire annotation sequence remains Ion data.
type::{name:Envelope, type:$any, annotations:{
  type:Base,
  element:distinct::{any_of:[
    {valid_values:[record]}, Stage, {id:"common.isl",type:VersionToken}
  ]},
  one_of:[{contains:[approved]},{contains:[draft]}],
  not:{contains:[deprecated]},
  ordered_elements:[{valid_values:[record]},{type:any,occurs:range::[1,3]}]
}}
type::{name:RepeatedElement, type:$any, annotations:{
  element:{valid_values:[record,approved]},
  element:{valid_values:[approved,draft]}
}}
type::{name:RepeatedValues, type:$any, annotations:{
  element:{valid_values:[record,approved],valid_values:[approved,draft]}
}}
type::{name:ExactSequence, type:$any, annotations:{valid_values:[[record,v1],[record,v2]]}}
type::{name:OrderedMinimum, type:$any, annotations:{ordered_elements:[{valid_values:[record],occurs:2}]}}
type::{name:NullableInline, type:$any, annotations:$null_or::{contains:[record]}}
type::{name:NestedAnnotations, type:$any, annotations:{element:{annotations:closed::[]}}}
type::{name:PublicTokens, type:$any, annotations:{element:{not:{regex:"^internal_"}}}}
type::{name:AnyAnnotations, type:$any, annotations:{}}
type::{name:AllOfPolicy, type:$any, annotations:{all_of:[{contains:[record]},{container_length:2}]}}
type::{name:ImportedTokens, type:$any, annotations:{element:{id:"common.isl",type:StageToken}}}
// LocalName conflicts deliberately: ScopedTokens must resolve in common.isl.
type::{name:LocalName, type:int}
type::{name:ImportedList, type:$any, annotations:{id:"common.isl",type:ScopedTokens}}
// This is literal data, including its id and type fields. No file is loaded.
type::{name:LiteralSafe, type:$any, annotations:{contains:[{id:"missing.isl",type:Stage}]}}
type::{name:StageFields, type:$struct, field_names:{id:"common.isl",type:StageToken}}
type::{name:WorkflowMessage, type:struct, fields:closed::{payload:{type:StageFields,occurs:required}}}
type::{name:AuditRecord, type:struct, fields:closed::{payload:{type:Envelope,occurs:required}}}
type::{name:AnnotationFreeStream, type:document, annotations:{}}
