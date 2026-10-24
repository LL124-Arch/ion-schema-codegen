///|
fn main {
  let schema = "$ion_schema_2_0 type::{name:'quantity.total',type:int,valid_values:range::[1,100]} type::{name:Order,type:struct,fields:closed::{quantity:{type:'quantity.total',occurs:required},title:{type:string,occurs:required}}} type::{name:Stream,type:document,element:Order} type::{name:Overlapping,type:$any,one_of:[int,number]}"
  let validator = @codegen.SchemaValidator::new(schema) catch {
    _ => abort("invalid schema")
  }
  for
    (name, type_name, source) in [
      ("valid_order", "Order", "{quantity:3,title:\"MoonBit\"}"),
      ("invalid_order", "Order", "{quantity:0,quantity:2,title:1}"),
      ("overlapping_types", "Overlapping", "3"),
    ] {
    let report = validator.validate_text(type_name, source) catch {
      _ => abort("invalid validation request")
    }
    println(
      Json::object(
        Map([("case", name.to_json()), ("report", report.to_json())]),
      ).stringify(),
    )
  }
  let stream = validator.validate_document_text(
    "Stream", "{quantity:1,title:\"first\"} {quantity:2,title:\"second\"}",
  ) catch {
    _ => abort("invalid stream request")
  }
  println(
    Json::object(Map([("case", "document"), ("report", stream.to_json())])).stringify(),
  )
  let bounded = validator.validate_text(
    "Order",
    "{quantity:3,title:\"MoonBit\"}",
    limits={
      max_depth: 64,
      max_nodes: 10000,
      max_steps: 5,
      max_diagnostics: 100,
    },
  ) catch {
    _ => abort("invalid limits")
  }
  println(
    Json::object(Map([("case", "bounded_work"), ("report", bounded.to_json())])).stringify(),
  )
  let annotated = @codegen.SchemaValidator::new(
    "$ion_schema_2_0 type::{name:AnnotationTokens,type:list,element:symbol,container_length:2} type::{name:Approved,type:int,annotations:closed::required::[approved]} type::{name:TaggedInt,type:int,annotations:AnnotationTokens} type::{name:TaggedOrder,type:struct,fields:closed::{quantity:{type:int,occurs:required}},annotations:required::[approved]}",
  ) catch {
    _ => abort("invalid annotation schema")
  }
  for
    (name, type_name, source) in [
      ("annotated_integer", "Approved", "approved::3"),
      ("missing_annotation", "Approved", "3"),
      ("standard_annotation_type", "TaggedInt", "approved::audit::3"),
      ("annotated_struct", "TaggedOrder", "approved::{quantity:1}"),
    ] {
    let report = annotated.validate_text(type_name, source) catch {
      _ => abort("invalid annotation request")
    }
    println(
      Json::object(
        Map([("case", name.to_json()), ("report", report.to_json())]),
      ).stringify(),
    )
  }
  let equality = @codegen.SchemaValidator::new(
    "$ion_schema_2_0 type::{name:DistinctFloats,type:list,element:distinct::float} type::{name:PositiveZero,type:float,valid_values:[0e0]} type::{name:KnownSymbol,type:symbol,valid_values:[known]}",
  ) catch {
    _ => abort("invalid equality schema")
  }
  for
    (name, type_name, source) in [
      ("distinct_signed_zeros", "DistinctFloats", "[0e0,-0e0]"),
      ("negative_zero_literal", "PositiveZero", "-0e0"),
    ] {
    let report = equality.validate_text(type_name, source) catch {
      _ => abort("invalid equality request")
    }
    println(
      Json::object(
        Map([("case", name.to_json()), ("report", report.to_json())]),
      ).stringify(),
    )
  }
  let symbol = @model.IonValue::Symbol({ text: Some("known"), sid: Some(77), })
  let resolved = equality.validate("KnownSymbol", symbol) catch {
    _ => abort("invalid symbol request")
  }
  println(
    Json::object(
      Map([("case", "resolved_symbol"), ("report", resolved.to_json())]),
    ).stringify(),
  )
}
