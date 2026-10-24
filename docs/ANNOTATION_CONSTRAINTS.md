# 标准注解约束（0.61.0）

规范依据：[ISL 2.0 annotations](https://amazon-ion.github.io/ion-schema/docs/isl-2-0/spec#annotations)。
注解按有序的非 null symbol list 检查，各 token 自身没有注解。业务值可以是 null；
document 没有注解列表，因此始终不满足 annotations。

## 可组合能力

| 写法 | 行为 |
| --- | --- |
| `annotations: T` | built-in 或命名类型检查整个注解列表 |
| `annotations: {}` | 对单个 Ion 值没有附加限制；document 仍拒绝 |
| inline `type` | 与其他条件共同成立，声明的类型不会被覆盖 |
| `all_of` / `any_of` / `one_of` / `not` | 在同一列表或 token 上执行通用逻辑；one_of 分支分别计数 |
| `element: symbol` 或命名类型 | 逐 token 检查，允许 inline 逻辑及已支持的文本约束 |
| `element: distinct::T` | 先执行元素规则，并拒绝重复注解 |
| 多个 element / valid_values | 每项独立执行，取交集 |
| `container_length` / `contains` | 长度和包含条件，可与其他约束组合 |
| `valid_values: [[record,v1], [record,v2]]` | 完整注解序列须等于某个候选列表；保留次序 |
| `ordered_elements` | occurrence 与每个 token 的条件共同成立，完整消费序列 |
| `$null_or::{...}` | 接受通用 nullable 类型参数语法；实际注解列表始终非 null |
| token 上的 `annotations` | 检查没有自身注解的 symbol 值，例如 closed::[] 可通过 |
| `closed::` / `required::` 简化列表 | 按集合处理；列表中重复符号不增加次数要求 |

匿名条件会转换为同一通用类型模型。由于实际输入域已知，内部用原始 IonValue 承载列表和符号；
显式 type 条件保留为独立交集分支。不会把注解数组投影成业务字段，也不会覆盖前一项声明。
旧的独立标准注解解析/求值分支已移除，运行时和生成器共享解析结果。

## 导入和字面数据

native CLI 在 annotations、element、field_names、fields、ordered_elements 和嵌套逻辑参数中
递归解析 `{id:"common.isl",type:TypeName}`，并重写各文件可见的类型名及 as 别名。
导入类型内部继续使用其声明文件的作用域。

contains/valid_values 的内容是 Ion 字面值。即使其中有 id/type/annotations 字段，
也不会加载文件或重写符号。网络 authorities、循环文件导入仍未实现；库 API 不负责文件解析。

## 真实业务例子

[审计记录策略](../examples/annotation_policy/policy.isl) 要求：record 位于首位；
approved/draft 恰好出现一种；可附加版本标签；标签不得重复。
公共策略和 token 类型来自 [common.isl](../examples/annotation_policy/common.isl)。

```sh
moon run --target native ./cli examples/annotation_policy/policy.isl examples/annotation_policy/generated.mbt
moon run --target native ./examples/annotation_policy
moon run --target native ./cli validate examples/annotation_policy/policy.isl Envelope examples/annotation_policy/approved.ion
moon run --target native ./cli validate examples/annotation_policy/policy.isl Envelope examples/annotation_policy/overlapping.ion
```

合法输入返回 valid 和退出码 0。最后一条命令返回 invalid 和退出码 1，
错误为 one_of、actual=2，路径是 annotations，并给出策略文件和 Envelope 声明名。

生成器的示例输出还展示交集、标签次序、occurs 下限、命名导入作用域、字段名导入和嵌套业务类型。
顺序匹配现在从长度 0 检查每个前缀，达到最小 occurrence 后才接受；
`other::record::1` 不满足“record 恰好出现两次”的模式。

## 支持边界

- 运行时可在命名 int/struct/list 等原生类型上校验注解；生成器继续要求承载值能保留注解，
  例如 any/$any/nullable 类型。原生标量或容器的代码生成投影限制没有放宽。
- 匿名列表/token 条件复用现有类型和约束子集；不会因此接受所有合法 ISL 类型定义。
  不相容或尚未实现的约束组合仍可能在 Schema 准备阶段显式拒绝。
- 标准语法的 contains 可以包含任意受支持的 Ion 字面值。非 symbol 候选不会匹配注解 token，
  这是数据不满足约束，不再一律作为“非法 annotations Schema”拒绝。
- regex 的剩余语义、完整内置类型/inline 支持、binary64/decimal 负零、ISL 1.0 互操作及
  官方一致性套件的全面接入仍未完成。本版本不宣称完整 ISL 2.0 兼容。

资源预算、错误路径及运行时入口见 [RUNTIME_VALIDATION.md](RUNTIME_VALIDATION.md)。
