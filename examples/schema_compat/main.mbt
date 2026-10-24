///|
fn main {
  let order = Order::from_ion(
    @ion.parse_one_text("{quantity:3}") catch {
      _ => abort("cannot parse order")
    },
  ) catch {
    _ => abort("order does not satisfy its imported and repeated constraints")
  }
  let values = from_ion_Values(
    @ion.parse_one_text("[1,2,3]") catch {
      _ => abort("cannot parse values")
    },
  ) catch {
    _ => abort("values do not satisfy both element and ordered constraints")
  }
  println(
    @ion.encode_value_text(order.to_ion()) catch {
      _ => abort("cannot encode order")
    },
  )
  println(
    @ion.encode_value_text(to_ion_Values(values)) catch {
      _ => abort("cannot encode values")
    },
  )
  let stream = from_ion_document_StreamAlias(
    @ion.parse_text("1 2 3") catch {
      _ => abort("cannot parse stream")
    },
  ) catch {
    _ => abort("stream does not satisfy its repeated constraints")
  }
  println("stream values: " + stream.length().to_string())
}
