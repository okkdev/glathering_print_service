import gleam/dynamic/decode
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/javascript/promise
import gleam/option
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(image_url: option.Option(String), error: option.Option(String))
}

fn init(_args) -> #(Model, Effect(Msg)) {
  let model = Model(image_url: option.None, error: option.None)

  #(model, effect.none())
}

type Msg {
  UserSelectedFile(decode.Dynamic)
  UserImageSubmitted
  PrintResult(Result(response.Response(fetch.FetchBody), fetch.FetchError))
  GotError(String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserSelectedFile(event) ->
      case get_image_url(event) {
        Ok(url) -> #(
          Model(image_url: option.Some(url), error: option.None),
          effect.none(),
        )
        Error(e) -> #(Model(..model, error: option.Some(e)), effect.none())
      }
    UserImageSubmitted ->
      case model.image_url {
        option.Some(url) -> #(
          Model(..model, error: option.None),
          convert_and_print_image(url),
        )
        option.None -> #(
          Model(..model, error: option.Some("No image selected")),
          effect.none(),
        )
      }
    PrintResult(result) ->
      case result {
        Ok(_) -> #(Model(..model, error: option.None), effect.none())
        Error(e) -> #(
          Model(
            ..model,
            error: option.Some("Couldn't print image: " <> string.inspect(e)),
          ),
          effect.none(),
        )
      }
    GotError(e) -> #(Model(..model, error: option.Some(e)), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.input([
      attribute.type_("file"),
      attribute.accept(["image/"]),
      event.on("change", decode.dynamic |> decode.map(UserSelectedFile)),
    ]),
    html.button([event.on_click(UserImageSubmitted)], [html.text("Print")]),
    case model.error {
      option.Some(e) ->
        html.p([attribute.style("color", "red")], [html.text(e)])
      option.None -> html.text("")
    },
  ])
}

fn convert_and_print_image(url) -> Effect(Msg) {
  use dispatch <- effect.from
  promise.await(convert_to_pgm(url, 640), fn(pgm_result) {
    case pgm_result {
      Ok(pgm) -> {
        let assert Ok(req) = request.to("http://localhost:8000")
        let req =
          req
          |> request.set_method(http.Post)
          |> request.set_body(pgm)
        use send_result <- promise.await(fetch.send_bits(req))
        dispatch(PrintResult(send_result))
        |> promise.resolve
      }
      Error(e) -> {
        dispatch(GotError(e))
        promise.resolve(Nil)
      }
    }
  })
  Nil
}

@external(javascript, "./frontend.ffi.mjs", "getImageUrl")
fn get_image_url(event: decode.Dynamic) -> Result(String, String)

@external(javascript, "./frontend.ffi.mjs", "resizeAndConvertToPGM")
fn convert_to_pgm(
  url: String,
  width: Int,
) -> promise.Promise(Result(BitArray, String))
