$ion_schema_2_0
type::{name: TreeNode, type: struct, fields: closed::{value: {type: string, occurs: required}, note: $null_or::string, children: {type: TreeNodeList, occurs: required}}}
type::{name: TreeNodeList, type: list, element: TreeNode}
type::{name: LinkNode, type: struct, fields: closed::{label: {type: string, occurs: required}, next: LinkNode}}
type::{name: NullableNode, type: struct, fields: closed::{next: $null_or::NullableNode}}
