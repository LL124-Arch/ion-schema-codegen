# 直接校验原始 Ion 值

从 0.57.0 起提供 `SchemaValidator`，0.60.0 为本批交付版本。
它解释受支持的 Schema 模型，无需生成或动态编译 `.mbt`，并保留输入的 Ion 类型、注解、重复字段和符号身份。
这是全量 ISL 2.0 实现路线中的运行时基础，当前仍受现有 Schema 解析子集限制。

## 库入口

```moonbit
import { "LL124-Arch/ion-schema-codegen" @codegen }

fn validate_quantity() -> Json raise {
  let validator = @codegen.SchemaValidator::new(
    "$ion_schema_2_0 type::{name:Quantity,type:int,valid_values:range::[1,100]}",
  )
  validator.validate_text("Quantity", "3").to_json()
}
```

同一 `SchemaValidator` 可反复使用，每次校验创建独立上下文和输入容器快照。
`type_names()` 返回可调用的命名类型，隐藏内部匿名约束。

| 入口 | 输入/输出 |
| --- | --- |
| `SchemaValidator::new(schema_text)` | 解析一个 Schema，检查引用与已有循环边界，返回可复用对象 |
| `SchemaValidator::from_ion_values(values)` | 接收已解析、已解决 imports 的 Schema；复制容器，调用方后续修改原数组不会更改规则 |
| `validate(type_name, value, limits~)` | 校验一个 IonValue，返回 ValidationReport |
| `validate_text(type_name, text, limits~)` | 解析恰好一个 Ion 值并校验；零个或多个值是调用错误 |
| `validate_document(type_name, values, limits~)` | 校验 document 命名类型的顶层值流 |
| `validate_document_text(type_name, text, limits~)` | 解析并校验零个或多个顶层值 |
| `ValidationReport::is_valid()` / `to_json()` | 严格成功判定及机器可读报告 |

Schema 错误仍抛 `SchemaError`。未知目标类型、无效 limits、输入解析失败及单值/文档入口用错，抛 `ValidationError`。
数据违反契约则返回报告，不把业务数据错误伪装成 Schema 解析错误。
单 Schema 库入口不读取文件或网络 imports；文件输入使用下文 CLI。

## 本批执行的约束

| 范围 | 行为 |
| --- | --- |
| 已支持的 built-in、命名/nullable 引用、别名 | 检查原 Ion kind，区分 plain null 与 typed null；不先转换为 JSON |
| struct 与 fields | 每个字段值及 occurs，开放/封闭规则；保留重复字段的零基出现序号和未知 SID |
| list、sexp、document | 元素、distinct、contains、长度、完整 ordered_elements；文档流与 Ion list 分开处理 |
| valid_values | 有限候选与既有数值/timestamp 范围；沿用生成器的数值比较辅助函数 |
| 标量断言 | decimal precision/exponent、timestamp precision/offset、ieee754_float、regex、码点/UTF-8/LOB 长度 |
| annotations | 简化 closed/required 及解析器已支持的标准引用/inline 规则；标准引用验证真实 symbol list |
| all_of / any_of / one_of / not | 每个分支独立验证；one_of 严格计数；预算耗尽传播为 incomplete |
| 重复约束与有限递归 | 使用上一批同一模型；额外声明继续共同成立，已有有限递归沿嵌套值执行 |

运行时无需投影成 MoonBit 原生字段，因此**命名 int、struct、list 等类型**也可应用已支持的注解规则。
`check_schema` / `generate_code` 仍检查代码生成配置，保留其注解承载限制；
两种入口的适用范围不同。任意 inline 注解组合仍需后续扩展，不能据此宣称完整 annotations 支持。
运行时也不要求类型/字段名能映射为 MoonBit 标识符；示例中的 `'quantity.total'` 可直接校验。

## 诊断与状态

报告包含 `status`、`diagnostics` 和本次解释器 `steps`。

- `valid`：在限制内完成并通过。
- `invalid`：完成检查并发现违反契约的值。
- `incomplete`：深度、输入节点、解释器工作量或诊断上限耗尽；`is_valid()` 必须为 false。

诊断路径采用结构化片段，**不是 JSON Pointer**：

```json
{"type":"Order","path":[{"kind":"field","name":"quantity","sid":null,"occurrence":1}],"constraint":"occurs","expected":"1..1","actual":"2"}
```

`field` 的 name 为字符串或 null，sid 为整数或 null；occurrence 是该符号的零基出现序号。
`index` 定位 list/sexp/document 中的元素，`annotations` 后的 index 定位注解 token。
报告定位本次发现的失败，不承诺穷尽所有可推导错误；类型失败可以停止该分支的后续检查。
CLI 另为诊断补充声明文件和原类型名，便于追踪 imports。

## 资源边界

| limits 字段 | 默认 | 允许最大值 |
| --- | --- | --- |
| max_depth | 64 | 256 |
| max_nodes | 10000 | 1000000 |
| max_steps | 100000 | 10000000 |
| max_diagnostics | 100 | 10000 |

各项必须为正。深度包括容器快照及类型引用/递归检查，不能直接等同于文本容器层数。
steps 包括快照访问、解释器调用、分支及顺序匹配工作；**解析、正则引擎和底层比较函数内部工作不计入该计数**，
它不是墙钟时间或进程内存的硬上限。Schema 快照另限深度 256、节点 100000、快照工作量 1000000。
资源不足在 `not`、`one_of` 等逻辑内部也会终止本次判断，不能作为“分支不匹配”继续得到成功。

## 文件 CLI

```sh
moon run --target native ./cli validate examples/schema_compat/order.isl Order examples/validator_demo/order.ion
moon run --target native ./cli validate-document examples/schema_compat/order.isl StreamAlias examples/validator_demo/stream.ion
```

`validate` 与生成命令共用相对文件 imports、as 别名和逐文件作用域解析。数据文件须为 UTF-8。
有效数据输出 JSON 并返回 0；invalid/incomplete 输出 JSON 后返回非零。
参数、Schema 或输入文本错误写入错误出口并返回非零。命令只读取输入，不覆盖源码或数据文件。

## 共用来源与剩余限制

`validator_support.mbt` 从既有生成 fixture 的辅助函数更新；`scripts/sync_validator_support.py`
是维护入口，运行后使用 `moon fmt`。CI 在重新生成 fixtures 后同步并检查该文件，避免两套数值/长度/相等性逻辑各自漂移。
本批同步修正浮点正负零等价与已解析符号的 SID 比较；NaN 按 Ion 等价处理。

Ion core 的 Float 仍为 32 位，decimal 只保存 coefficient/exponent，缺少独立负零符号。
已在解析阶段丢失的 binary64 精度及 decimal 负零身份无法由本层恢复。
现有 parser 的内置类型、inline/注解/正则与 document 逻辑组合子集仍适用；
ISL 1.0、网络 Schema authorities、官方一致性用例全量接入仍未完成。
不提供全标准通过率或认证声明。

[实际使用示例](../examples/validator_demo/README.md) · [ISL 2.0 规范](https://amazon-ion.github.io/ion-schema/docs/isl-2-0/spec)
