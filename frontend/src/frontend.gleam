import gleam/dynamic/decode
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/javascript/promise
import gleam/option
import gleam/string
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type State {
  Idle
  Printing
  Success(String)
  Failure(String)
}

type Model {
  Model(image_url: option.Option(String), state: State)
}

fn init(_args) -> #(Model, Effect(Msg)) {
  let model = Model(image_url: option.None, state: Idle)

  #(model, effect.none())
}

type Msg {
  UserSelectedFile(String)
  UserImageSubmitted
  PrintResult(Result(response.Response(fetch.FetchBody), fetch.FetchError))
  GotError(String)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserSelectedFile(url) -> #(
      Model(image_url: option.Some(url), state: Idle),
      effect.none(),
    )
    UserImageSubmitted ->
      case model.image_url {
        option.Some(url) -> #(
          Model(..model, state: Printing),
          convert_and_print_image(url),
        )
        option.None -> #(
          Model(..model, state: Failure("No image selected")),
          effect.none(),
        )
      }
    PrintResult(result) ->
      case result {
        Ok(_) -> #(
          Model(..model, state: Success("Image printed")),
          effect.none(),
        )
        Error(e) -> #(
          Model(
            ..model,
            state: Failure("Couldn't print image: " <> string.inspect(e)),
          ),
          effect.none(),
        )
      }
    GotError(e) -> #(Model(..model, state: Failure(e)), effect.none())
  }
}

const btn = "py-2 px-3 cursor-pointer text-pink-300 bg-pink-100 rounded-md border-2 border-pink-300 hover:bg-pink-200 font-bold disabled:cursor-not-allowed disabled:hover:bg-pink-100"

fn view(model: Model) -> Element(Msg) {
  html.main(
    [
      a.class(
        "flex flex-col gap-2 justify-center items-center min-h-screen bg-pink-100",
      ),
    ],
    [
      html.h1([a.class("text-3xl font-black text-center text-pink-300")], [
        html.text("Glathering Photo Service"),
      ]),
      html.div(
        [
          a.class(
            "p-5 mx-2 flex flex-col gap-5 xl:max-w-xl rounded-lg border-2 border-white bg-white/50 shadow",
          ),
        ],
        [
          case model.image_url {
            option.Some(url) ->
              html.img([
                a.src(url),
                a.class("object-contain max-w-full h-auto"),
              ])
            option.None -> html.text("")
          },

          html.div(
            [a.class("flex flex-col gap-2 justify-between md:flex-row")],
            [
              html.input([
                a.type_("file"),
                a.accept(["image/png", "image/jpg", "image/jpeg"]),
                a.disabled(model.state == Printing),
                a.class(btn),
                a.class("text-xs md:text-base"),
                event.on("change", handle_file_select()),
              ]),

              html.button(
                [
                  event.on_click(UserImageSubmitted),
                  a.disabled(
                    model.state == Printing || model.image_url == option.None,
                  ),
                  a.class(btn),
                ],
                [html.text("Print")],
              ),
            ],
          ),

          case model.state {
            Failure(e) ->
              html.p(
                [
                  a.class(
                    "text-red-600 bg-red-50 rounded border-2 border-red-600 p-2",
                  ),
                ],
                [
                  html.text(e),
                ],
              )
            Success(msg) ->
              html.p(
                [
                  a.class(
                    "text-green-600 bg-red-50 rounded border-2 border-green-600 p-2",
                  ),
                ],
                [
                  html.text(msg),
                ],
              )
            _ -> html.text("")
          },
        ],
      ),
    ],
  )
}

fn convert_and_print_image(url) -> Effect(Msg) {
  use dispatch <- effect.from
  promise.await(prepare_pgm(url, 640), fn(pgm_result) {
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

fn handle_file_select() -> decode.Decoder(Msg) {
  use res <- decode.subfield(
    ["target", "files"],
    decode.at(
      [0],
      decode.dynamic
        |> decode.map(create_object_url),
    ),
  )
  decode.success(UserSelectedFile(res))
}

@external(javascript, "./frontend.ffi.mjs", "createObjectUrl")
fn create_object_url(file: decode.Dynamic) -> String

@external(javascript, "./frontend.ffi.mjs", "preparePGM")
fn prepare_pgm(
  url: String,
  width: Int,
) -> promise.Promise(Result(BitArray, String))
