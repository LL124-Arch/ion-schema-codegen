$ion_schema_2_0
schema_header::{user_reserved_fields:{type:[contract_id]}}
type::{name:StageToken, type:symbol, valid_values:[approved,draft], contract_id:"audit-stage"}
type::{name:VersionToken, type:symbol, regex:"^v[0-9]+$"}
type::{name:BasePolicy, type:$list, element:symbol, contains:[record], container_length:range::[2,4]}
type::{name:LocalName, type:symbol, valid_values:[record]}
type::{name:ScopedTokens, type:$list, element:LocalName}
