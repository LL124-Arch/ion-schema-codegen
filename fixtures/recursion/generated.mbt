///|
pub(all) suberror ConversionError {
  TypeMismatch(path~ : String, expected~ : String, actual~ : String)
  InvalidValue(path~ : String, constraint~ : String, actual~ : String)
  MissingRequiredField(path~ : String)
  DuplicateField(path~ : String)
  FieldOccurrenceMismatch(path~ : String, expected~ : String, actual~ : Int)
  UnknownField(path~ : String)
  UnknownSymbol(path~ : String, sid~ : Int)
  NullNotAllowed(path~ : String)
  AnnotatedValueNotSupported(path~ : String)
}

///|
fn ion_schema_codegen_kind_name(kind : @ion_model.IonNull) -> String {
  match kind {
    @ion_model.IonNull::Null => "null"
    @ion_model.IonNull::Bool => "bool"
    @ion_model.IonNull::Int => "int"
    @ion_model.IonNull::Float => "float"
    @ion_model.IonNull::Decimal => "decimal"
    @ion_model.IonNull::Timestamp => "timestamp"
    @ion_model.IonNull::Symbol => "symbol"
    @ion_model.IonNull::String => "string"
    @ion_model.IonNull::Blob => "blob"
    @ion_model.IonNull::Clob => "clob"
    @ion_model.IonNull::List => "list"
    @ion_model.IonNull::Sexp => "sexp"
    @ion_model.IonNull::Struct => "struct"
  }
}

///|
fn ion_schema_codegen_actual_type(value : @ion_model.IonValue) -> String {
  let kind = value.kind()
  match (value.is_null(), kind) {
    (true, @ion_model.IonNull::Null) => "null"
    (true, typed_kind) => "null.\{ion_schema_codegen_kind_name(typed_kind)}"
    (false, actual_kind) => ion_schema_codegen_kind_name(actual_kind)
  }
}

///|
fn ion_schema_codegen_matches_type(
  value : @ion_model.IonValue,
  expected : String,
) -> Bool {
  let kind = value.kind()
  let is_null = value.is_null()
  match expected {
    "any" => !is_null
    "$any" => true
    "$null" => is_null && kind == @ion_model.IonNull::Null
    "bool" => !is_null && kind == @ion_model.IonNull::Bool
    "$bool" => kind == @ion_model.IonNull::Bool
    "int" => !is_null && kind == @ion_model.IonNull::Int
    "$int" => kind == @ion_model.IonNull::Int
    "float" => !is_null && kind == @ion_model.IonNull::Float
    "$float" => kind == @ion_model.IonNull::Float
    "decimal" => !is_null && kind == @ion_model.IonNull::Decimal
    "$decimal" => kind == @ion_model.IonNull::Decimal
    "string" => !is_null && kind == @ion_model.IonNull::String
    "$string" => kind == @ion_model.IonNull::String
    "symbol" => !is_null && kind == @ion_model.IonNull::Symbol
    "$symbol" => kind == @ion_model.IonNull::Symbol
    "timestamp" => !is_null && kind == @ion_model.IonNull::Timestamp
    "$timestamp" => kind == @ion_model.IonNull::Timestamp
    "blob" => !is_null && kind == @ion_model.IonNull::Blob
    "$blob" => kind == @ion_model.IonNull::Blob
    "clob" => !is_null && kind == @ion_model.IonNull::Clob
    "$clob" => kind == @ion_model.IonNull::Clob
    "list" => !is_null && kind == @ion_model.IonNull::List
    "$list" => kind == @ion_model.IonNull::List
    "sexp" => !is_null && kind == @ion_model.IonNull::Sexp
    "$sexp" => kind == @ion_model.IonNull::Sexp
    "struct" => !is_null && kind == @ion_model.IonNull::Struct
    "$struct" => kind == @ion_model.IonNull::Struct
    "number" | "$number" =>
      (
        kind == @ion_model.IonNull::Int ||
        kind == @ion_model.IonNull::Float ||
        kind == @ion_model.IonNull::Decimal
      ) &&
      (expected == "$number" || !is_null)
    "text" | "$text" =>
      (kind == @ion_model.IonNull::String || kind == @ion_model.IonNull::Symbol) &&
      (expected == "$text" || !is_null)
    "lob" | "$lob" =>
      (kind == @ion_model.IonNull::Blob || kind == @ion_model.IonNull::Clob) &&
      (expected == "$lob" || !is_null)
    _ => false
  }
}

///|
fn ion_schema_codegen_prefix_error(
  error : ConversionError,
  prefix : String,
) -> ConversionError {
  match error {
    ConversionError::TypeMismatch(path~, expected~, actual~) =>
      ConversionError::TypeMismatch(path=prefix + path, expected~, actual~)
    ConversionError::InvalidValue(path~, constraint~, actual~) =>
      ConversionError::InvalidValue(path=prefix + path, constraint~, actual~)
    ConversionError::MissingRequiredField(path~) =>
      ConversionError::MissingRequiredField(path=prefix + path)
    ConversionError::DuplicateField(path~) =>
      ConversionError::DuplicateField(path=prefix + path)
    ConversionError::FieldOccurrenceMismatch(path~, expected~, actual~) =>
      ConversionError::FieldOccurrenceMismatch(
        path=prefix + path,
        expected~,
        actual~,
      )
    ConversionError::UnknownField(path~) =>
      ConversionError::UnknownField(path=prefix + path)
    ConversionError::UnknownSymbol(path~, sid~) =>
      ConversionError::UnknownSymbol(path=prefix + path, sid~)
    ConversionError::NullNotAllowed(path~) =>
      ConversionError::NullNotAllowed(path=prefix + path)
    ConversionError::AnnotatedValueNotSupported(path~) =>
      ConversionError::AnnotatedValueNotSupported(path=prefix + path)
  }
}

///|
pub type TreeNodeList = Array[TreeNode]

///|
/// Convert an Ion list to TreeNodeList with element-level diagnostics.
pub fn from_ion_TreeNodeList(
  value : @ion_model.IonValue,
) -> TreeNodeList raise ConversionError {
  let type_path = "TreeNodeList"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_elements = match value.without_annotations() {
    @ion_model.IonValue::List(elements) => elements
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="list",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let converted : TreeNodeList = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : TreeNode = TreeNode::from_ion(element) catch {
      error => raise ion_schema_codegen_prefix_error(error, element_path + ".")
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert TreeNodeList into an Ion list.
pub fn to_ion_TreeNodeList(items : TreeNodeList) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(TreeNode::to_ion(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct TreeNode {
  value : String
  note : @ion_model.IonValue?
  children : TreeNodeList
}

///|
/// Convert an Ion struct to TreeNode with field-level diagnostics.
pub fn TreeNode::from_ion(
  value : @ion_model.IonValue,
) -> TreeNode raise ConversionError {
  let type_path = "TreeNode"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_fields = match value.without_annotations() {
    @ion_model.IonValue::Struct(fields) => fields
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="struct",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  let mut input_field_1 : @ion_model.IonValue? = None
  let mut input_field_2 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "value" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="TreeNode.value")
              None => Some(field_value)
            }
          "note" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="TreeNode.note")
              None => Some(field_value)
            }
          "children" =>
            input_field_2 = match input_field_2 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="TreeNode.children")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(path="TreeNode." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="TreeNode.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : String = match input_field_0 {
    Some(field_value) => {
      let field_path = "TreeNode.value"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="TreeNode.value")
  }
  let ion_schema_codegen_value_1 : @ion_model.IonValue? = match input_field_1 {
    Some(field_value) => {
      let field_path = "TreeNode.note"
      let field_item : @ion_model.IonValue = if ion_schema_codegen_matches_type(
          field_value, "$null",
        ) {
        field_value
      } else {
        if !ion_schema_codegen_matches_type(field_value, "string") {
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
        }
        field_value
      }
      Some(field_item)
    }
    None => None
  }
  let ion_schema_codegen_value_2 : TreeNodeList = match input_field_2 {
    Some(field_value) => {
      let field_path = "TreeNode.children"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : TreeNodeList = from_ion_TreeNodeList(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      field_item
    }
    None =>
      raise ConversionError::MissingRequiredField(path="TreeNode.children")
  }
  {
    value: ion_schema_codegen_value_0,
    note: ion_schema_codegen_value_1,
    children: ion_schema_codegen_value_2,
  }
}

///|
/// Convert TreeNode into an Ion struct in schema field order.
pub fn TreeNode::to_ion(self : TreeNode) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("value"),
      @ion_model.IonValue::String(self.value),
    ),
  )
  match self.note {
    Some(field_value) =>
      output_fields.push((@ion_model.IonSymbol::from_text("note"), field_value))
    None => ()
  }
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("children"),
      to_ion_TreeNodeList(self.children),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct LinkNode {
  label : String
  next : LinkNode?
}

///|
/// Convert an Ion struct to LinkNode with field-level diagnostics.
pub fn LinkNode::from_ion(
  value : @ion_model.IonValue,
) -> LinkNode raise ConversionError {
  let type_path = "LinkNode"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_fields = match value.without_annotations() {
    @ion_model.IonValue::Struct(fields) => fields
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="struct",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  let mut input_field_1 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "label" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="LinkNode.label")
              None => Some(field_value)
            }
          "next" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="LinkNode.next")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(path="LinkNode." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="LinkNode.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : String = match input_field_0 {
    Some(field_value) => {
      let field_path = "LinkNode.label"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="LinkNode.label")
  }
  let ion_schema_codegen_value_1 : LinkNode? = match input_field_1 {
    Some(field_value) => {
      let field_path = "LinkNode.next"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : LinkNode = LinkNode::from_ion(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      Some(field_item)
    }
    None => None
  }
  { label: ion_schema_codegen_value_0, next: ion_schema_codegen_value_1, }
}

///|
/// Convert LinkNode into an Ion struct in schema field order.
pub fn LinkNode::to_ion(self : LinkNode) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("label"),
      @ion_model.IonValue::String(self.label),
    ),
  )
  match self.next {
    Some(field_value) =>
      output_fields.push(
        (@ion_model.IonSymbol::from_text("next"), LinkNode::to_ion(field_value)),
      )
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct NullableNode {
  next : @ion_model.IonValue?
}

///|
/// Convert an Ion struct to NullableNode with field-level diagnostics.
pub fn NullableNode::from_ion(
  value : @ion_model.IonValue,
) -> NullableNode raise ConversionError {
  let type_path = "NullableNode"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_fields = match value.without_annotations() {
    @ion_model.IonValue::Struct(fields) => fields
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="struct",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "next" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="NullableNode.next")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(
              path="NullableNode." + field_name,
            )
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="NullableNode.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : @ion_model.IonValue? = match input_field_0 {
    Some(field_value) => {
      let field_path = "NullableNode.next"
      let field_item : @ion_model.IonValue = if ion_schema_codegen_matches_type(
          field_value, "$null",
        ) {
        field_value
      } else {
        let _ = NullableNode::from_ion(field_value) catch {
          error =>
            raise ion_schema_codegen_prefix_error(error, field_path + ".")
        }
        field_value
      }
      if !ion_schema_codegen_matches_type(field_value, "$null") {

      }
      Some(field_item)
    }
    None => None
  }
  { next: ion_schema_codegen_value_0, }
}

///|
/// Convert NullableNode into an Ion struct in schema field order.
pub fn NullableNode::to_ion(self : NullableNode) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  match self.next {
    Some(field_value) =>
      output_fields.push((@ion_model.IonSymbol::from_text("next"), field_value))
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub(all) struct BranchLeaf {
  name : String
  parent : Branch?
}

///|
/// Convert an Ion struct to BranchLeaf with field-level diagnostics.
pub fn BranchLeaf::from_ion(
  value : @ion_model.IonValue,
) -> BranchLeaf raise ConversionError {
  let type_path = "BranchLeaf"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_fields = match value.without_annotations() {
    @ion_model.IonValue::Struct(fields) => fields
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="struct",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  let mut input_field_1 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "name" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="BranchLeaf.name")
              None => Some(field_value)
            }
          "parent" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="BranchLeaf.parent")
              None => Some(field_value)
            }
          _ =>
            raise ConversionError::UnknownField(path="BranchLeaf." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="BranchLeaf.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : String = match input_field_0 {
    Some(field_value) => {
      let field_path = "BranchLeaf.name"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="BranchLeaf.name")
  }
  let ion_schema_codegen_value_1 : Branch? = match input_field_1 {
    Some(field_value) => {
      let field_path = "BranchLeaf.parent"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : Branch = Branch::from_ion(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      Some(field_item)
    }
    None => None
  }
  { name: ion_schema_codegen_value_0, parent: ion_schema_codegen_value_1, }
}

///|
/// Convert BranchLeaf into an Ion struct in schema field order.
pub fn BranchLeaf::to_ion(self : BranchLeaf) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("name"),
      @ion_model.IonValue::String(self.name),
    ),
  )
  match self.parent {
    Some(field_value) =>
      output_fields.push(
        (@ion_model.IonSymbol::from_text("parent"), Branch::to_ion(field_value)),
      )
    None => ()
  }
  @ion_model.IonValue::Struct(output_fields)
}

///|
pub type BranchLeaves = Array[BranchLeaf]

///|
/// Convert an Ion list to BranchLeaves with element-level diagnostics.
pub fn from_ion_BranchLeaves(
  value : @ion_model.IonValue,
) -> BranchLeaves raise ConversionError {
  let type_path = "BranchLeaves"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_elements = match value.without_annotations() {
    @ion_model.IonValue::List(elements) => elements
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="list",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let converted : BranchLeaves = []
  let mut index = 0
  for element in input_elements {
    let element_path = type_path + "[" + index.to_string() + "]"
    if element.annotations().length() > 0 {
      raise ConversionError::AnnotatedValueNotSupported(path=element_path)
    }
    if element.is_null() {
      raise ConversionError::NullNotAllowed(path=element_path)
    }
    let item : BranchLeaf = BranchLeaf::from_ion(element) catch {
      error => raise ion_schema_codegen_prefix_error(error, element_path + ".")
    }
    converted.push(item)
    index += 1
  }
  converted
}

///|
/// Convert BranchLeaves into an Ion list.
pub fn to_ion_BranchLeaves(items : BranchLeaves) -> @ion_model.IonValue {
  let output_elements : Array[@ion_model.IonValue] = []
  for element in items {
    output_elements.push(BranchLeaf::to_ion(element))
  }
  @ion_model.IonValue::List(output_elements)
}

///|
pub(all) struct Branch {
  name : String
  leaves : BranchLeaves
}

///|
/// Convert an Ion struct to Branch with field-level diagnostics.
pub fn Branch::from_ion(
  value : @ion_model.IonValue,
) -> Branch raise ConversionError {
  let type_path = "Branch"
  if value.is_null() {
    raise ConversionError::NullNotAllowed(path=type_path)
  }
  if value.annotations().length() > 0 {
    raise ConversionError::AnnotatedValueNotSupported(path=type_path)
  }
  let input_fields = match value.without_annotations() {
    @ion_model.IonValue::Struct(fields) => fields
    _ =>
      raise ConversionError::TypeMismatch(
        path=type_path,
        expected="struct",
        actual=ion_schema_codegen_actual_type(value),
      )
  }
  let mut input_field_0 : @ion_model.IonValue? = None
  let mut input_field_1 : @ion_model.IonValue? = None
  for (field_symbol, field_value) in input_fields {
    match field_symbol.text_value() {
      Some(field_name) =>
        match field_name {
          "name" =>
            input_field_0 = match input_field_0 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="Branch.name")
              None => Some(field_value)
            }
          "leaves" =>
            input_field_1 = match input_field_1 {
              Some(_) =>
                raise ConversionError::DuplicateField(path="Branch.leaves")
              None => Some(field_value)
            }
          _ => raise ConversionError::UnknownField(path="Branch." + field_name)
        }
      None =>
        raise ConversionError::UnknownSymbol(
          path="Branch.<field>",
          sid=field_symbol.sid_value().unwrap_or(0),
        )
    }
  }
  let ion_schema_codegen_value_0 : String = match input_field_0 {
    Some(field_value) => {
      let field_path = "Branch.name"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : String = match field_value.without_annotations() {
        @ion_model.IonValue::String(converted_value) => converted_value
        _ =>
          raise ConversionError::TypeMismatch(
            path=field_path,
            expected="string",
            actual=ion_schema_codegen_actual_type(field_value),
          )
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="Branch.name")
  }
  let ion_schema_codegen_value_1 : BranchLeaves = match input_field_1 {
    Some(field_value) => {
      let field_path = "Branch.leaves"
      if field_value.annotations().length() > 0 {
        raise ConversionError::AnnotatedValueNotSupported(path=field_path)
      }
      if field_value.is_null() {
        raise ConversionError::NullNotAllowed(path=field_path)
      }
      let field_item : BranchLeaves = from_ion_BranchLeaves(field_value) catch {
        error => raise ion_schema_codegen_prefix_error(error, field_path + ".")
      }
      field_item
    }
    None => raise ConversionError::MissingRequiredField(path="Branch.leaves")
  }
  { name: ion_schema_codegen_value_0, leaves: ion_schema_codegen_value_1, }
}

///|
/// Convert Branch into an Ion struct in schema field order.
pub fn Branch::to_ion(self : Branch) -> @ion_model.IonValue {
  let output_fields : Array[(@ion_model.IonSymbol, @ion_model.IonValue)] = []
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("name"),
      @ion_model.IonValue::String(self.name),
    ),
  )
  output_fields.push(
    (
      @ion_model.IonSymbol::from_text("leaves"),
      to_ion_BranchLeaves(self.leaves),
    ),
  )
  @ion_model.IonValue::Struct(output_fields)
}
