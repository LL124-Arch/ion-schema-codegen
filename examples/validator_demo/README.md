# 无需生成代码的 Ion 校验

本例直接使用公开的 SchemaValidator，输出逐行 JSON 报告：

```sh
moon run --target native ./examples/validator_demo
```

本次实际运行行为：

| 示例 case | status | 内容 |
| --- | --- | --- |
| valid_order | valid | 命名整数范围与闭合订单 |
| invalid_order | invalid | 数量越界、title 类型错误、重复 quantity；路径包含 occurrence=1 |
| overlapping_types | invalid | int 和 number 同时命中，one_of 计数为 2 |
| document | valid | 两个顶层订单值 |
| bounded_work | incomplete | max_steps=5；不会报告成功 |
| annotated_integer / annotated_struct | valid | 原整数和结构体的 approved 注解 |
| missing_annotation | invalid | 缺少 required 注解，定位 annotations |
| standard_annotation_type | valid | 将注解作为 symbol list 校验命名类型 |
| distinct_signed_zeros | valid | 正负浮点零是两个不同 Ion 值 |
| negative_zero_literal | invalid | 负零不命中正零字面值 |
| resolved_symbol | valid | 文本 known 与相同文本、不同 SID 的符号等价 |

`main.mbt` 中 Schema 为程序化示例；`order.ion` 与 `stream.ion` 则复用上一批的跨文件 Schema 运行 CLI：

```sh
moon run --target native ./cli validate examples/schema_compat/order.isl Order examples/validator_demo/order.ion
moon run --target native ./cli validate-document examples/schema_compat/order.isl StreamAlias examples/validator_demo/stream.ion
```

两条命令实际返回 `status=valid`，退出码 0，且不写出生成文件。
API、错误分类、限制与未实现标准能力见 [运行时说明](../../docs/RUNTIME_VALIDATION.md)。
