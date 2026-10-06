# ion-schema-codegen

`ion-schema-codegen` 根据受支持的 Ion Schema 2.0 文档生成 MoonBit 类型和双向 Ion 转换函数。它依赖 [amazon-ion-moonbit-core](https://github.com/LL124-Arch/amazon-ion-moonbit-core) 解析 Ion 文本并表示 Ion 值。

## 支持范围

- `container_length` 支持 list、sexp、struct 和 document 的精确长度与整数范围；struct 按字段总出现次数计数，document 按顶层值数计数。
- `codepoint_length` 与 `utf8_byte_length` 支持 string 和 symbol；`byte_length` 支持 blob 和 clob，均可使用精确值或整数范围。
- 标量：`bool`、`int`、`float`、`decimal`、`string`、`symbol`、`timestamp`、`blob` 和 `clob`。
- 数值联合类型 `number` / `$number` 可作为 `IonValue` 使用，并检查其 int、float 或 decimal 成员类型。
- 开放与封闭结构体字段；可用 closed 注解限制额外字段。字段支持必选、可选及整数/区间 `occurs`；可重复字段映射为数组，未知字段和值模型按原顺序保留。
- `element` 支持 list、sexp、document 和 struct 中每个值的类型约束；struct 可与 `fields` 组合，也可仅用 `element` 校验并保留开放字段。
- 列表元素支持受支持标量或同一 Schema 命名类型；sexp、document 和 struct 元素按输入顺序逐项校验并在错误路径中标明位置。
- Ion `sexp` 作为 `Array[@ion_model.IonValue]`，支持结构体字段及列表元素；表达式内部值与顺序保持为 Ion 值模型。
- Ion Schema `any` 作为 `@ion_model.IonValue`，可用于字段、列表元素和命名别名；任意非 null `IonValue`（含注解及嵌套值）原样往返。
- Ion Schema `$any` 也作为 `@ion_model.IonValue`，可在字段、列表元素和命名别名中保留 plain null、typed null 及注解。
- nullable built-in（如 `$int`、`$string`、`$null`）以及 type argument 的 `$null_or::T` 映射为原始 `@ion_model.IonValue`，保留 null kind、注解和值；转换时仍按对应 Schema 类型检查。
- Ion Schema `document` 作为有序的 `Array[@ion_model.IonValue]` 顶层流；生成 `from_ion_document_Type` / `to_ion_document_Type` 函数，并支持同 Schema 别名。
- 标量命名类型支持有限 `valid_values` 集合；集合成员比较遵循 Ion 值等价规则并忽略注解，字段与列表元素转换会报告约束失败路径。
- `valid_values` 支持数值和 timestamp 的 `range::[...]`，包括 `min` / `max`、闭区间和 `exclusive::` 边界；上下界需匹配范围类型，数值范围按数学值比较。
- 无循环的同 Schema 命名类型引用；生成声明按依赖顺序排列。
- 结构体与列表的 `from_ion` / `to_ion` 转换。转换会报告字段路径、列表下标和具体 Ion 类型。

项目不实现完整的 Ion Schema 校验器。跨 Schema 导入、递归类型、正则、注解和类型代数等约束会显式报错。`element` 上的 `distinct::` 和内联 type/import 定义仍不支持。`valid_values` 范围目前限于 `int` / `float` / `decimal` / `number` 及对应 nullable 数值类型，以及 `timestamp` / `$timestamp`。`$null_or` type argument 不能同时声明显式 `occurs`，遵循 ISL 2.0 规定。`any`/`$any` 接受注解值；该行为保留注解，不代表实现了 ISL 的注解约束。`document` 只能作为顶层命名类型或别名使用，不能嵌入结构体字段或列表元素；`$any` 表示单个 `IonValue`，document 流由独立类型表示。

## 安装与检查

安装 MoonBit 工具链后，在仓库根目录运行：

```sh
moon update
moon fmt --check
moon check --deny-warn --target all
moon build
moon test --deny-warn --target all
```

## 从 Schema 生成代码

CLI 读取 UTF-8 `.isl` 文件并写出 `.mbt` 文件。CLI 使用本机文件系统，运行目标为 `native`：

```sh
moon run --target native ./cli examples/person/person.isl examples/person/generated.mbt
```

命令会打印生成结果所需的包导入。把这些导入加入目标包的 `moon.pkg`，然后编译或运行该包。已有输出文件会被覆盖；读取、Schema 生成和写入失败会返回非零状态并显示原因。

## 端到端示例

仓库内的 [Person Schema](examples/person/person.isl) 声明必选 `id`、`name` 和可选 `nickname`。从仓库根目录依次运行：

```sh
moon run --target native ./cli examples/person/person.isl examples/person/generated.mbt
moon run --target native ./examples/person
```

示例程序解析 Ion 文本，将值转换为 `Person`，更新姓名，再把类型化值编码回 Ion 文本。输出类似：

```ion
{id: 42, name: "Ada Lovelace", nickname: "Ada"}
```

可查看 [示例入口](examples/person/main.mbt) 和 [CLI 生成的 MoonBit 代码](examples/person/generated.mbt)。

## 库 API

```moonbit
let generated = @ion-schema-codegen.generate_code(schema_text)
// generated.source 是 MoonBit 源码
// generated.package_imports 是目标包需要加入 moon.pkg 的导入项
```

`check_schema(schema_text)` 只检查当前受支持的 Schema 子集；`generate_code(schema_text)` 返回源码和所需导入。程序化调用示例见 `fixtures/generated` 与 `fixtures/references`。

结构体转换校验每个字段的 `occurs` 上下界；必选字段映射为 `T`，可选字段映射为 `T?`，多次出现字段映射为 `Array[T]`。重复字段按输入顺序存储。已声明字段按 Schema 顺序输出，开放结构体的未知字段和值在其后按输入顺序输出，重复项和未解析 SID 均会保留。转换还会报告未知字段、错误 Ion 类型和不符合字段类型的 null。普通具名类型的字段仍拒绝注解；`any` 字段保留所有非 null 值与注解，`$any` 接受任意 Ion 值。nullable built-in 保留其对应 typed null，`$null_or::T` 接受 plain null 或符合 T 的值；这些字段和列表元素都以 `IonValue` 表示。列表转换要求 Ion `list`，逐项验证元素类型，并在错误路径中包含元素下标；`any` 元素拒绝 null，`$any` 元素接受 null。

`sexp` 转换检查外层容器必须是 Ion `sexp`，并保留内部的任意 Ion 值；内部子值不会按其他 Schema 类型递归校验。

`document` 类型转换的是零个或多个顶层 Ion 值组成的有序流。生成函数只在 `Array[@ion_model.IonValue]` 与对应命名类型之间传递数据；文本或二进制解析/编码继续使用 Ion core 的 `parse_text` / `encode_text` 等接口。

## 变更记录

版本变更见 [CHANGELOG.md](CHANGELOG.md)。
