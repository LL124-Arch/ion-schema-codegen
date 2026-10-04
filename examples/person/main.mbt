///|
fn main {
  let input = "{id: 42, name: \"Ada\", nickname: \"Countess\"}"
  let ion_value = @ion.parse_one_text(input) catch {
    error => {
      println("Ion parse failed: " + error.message())
      return
    }
  }
  let person = Person::from_ion(ion_value) catch {
    _ => {
      println("Ion value does not match the Person schema")
      return
    }
  }
  let updated : Person = {
    id: person.id,
    name: person.name + " Lovelace",
    nickname: Some("Ada"),
  }
  let output = @ion.encode_value_text(Person::to_ion(updated)) catch {
    error => {
      println("Ion write failed: " + error.message())
      return
    }
  }
  println(output)
}
