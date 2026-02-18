import { BitArray$BitArray } from "./gleam.mjs"
import { Result$Ok, Result$Error } from "./gleam.mjs"
import { Jimp } from "jimp"
import { intToRGBA } from "@jimp/utils"

export function getImageUrl(event) {
  const files = event.target?.files
  if (files && files.length > 0) {
    const url = URL.createObjectURL(files[0])
    return Result$Ok(url)
  } else {
    return Result$Error("No file selected")
  }
}

export async function resizeAndConvertToPGM(url, width) {
  try {
    const image = await Jimp.read(url)
    image.resize({ w: width, h: Jimp.AUTO })
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
