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
}

///|
priv enum TypeBody {
  Scalar(TypeRef)
  Alias(TypeRef)
  Struct(Array[FieldSpec])
  List(TypeRef)
}

///|
priv enum FieldOccurrence {
  Required
  Optional
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
}

///|
priv struct Schema {
  types : Array[NamedType]
}
