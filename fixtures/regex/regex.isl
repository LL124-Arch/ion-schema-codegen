$ion_schema_2_0
type::{name: Digits, type: string, regex: "[0-9]+"}
type::{name: AnchoredDigits, type: string, regex: "^[0-9]+$"}
type::{name: CaseInsensitive, type: string, regex: i::"ion"}
type::{name: MultilineValue, type: string, regex: m::"^value$"}
type::{name: DotWithoutLineBreak, type: string, regex: "a.b"}
type::{name: SymbolCode, type: symbol, regex: i::"[a-z]+"}
type::{name: DigitAlias, type: Digits, regex: "[0-9]{2,}"}
type::{name: RegexArray, type: list, element: AnchoredDigits}
type::{name: RegexRecord, type: struct, fields: closed::{code: {type: AnchoredDigits, occurs: required}}}
