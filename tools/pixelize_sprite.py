"""Convert an alpha-matted concept into a native-resolution pixel sprite.

The output has a hard alpha mask, a deliberately small adaptive palette, no
dithering, and transparent padding. It is intended for generated concepts that
have already been separated from their chroma background.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument("--colors", default=32, type=int)
    parser.add_argument("--padding", default=1, type=int)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = Image.open(args.input).convert("RGBA")
    alpha = source.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise SystemExit("Input contains no opaque subject")
    subject = source.crop(bounds)
    inner_width = max(1, args.width - args.padding * 2)
    inner_height = max(1, args.height - args.padding * 2)
    scale = min(inner_width / subject.width, inner_height / subject.height)
    sprite_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    reduced = subject.resize(sprite_size, Image.Resampling.LANCZOS)
    reduced_alpha = reduced.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = reduced.convert("RGB").quantize(
        colors=max(2, min(256, args.colors)),
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    reduced = rgb.convert("RGBA")
    reduced.putalpha(reduced_alpha)
    canvas = Image.new("RGBA", (args.width, args.height), (0, 0, 0, 0))
    offset = ((args.width - reduced.width) // 2, (args.height - reduced.height) // 2)
    canvas.alpha_composite(reduced, offset)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output, optimize=False)
    print(
        f"Wrote {args.output} at {args.width}x{args.height}, "
        f"subject {reduced.width}x{reduced.height}, palette <= {args.colors}"
    )


if __name__ == "__main__":
    main()
