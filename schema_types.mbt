///|
pub(all) suberror SchemaError {
  IonParse(String)
  InvalidSchema(String)
  UnsupportedVersion(String)
  UnsupportedFeature(String)
  DuplicateType(String)
  DuplicateField(type_name~ : String, field_name~ : String)
  UnknownType(String)
  CyclicTypeReference(String)
  InvalidOccurs(String)
  InvalidIdentifier(String)
  IdentifierCollision(String)
}

///|
/// Generated MoonBit declarations and the package imports they need.
///
/// Add each entry from [package_imports] to the target package configuration.
pub(all) struct GeneratedCode {
  source : String
  package_imports : Array[String]
}

///|
priv enum TypeRef {
  Builtin(String)
  Named(String)
  NullOrBuiltin(String)
  NullOrNamed(String)
}

///|
priv enum TypeBody {
  Scalar(TypeRef)
  Alias(TypeRef)
  Struct(Array[FieldSpec], Bool)
  List(TypeRef)
}

///|
priv struct FieldOccurrence {
  min_count : Int
  max_count : Int?
}

///|
priv struct IntegerRange {
  minimum : Int
  maximum : Int?
}

///|
priv struct RegexConstraint {
  pattern : String
}

///|
priv struct OrderedElementSpec {
  type_ref : TypeRef
  occurrence : FieldOccurrence
}

///|
priv struct FieldSpec {
  name : String
  type_ref : TypeRef
  occurrence : FieldOccurrence
}

///|
priv struct NamedType {
  name : String
  body : TypeBody
  element_type : TypeRef?
  element_distinct : Bool
  contains_values : Array[@model.IonValue]?
  field_names_type : TypeRef?
  field_names_distinct : Bool
  ordered_elements : Array[OrderedElementSpec]?
  valid_values : Array[@model.IonValue]?
  precision_ranges : Array[IntegerRange]
  exponent_ranges : Array[IntegerRange]
  timestamp_precision_ranges : Array[IntegerRange]
  timestamp_offsets : Array[Array[Int?]]
  ieee754_float_formats : Array[String]
  regex_constraints : Array[RegexConstraint]
  container_lengths : Array[IntegerRange]
  codepoint_lengths : Array[IntegerRange]
  utf8_byte_lengths : Array[IntegerRange]
  byte_lengths : Array[IntegerRange]
}

///|
priv struct Schema {
  types : Array[NamedType]
}
