import escpos
import escpos/image
import escpos/printer
import gleam/erlang/process
import gleam/http
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  let assert Ok(printer) = printer.device("/dev/usb/lp0")

  let assert Ok(_) =
    wisp_mist.handler(handle_request(_, printer), secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

pub fn handle_request(req: Request, printer: printer.Printer) -> Response {
  use req <- middleware(req)
  use <- wisp.require_method(req, http.Post)
  case wisp.read_body_bits(req) {
    Ok(data) -> {
      echo data
      case image.from_pgm(data) {
        Ok(image) -> {
          let pi = image.dither_ign(image)
          let _ =
            escpos.new()
            |> escpos.reset()
            |> escpos.image(pi)
            |> printer.print(printer)
          wisp.response(200)
        }
        Error(_) -> wisp.response(500)
      }
    }
    Error(Nil) -> wisp.response(500)
  }
}

fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  handle_request(req)
}
