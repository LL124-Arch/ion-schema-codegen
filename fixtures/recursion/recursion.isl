$ion_schema_2_0
type::{name: TreeNode, type: struct, fields: closed::{value: {type: string, occurs: required}, note: $null_or::string, children: {type: TreeNodeListAlias, occurs: required}}}
type::{name: TreeNodeList, type: list, element: TreeNode}
type::{name: TreeNodeListAlias, type: TreeNodeList}
type::{name: LinkNode, type: struct, fields: closed::{label: {type: string, occurs: required}, next: LinkNode}}
type::{name: NullableNode, type: struct, fields: closed::{next: $null_or::NullableNode}}
type::{name: Branch, type: struct, fields: closed::{name: {type: string, occurs: required}, leaves: {type: BranchLeaves, occurs: required}}}
type::{name: BranchLeaves, type: list, element: BranchLeaf}
type::{name: BranchLeaf, type: struct, fields: closed::{name: {type: string, occurs: required}, parent: Branch}}
type::{name: RecursiveStructElement, type: struct, element: RecursiveStructElement}
type::{name: RecursiveSequence, type: list, ordered_elements: [{type: RecursiveSequence, occurs: optional}]}
