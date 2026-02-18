import { BitArray$BitArray } from "./gleam.mjs"
import { Result$Ok, Result$Error } from "./gleam.mjs"
import { Jimp } from "jimp"
import { intToRGBA } from "@jimp/utils"

export function createObjectUrl(file) {
  console.log(file)
  return URL.createObjectURL(file)
}

export async function preparePGM(url, width) {
  try {
    const [image, overlay] = await Promise.all([
      Jimp.read(url),
      Jimp.read("/gglogo.png"),
    ])
    image.resize({ w: width, h: Jimp.AUTO })

    const x = image.width - overlay.width
    const y = image.height - overlay.height / 1.5
    image.composite(overlay, x, y)

    image.greyscale()

    const w = image.width
    const h = image.height

    const header = `P5\n${w} ${h}\n255\n`
    const headerBytes = new TextEncoder().encode(header)
    const pixelData = new Uint8Array(w * h)

    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const pixel = intToRGBA(image.getPixelColor(x, y))
        pixelData[y * w + x] = pixel.r
      }
    }

    const result = new Uint8Array(headerBytes.length + pixelData.length)
    result.set(headerBytes, 0)
    result.set(pixelData, headerBytes.length)

    return Result$Ok(BitArray$BitArray(result))
  } catch (err) {
    return Result$Error(err.message)
  }
}
