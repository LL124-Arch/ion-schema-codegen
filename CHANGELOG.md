# 变更记录

## 0.40.0 — 2026-10-10

- 类型代数 inline type definition 支持 `type: list` 与元素类型、长度和包含约束；matcher 通过 package-private 转换代码验证列表内容。
- Inline list 的生成模型和转换函数不会成为调用方可见的公开 API。

## 0.39.0 — 2026-10-09

- Native CLI 会递归加载类型代数中的 inline imports，并将 `{id, type}` 参数改写为导入 Schema 中的实际类型；支持 `$null_or` 包裹和 all/any/one/not 四种组合。
- inline import 不进入 Schema 的通用可见名称范围；相对文件及选定类型不存在时返回文件上下文错误。纯库 API 对 inline import 显式报错。

## 0.38.0 — 2026-10-09

- Inline scalar type definitions 可组合当前已实现的值约束；逻辑分支 matcher 会执行 `regex` 等约束，而不是只匹配底层 Ion 类型。
- 显式拒绝容器 inline definitions 与仍不支持的逻辑约束组合。

## 0.37.0 — 2026-10-09

- 类型代数接受 `$null_or::{type: ..., valid_values: [...]}` inline 参数；plain null 或匹配值通过，错误 typed null 和集合外值继续失败。
- nullable inline matcher 适用于 `all_of`、`any_of`、`one_of` 和 `not`，保留既有分支计数语义。

## 0.36.0 — 2026-10-09

- `all_of`、`any_of`、`one_of` 和 `not` 类型参数接受标量 `type` 与 `valid_values` 组成的 inline type definition；匿名 matcher 为内部实现，不生成公开类型声明。
- Inline type definition 中未实现的容器及其他约束组合仍在 Schema 检查阶段明确拒绝。

## 0.35.0 — 2026-10-09

- `annotations` 标准 inline `element` 支持 `regex`、`codepoint_length` 和 `utf8_byte_length`，按每个 symbol token 的文本校验。
- 支持 `ordered_elements` 对注解 token 有序分组校验，包括必选、可选、精确及范围次数；未消费 token 和无文本 symbol 返回 `annotations` 错误。

## 0.34.0 — 2026-10-09

- `annotations` 标准 inline 表达式支持 `element: {valid_values: [...]}`，逐个限制注解 symbol token。
- 有限集合按文本 symbol 解释并去重；空注解序列通过逐项约束，非法 token 报 `annotations` 错误并保留路径。

## 0.33.0 — 2026-10-09

- `annotations` 标准 inline type argument 支持 `contains` 符号集合；按无序包含语义检查，重复期望符号不增加要求。
- `contains` 仅接受有文本的未注解 symbol，错误沿用 `annotations` 分类及原值路径。

## 0.32.0 — 2026-10-09

- `annotations` 标准 inline type argument 支持 `container_length` 精确值与范围，按值的注解数量校验。
- 非法注解数量沿用 `annotations` 错误分类，并保留当前值路径。

## 0.31.0 — 2026-10-09

- `annotations` 标准语法接受 built-in、命名类型及 `$null_or` 类型引用，将值注解按有序 symbol list 校验。
- 命名注解类型的长度、元素及其他已实现约束复用现有类型 matcher；标准 inline 约束对象仍显式报错。

## 0.30.0 — 2026-10-09

- 支持 not 单类型参数约束；仅当目标类型不匹配时通过，nullable 参数按 null 与目标类型的并集判断。
- not 可引用 built-in、同 Schema 命名类型及直接导入类型；嵌套字段和列表元素返回 not 约束名与具体路径。

## 0.29.0 — 2026-10-09

- 支持非空 one_of 类型参数列表，按分支独立计数并要求恰好一个匹配。
- 重叠类型与重复分支均计为多次匹配；one_of 沿命名类型别名传播到字段和列表元素并报告路径。

## 0.28.0 — 2026-10-09

- 支持非空 any_of 类型参数列表，任一分支匹配即通过；各分支独立检查，支持重叠分支及 nullable 分支。
- any_of 可沿命名类型别名传播到字段和列表元素，并保留失败约束名与路径。

## 0.27.0 — 2026-10-09

- 命名类型可省略 type，此时按 $any 生成原始 IonValue 表示。
- 支持非空 all_of 类型参数列表；各分支均匹配时通过，别名、字段和列表元素校验保留失败路径。
- 类型代数的类型参数支持已解析的 built-in、同 Schema 命名类型及 $null_or；inline 定义/导入和 document 类型参数显式报错。需要容器结构的约束仍要求显式 type: struct/list。

## 0.26.0 — 2026-10-09

- 支持 `annotations: closed::[...]`、`required::[...]` 及二者组合，按符号集合检查 Ion 值注解。
- 支持范围限定为原始 `IonValue` 表示并能保留注解的类型；标准语法和原生标量投影类型显式报错，`document` 始终不匹配。

## 0.25.0 — 2026-10-07

- 支持 `string` 和 `symbol` 的 `regex` 子集及 `i` / `m` 标志，约束沿别名传播到字段和列表元素，并返回路径化错误。
- Schema 检查会拒绝无效模式、未知/重复标志和子集外语法；明确记录特殊分组、部分转义及字符类内部 `\D` / `\S` / `\W` 的限制。

## 0.24.0 — 2026-10-07

- 支持 `ieee754_float: binary16 | binary32 | binary64`，按命名约束、别名、字段和列表元素校验。
- 对 binary16 实现精确 Float 位级兼容检查，覆盖正规数、次正规数、最大有限值、正负零、NaN 和正负无穷。
- 当前 Ion core 将 `IonValue::Float` 存为 MoonBit 32 位 `Float`；binary32/64 因而不会继续缩窄，解析时被依赖舍弃的 binary64 精度无法由生成代码恢复或检测。

## 0.23.0 — 2026-10-07

- 支持 `timestamp_offset` 的 `±hh:mm` 集合约束，`+00:00` 与 `Z` 等价，`-00:00` 按未知偏移匹配。
- 对格式错误及超出小时/分钟范围的偏移在 Schema 检查时返回错误；值错误显示实际偏移并保留字段/列表路径。
- 覆盖别名及结构体字段、列表元素中的偏移检查。

## 0.22.0 — 2026-10-07

- 扩展 `timestamp_precision` 支持 `range::[...]`、`min` / `max` 及 `exclusive::` 边界。
- 使用细分精度等级比较小数秒；例如 `range::[exclusive::second, exclusive::millisecond]` 精确匹配十分位和百分位时间戳。
- 覆盖别名、结构体字段和列表元素中的范围约束及路径化错误。

## 0.21.0 — 2026-10-07

- 支持 `timestamp_precision` 的八种精确值；按时间组件与小数秒位数校验，保留十分位到纳秒之间的实际精度。
- 约束可沿命名别名传播到字段与列表元素转换，并通过 `validate_timestamp_precision_Type` 检查直接值。

## 0.20.0 — 2026-10-07

- 支持 decimal 的 `exponent` 精确值及含负数边界的整数范围，包括 `min` / `max` 和 `exclusive::`。
- 通过 Ion Decimal 数据模型 accessor 读取 exponent；typed null 不具备 exponent，因此校验失败。
- 约束沿同 Schema 别名传播到结构体字段和列表元素，fixture 覆盖直接校验与嵌套错误路径。

## 0.19.0 — 2026-10-07

- 支持 decimal 的 `precision` 精确值与整数范围；按 Decimal coefficient 的位数计数，不含符号，零为一位。
- 要求 precision 下界至少为 1，并拒绝 typed null；约束会通过同 Schema 别名传播到字段和列表元素转换。
- 增加独立 precision fixture，覆盖精确值、范围、别名及嵌套转换错误路径。

## 0.18.0 — 2026-10-07

- 支持 list、sexp、struct 和 document 的 `contains`，期望值按任意顺序匹配，重复声明不增加要求。
- 成员匹配遵循 Ion 值等价规则并比较注解；struct 以字段值作为成员，内嵌 struct 的字段次序不影响匹配。
- 缺少成员时返回容器路径、`contains` 约束和可读的缺失 Ion 值；约束沿同 Schema 容器别名传播。
- 增加独立 contains fixture，覆盖四类容器、重复要求、等价匹配和嵌套别名转换。

## 0.17.0 — 2026-10-07

- 支持 struct 的 `field_names` type argument，可用 symbol 或同 Schema 命名类型校验所有字段名，包括开放字段。
- 支持 `field_names: distinct::T` 检查字段名唯一性；类型校验错误包含字段名和出现位置，并沿 struct 别名传播。
- 扩展独立 constraints fixture，验证允许集合、重复字段、开放内容和嵌套别名路径。

## 0.16.0 — 2026-10-07

- 支持 list、sexp、struct 和 document 的 `element: distinct::T`，重复值按 Ion 数据模型等价规则比较并包含注解。
- 对深层容器值递归比较；struct 字段顺序不影响等价性，重复值错误包含容器路径和下标。
- 增加独立 constraints fixture，实际覆盖 list、sexp、struct、document、注解及嵌套 struct 顺序。

## 0.15.0 — 2026-10-07

- native 文件 CLI 递归解析相对 Schema imports，支持整份 Schema、选定类型和 `as` 别名，并按各文件的直接导入维护类型作用域；从解析后的 Ion 值直接生成，避免精度敏感值的文本往返。
- 对导入循环、无法读取的文件、未声明的导入类型及可见名称冲突提供文件路径诊断；纯库 API 对 imports 明确返回 unsupported feature。
- 提供 `generate_code_from_ion_values` 入口，供已解析的单 Schema Ion 值直接调用。

## 0.14.0 — 2026-10-07

- 支持 list、sexp 和 document 的 `ordered_elements`，包含 required、optional、固定次数及范围 `occurs`，并校验整个序列被完整消费。
- 异质序列以原始 `IonValue` 数组往返，保留类型、注解和 decimal 精度；不合法项的错误路径包含序列下标。

## 0.13.0 — 2026-10-07

- 支持 struct、sexp 和 document 的 `element` 约束，逐项验证字段值或顶层值，并保留 struct 的重复与开放字段。
- struct 可仅声明 `element`；document 别名会组合应用元素约束和 `container_length` 范围。

## 0.12.0 — 2026-10-07

- 支持 string / symbol 的 `codepoint_length` 与 `utf8_byte_length`，以及 blob / clob 的 `byte_length` 精确值和整数区间。
- Unicode 长度按码点或 UTF-8 编码字节计算，LOB 长度按载荷原始字节计算；转换错误包含字段路径、约束名和实际长度。

## 0.11.0 — 2026-10-07

- 支持 list、sexp、struct 和 document 的 container_length 精确值及整数区间。
- 转换按结构体字段总出现次数和 document 顶层值数计算长度，并返回带路径的约束错误。

## 0.10.0 — 2026-10-07

- 支持 `valid_values: range::[...]` 及集合中混合普通值与数值/timestamp 范围。
- 校验 `min` / `max`、闭区间与 `exclusive::` 边界；数值比较保留整数和 decimal 精度，timestamp 按绝对时间比较，并拒绝类型不匹配或非有限端点。

## 0.9.0 — 2026-10-07

- 支持标量命名类型的有限 `valid_values` 集合，并在结构体字段和列表元素的 Ion 转换中校验集合成员。
- 集合匹配遵循 Ion 值等价规则并忽略注解；生成 `is_valid_values_Type` / `validate_Type` 检查函数及带路径的转换错误。

## 0.8.0 — 2026-10-07

- 支持默认开放 fields；生成结构体保存未知字段、重复项和未解析符号，并在往返时稳定保留。

## 0.7.0 — 2026-10-07

- 支持结构体字段整数及范围 occurs；可重复字段生成数组，转换时保留重复值并验证字段出现次数。

## 0.6.0 — 2026-10-07

- 支持 nullable Ion built-in 类型和 `$null_or::T` 类型参数，在别名、结构体字段和列表元素中保留 plain/typed null。
- 为 nullable 类型添加基于实际 Ion kind 的转换检查，保留原始 IonValue 与注解。

## 0.5.0 — 2026-10-06

- 支持 ISL `document` 顶层流类型，映射为有序的 `Array[@ion_model.IonValue]`。
- 为 document 命名类型及同 Schema 别名生成独立流转换函数；明确拒绝 document 嵌套进字段或列表。
- 增加多个顶层值及 Ion core 文本解析/编码往返用例。

## 0.4.0 — 2026-10-06

- 支持 nullable universal type `$any`，作为字段、列表元素及命名别名时映射为原始 `IonValue`。
- 保留 plain null、typed null、带注解 null 和其他注解值；非 nullable `any` 仍拒绝 null。
- 其他 nullable 类型及顶层 document 流仍不在当前值转换子集中。

## 0.3.0 — 2026-10-05

- 支持 Ion Schema `any`，映射为原始 `IonValue`，可用于结构体字段、列表元素及命名别名。
- 任意非 null 值及其注解、嵌套容器均经 `from_ion` / `to_ion` 原样保留；plain null 和 typed null 返回带路径错误。
- 显式保持 `$any`（nullable any）不支持，并为解析、生成及运行时往返补充回归用例。

## 0.2.0 — 2026-10-05

- 支持 Ion Schema `sexp` 类型，并可在结构体字段和列表元素中转换。
- 将表达式映射为 `Array[@ion_model.IonValue]`，保留任意嵌套 Ion 子值、注解与顺序。
- 为 S-expression 容器错误补充类型诊断及端到端往返 fixture。

## 0.1.0 — 2026-10-05

- 实现 ISL 2.0 受支持子集解析、MoonBit 类型生成及 Ion 双向转换。
- 支持标量、封闭结构体、列表、同 Schema 命名引用和稳定依赖顺序；循环引用会报告引用链。
- 增加 native CLI，能够读取 `.isl` 文件并写出生成的 `.mbt` 文件。
- 增加 Person 端到端示例、标量/结构体/列表转换 fixture 和四目标 CI 验收。
- 明确拒绝跨 Schema 导入、递归类型、开放结构体、nullable 类型及未实现约束。
