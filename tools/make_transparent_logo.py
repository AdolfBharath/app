from __future__ import annotations

from pathlib import Path

from PIL import Image


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    src = repo_root / "assets" / "favicon.png"
    dst = repo_root / "assets" / "jenovate_logo.png"

    im = Image.open(src).convert("RGBA")
    pixels = im.load()

    # Make near-black pixels transparent.
    # This removes the solid black background in the provided logo.
    threshold = 18
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if r <= threshold and g <= threshold and b <= threshold:
                pixels[x, y] = (r, g, b, 0)

    # Trim fully transparent margins.
    bbox = im.getbbox()
    if bbox is not None:
        im = im.crop(bbox)

    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    print(f"Wrote {dst} size={im.size}")


if __name__ == "__main__":
    main()
