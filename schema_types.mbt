///|
pub(all) suberror SchemaError {
  IonParse(String)
  InvalidSchema(String)
  UnsupportedVersion(String)
  UnsupportedFeature(String)
  DuplicateType(String)
  DuplicateField(type_name~ : String, field_name~ : String)
  UnknownType(String)
  InvalidOccurs(String)
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
