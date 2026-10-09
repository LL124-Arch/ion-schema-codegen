# ion-schema-codegen

`ion-schema-codegen` 根据受支持的 Ion Schema 2.0 文档生成 MoonBit 类型和双向 Ion 转换函数。它依赖 [amazon-ion-moonbit-core](https://github.com/LL124-Arch/amazon-ion-moonbit-core) 解析 Ion 文本并表示 Ion 值。

## 支持范围

- all_of 支持非空 built-in、同 Schema 命名类型、CLI 已解析的直接导入类型及 $null_or 类型参数列表，所有分支均须匹配；命名类型省略 type 时按 $any 表示并保留原始 IonValue。inline type definition、约束参数内的 inline import 和 document 类型参数不支持；需要容器结构的约束仍须显式声明 type: struct 或 type: list。
- any_of 支持非空 built-in、同 Schema 命名类型、CLI 已解析的直接导入类型及 $null_or 类型参数列表，至少一个分支须匹配；支持重叠分支并逐支独立验证。
- one_of 支持非空 built-in、同 Schema 命名类型、CLI 已解析的直接导入类型及 $null_or 类型参数列表，恰好一个分支须匹配；重叠类型和重复分支会分别计数。
- not 支持单个 built-in、同 Schema 命名类型、CLI 已解析的直接导入类型及 $null_or 类型参数；分支匹配时拒绝当前值，分支转换或校验失败时通过。
- `container_length` 支持 list、sexp、struct 和 document 的精确长度与整数范围；struct 按字段总出现次数计数，document 按顶层值数计数。
- `codepoint_length` 与 `utf8_byte_length` 支持 string 和 symbol；`byte_length` 支持 blob 和 clob，均可使用精确值或整数范围。
- 标量：`bool`、`int`、`float`、`decimal`、`string`、`symbol`、`timestamp`、`blob` 和 `clob`。
- 数值联合类型 `number` / `$number` 可作为 `IonValue` 使用，并检查其 int、float 或 decimal 成员类型。
- 开放与封闭结构体字段；可用 closed 注解限制额外字段。字段支持必选、可选及整数/区间 `occurs`；可重复字段映射为数组，未知字段和值模型按原顺序保留。
- `field_names` 支持对 struct 的全部字段名应用 symbol 或同 Schema 命名类型约束；`distinct::T` 同时拒绝重复字段名，开放字段也会参与检查。
- `contains` 支持 list、sexp、struct 和 document 按任意顺序包含给定 Ion 值；匹配比较注解，重复的期望值不增加要求，缺失值错误包含容器路径与 Ion 表示。
- Decimal `precision` 支持未缩放 coefficient 的精确位数与整数范围；按 Decimal 数据模型计数，不含符号和 exponent，零按一位处理。`exponent` 支持含负数的精确值及范围，直接读取 Decimal 数据模型。两项约束都会沿别名传播到字段和列表元素转换，并拒绝 typed null。
- `timestamp_precision` 支持 `year`、`month`、`day`、`minute`、`second`、`millisecond`、`microsecond` 和 `nanosecond` 精确值及范围，包含 `min` / `max`、`exclusive::` 与秒以下的小数精度；按时间戳数据模型中的小数位数校验。
- `timestamp_offset` 支持 `±hh:mm` 集合，`+00:00` 与 `Z` 等价，`-00:00` 表示未知偏移；非法格式和越界小时/分钟会在 Schema 解析阶段报错。
- `ieee754_float` 接受 `binary16`、`binary32` 和 `binary64`；`binary16` 按 Float 位模式检查无损表示，包含次正规数、溢出、正负零、NaN 与无穷值。当前 Ion core 的 `IonValue::Float` 使用 MoonBit 32 位 `Float`，因此 binary32/64 对已解析值不会再缩窄，也无法检测 Ion core 在解析时已舍弃的 binary64 精度。
- `regex` 支持 string 和有文本的 symbol 子串匹配、常用字符类/量词/分组/交替/锚点，以及 `i` 大小写和 `m` 多行标志；点号不匹配换行。无文本 symbol 不匹配。当前子集不接受特殊分组、未实现的转义，以及字符类内部的 `\D` / `\S` / `\W`，并在 Schema 检查时显式报错。
- `annotations` 支持简化语法的 `closed` 与 `required` 修饰符，并支持标准语法的 built-in、命名类型和 `$null_or` 类型引用；标准引用会按有序 symbol list 校验注解，复用引用类型已有的约束。标准 inline 对象目前支持 `container_length` 精确值与范围、无序 `contains` 符号集合、逐个 token 的 `element.valid_values`、`regex`、`codepoint_length`、`utf8_byte_length`，以及 `ordered_elements` 的顺序和 occurrence 校验。文本长度按 Unicode codepoint 与 UTF-8 字节分别统计；无文本 symbol 不满足正则或长度约束。简化语法仅接受以 `IonValue` 保存并能往返保留注解的类型（如 `any`、`$any`、nullable 类型及其别名）；其他标准 inline 约束和原生标量投影类型上的注解约束暂不支持并会显式报错；`document` 不满足任何注解约束。
- `element` 支持 list、sexp、document 和 struct 中每个值的类型约束；`distinct::T` 会按 Ion 值等价语义（含注解）拒绝容器中的重复值。struct 可与 `fields` 组合，也可仅用 `element` 校验并保留开放字段。
- 列表元素支持受支持标量或同一 Schema 命名类型；sexp、document 和 struct 元素按输入顺序逐项校验并在错误路径中标明位置。
- `ordered_elements` 支持 list、sexp 和 document 的异质顺序约束，包含 required、optional、固定次数和整数范围 `occurs`；回溯匹配完整消费序列，并以 `Array[@ion_model.IonValue]` 保存原始值。
- native 文件 CLI 支持相对于当前 `.isl` 文件的 Schema imports，包括整份 Schema 导入、选定类型及 `as` 别名；每个 Schema 只解析本地定义和直接导入，导入循环、缺失类型及名称冲突会报告文件上下文。
- Ion `sexp` 作为 `Array[@ion_model.IonValue]`，支持结构体字段及列表元素；表达式内部值与顺序保持为 Ion 值模型。
- Ion Schema `any` 作为 `@ion_model.IonValue`，可用于字段、列表元素和命名别名；任意非 null `IonValue`（含注解及嵌套值）原样往返。
- Ion Schema `$any` 也作为 `@ion_model.IonValue`，可在字段、列表元素和命名别名中保留 plain null、typed null 及注解。
- nullable built-in（如 `$int`、`$string`、`$null`）以及 type argument 的 `$null_or::T` 映射为原始 `@ion_model.IonValue`，保留 null kind、注解和值；转换时仍按对应 Schema 类型检查。
- Ion Schema `document` 作为有序的 `Array[@ion_model.IonValue]` 顶层流；生成 `from_ion_document_Type` / `to_ion_document_Type` 函数，并支持同 Schema 别名。
- 标量命名类型支持有限 `valid_values` 集合；集合成员比较遵循 Ion 值等价规则并忽略注解，字段与列表元素转换会报告约束失败路径。
- `valid_values` 支持数值和 timestamp 的 `range::[...]`，包括 `min` / `max`、闭区间和 `exclusive::` 边界；上下界需匹配范围类型，数值范围按数学值比较。
- 无循环的同 Schema 命名类型引用；生成声明按依赖顺序排列。
- 结构体与列表的 `from_ion` / `to_ion` 转换。转换会报告字段路径、列表下标和具体 Ion 类型。

项目不实现完整的 Ion Schema 校验器。程序化库 API 仍只接收单个 Schema；包含 imports 的文件请使用 native CLI。递归类型、`annotations` 尚未实现的标准 inline 子约束和 inline type definition 等仍显式报错。`annotations` 标准语法支持 built-in、同 Schema 命名类型、CLI 已解析的直接导入类型及 `$null_or` 类型引用；inline 对象目前实现 `container_length`、`contains`、`element.valid_values`、`element.regex`、`element.codepoint_length`、`element.utf8_byte_length` 和 `ordered_elements`，简化语法保留注解的限制不变。`all_of` / `any_of` / `one_of` / `not` 支持非空的 built-in、同 Schema 命名类型、CLI 已解析的直接导入类型及 `$null_or` 类型参数；约束参数内的 inline import 和 document 类型参数仍显式报错。`valid_values` 范围目前限于 `int` / `float` / `decimal` / `number` 及对应 nullable 数值类型，以及 `timestamp` / `$timestamp`。`$null_or` type argument 不能同时声明显式 `occurs`，遵循 ISL 2.0 规定。`any`/`$any` 接受注解值；对其支持的 `annotations` 约束会检查并保留注解。`document` 只能作为顶层命名类型或别名使用，不能嵌入结构体字段或列表元素；`$any` 表示单个 `IonValue`，document 流由独立类型表示。

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

`schema_header::{imports: [...]}` 中的 `id` 按声明它的 `.isl` 文件目录解析。导入项可只给 `id` 以导入该文件声明的全部类型，也可加 `type` 选定类型，并用 `as` 改名。导入 Schema 自己的导入仅在该文件内部可见，不会传递给调用方。纯库 API `generate_code(schema_text)` 对 imports 返回明确的 unsupported feature 错误。

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

`check_schema(schema_text)` 只检查当前受支持的 Schema 子集；`generate_code(schema_text)` 返回源码和所需导入。已解析的单 Schema Ion 值也可传给 `generate_code_from_ion_values(values)`；它不会把值重新序列化为文本，也不负责解析 imports。程序化调用示例见 `fixtures/generated` 与 `fixtures/references`。

结构体转换校验每个字段的 `occurs` 上下界；必选字段映射为 `T`，可选字段映射为 `T?`，多次出现字段映射为 `Array[T]`。重复字段按输入顺序存储。已声明字段按 Schema 顺序输出，开放结构体的未知字段和值在其后按输入顺序输出，重复项和未解析 SID 均会保留。转换还会报告未知字段、错误 Ion 类型和不符合字段类型的 null。普通具名类型的字段仍拒绝注解；`any` 字段保留所有非 null 值与注解，`$any` 接受任意 Ion 值。nullable built-in 保留其对应 typed null，`$null_or::T` 接受 plain null 或符合 T 的值；这些字段和列表元素都以 `IonValue` 表示。列表转换要求 Ion `list`，逐项验证元素类型，并在错误路径中包含元素下标；`any` 元素拒绝 null，`$any` 元素接受 null。

`sexp` 转换检查外层容器必须是 Ion `sexp`，并保留内部的任意 Ion 值；内部子值不会按其他 Schema 类型递归校验。

`document` 类型转换的是零个或多个顶层 Ion 值组成的有序流。生成函数只在 `Array[@ion_model.IonValue]` 与对应命名类型之间传递数据；文本或二进制解析/编码继续使用 Ion core 的 `parse_text` / `encode_text` 等接口。

## 变更记录

版本变更见 [CHANGELOG.md](CHANGELOG.md)。
