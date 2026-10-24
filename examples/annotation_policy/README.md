# 审计记录的注解策略

公共约束按文件导入，业务载荷及其注解保留为原始 IonValue。
`Envelope` 要求 record 在首位、approved/draft 恰好一种、版本标签合法且所有标签不重复。
`AuditRecord` 展示在生成的结构体里使用这项策略。

```sh
moon run --target native ./cli examples/annotation_policy/policy.isl examples/annotation_policy/generated.mbt
moon run --target native ./examples/annotation_policy
moon run --target native ./cli validate examples/annotation_policy/policy.isl Envelope examples/annotation_policy/approved.ion
moon run --target native ./cli validate examples/annotation_policy/policy.isl Envelope examples/annotation_policy/overlapping.ion
```

最后一条是无效业务输入：输出 JSON 后退出 1。它同时带 approved/draft，报告 one_of 命中 2 个分支。

可执行示例打印 29 项生成代码的实际判定：

| 场景 | accepted |
| --- | --- |
| approved_record、draft_record、typed_audit_record | true |
| overlapping_stages、duplicate_tags、wrong_order、unsupported_token | false |
| element_intersection、value_intersection | true |
| element_outside_intersection、value_outside_intersection | false |
| exact_sequence / reversed_exact_sequence | true / false |
| required_prefix / bad_required_prefix | true / false |
| nullable_inline / missing_required_symbol | true / false |
| unannotated_symbol_tokens、empty_predicate、list_conjunction | true |
| public_token / private_token | true / false |
| inline_import_element / inline_import_rejects_unknown | true / false |
| import_scope、imported_field_names | true |
| unknown_field_name、literal_is_not_import、document_has_no_annotations | false |

`common.isl` 中的 LocalName 与根文件故意同名，ImportedList 仍使用公共文件的符号规则。
LiteralSafe 的 contains 数据带 `id:"missing.isl"` 和 type 字段，生成时不会访问该文件；
实际注解都是 symbol，因此不能匹配其中的 struct。

[语义及支持边界](../../docs/ANNOTATION_CONSTRAINTS.md)。本示例不代表官方一致性套件。
