# 变更记录

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
