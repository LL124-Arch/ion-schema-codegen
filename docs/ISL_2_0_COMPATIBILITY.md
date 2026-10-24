# ISL 2.0 兼容范围：开放内容与重复约束

版本：0.56.0，2026-10-24。规范依据：[Ion Schema 2.0](https://amazon-ion.github.io/ion-schema/docs/isl-2-0/spec)。
本次补齐文档处理和重复约束，仍不表示全量 ISL 2.0 兼容。

## 开放内容

| 内容 | 处理 |
| --- | --- |
| 版本前、声明之间、footer 后的普通 Ion 值 | 忽略，不生成业务类型 |
| schema_header/type/schema_footer 中非保留字段名 | 作为元数据忽略，例如 `_doc`、`displayName` |
| 小写 snake_case 或 `$ion_schema` 系列的保留字段名 | 须在 header 的 user_reserved_fields 对应位置声明 |
| ISL 关键字 | 保留语义；禁止声明为用户字段，禁止在错误位置当作元数据忽略 |
| user_reserved_fields | 无注解 struct，仅允许 schema_header/type/schema_footer 三类无注解 symbol list；禁止重复作用域与关键字项 |
| 嵌套类型参数 | 按所属文档的 type 元数据声明处理 |
| contains/valid_values 中的 struct/list 字面值 | 保留原 Ion 值，不清除其中字段或注解 |
| Schema 间 imports | 每个文件独立整理；一个文件的元数据声明不授权另一个文件的字段 |

保留字段名的判定遵循规范规定的 ASCII snake_case 和 `$ion_schema` 前缀规则。
Schema 内开放内容的注解不得使用保留符号；无文本字段名/注解仍明确拒绝。
版本标记、header、type、footer 的顺序和形状仍须合法；重复 header/footer、重复版本、
footer 后再次声明类型会报错。ISL 1.0 仍未实现。

公共入口 `prepare_schema_document(values)` 返回剔除开放内容后的 Ion Schema 值，保留未解析 imports。
它负责文档与声明检查，**不代表 Schema 类型引用或所有约束已合法**；完整检查仍调用
`check_schema` / `generate_code`。文件 CLI 在逐文件解析 imports 前调用同一入口。

## 重复约束

每项声明均约束同一个原始 Ion 值。第一项选择现有 MoonBit 类型表示，
后续项生成私有校验分支；单项原有的支持限制仍适用。

| 声明 | 语义 |
| --- | --- |
| 多个 type | 每个类型均须匹配；不当作类型联合 |
| 多个 valid_values | 每组允许集合或范围均须命中，取交集 |
| 多个 fields | 每组独立执行字段类型、occurs 和 closed；不跨组拼接字段或丢弃 closed |
| 多个 element | 每组元素类型及 distinct 均须成立，覆盖 list/sexp/struct/document 的原有支持域 |
| 多个 field_names | 每组字段名类型及 distinct 均执行 |
| 多个 ordered_elements | 每个顺序模式分别消费完整序列；list/sexp/document 按已有规则匹配 |
| 已有长度、precision/exponent、regex、annotations、逻辑等多项约束 | 继续按原来的逐项检查执行 |
| 重复 name、occurs、同一 fields 中重复字段名 | 这些是名称或出现次数声明错误，继续拒绝 |

文档流的重复约束在原流上执行；别名继承完整校验链。相同的 `type:document`
可重复声明；与单值类型混合的 document 类型交集、通用 document 逻辑类型仍显式拒绝。
普通值的额外分支失败沿用 `all_of` 的转换错误与父路径；文档流保留原有元素/顺序错误路径。

## 实例与剩余工作

[订单示例](../examples/schema_compat/README.md) 实际导入公共约束、生成源码、编译并转换订单、列表及文档流。
复现工具链基线为 compiler/core `0.10.14+7d59c7ec9`，moon `0.1.20260920`；CI 固定相同版本。

0.60.0 已加入 [直接校验原始 Ion 的运行时层](RUNTIME_VALIDATION.md)，本页保留开放内容和重复约束的配置说明。
后续仍需完整标准注解组合、正则剩余语义、上游 binary64/decimal 负零表示与 ISL 1.0 互操作，
以及官方一致性用例的系统接入。当前不存在官方测试集通过率或全标准兼容认证。
