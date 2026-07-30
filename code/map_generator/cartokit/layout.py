"""
Physical-unit geometry and typography for a declared print size.

Author:     Pouria Hadjibagheri
Email:      p.bagheri@ucl.ac.uk
Copyright:  (c) 2026 Pouria Hadjibagheri
License:    PolyForm Noncommercial 1.0.0 (attribution required, noncommercial use only)
"""

# Python imports
# ============================
from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path

# Third party imports
# ============================
from PIL import ImageFont

# Internal imports
# ============================
# None


__all__ = [
    "DEFAULT_FONT_CANDIDATES",
    "FigureMetrics",
    "FontWeight",
]


_MILLIMETRES_PER_INCH = 25.4
_POINTS_PER_INCH = 72.0


class FontWeight(StrEnum):
    """Identifies a font weight the renderer draws with."""

    REGULAR = "regular"
    BOLD = "bold"
    ITALIC = "italic"


# Candidates are probed in order and the first path that exists wins, so one mapping covers Windows, Linux, and
# macOS without the caller having to know which platform it is on.
DEFAULT_FONT_CANDIDATES = {
    FontWeight.REGULAR: (
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ),
    FontWeight.BOLD: (
        "C:/Windows/Fonts/arialbd.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
    ),
    FontWeight.ITALIC: (
        "C:/Windows/Fonts/ariali.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf",
        "/Library/Fonts/Arial Italic.ttf",
    ),
}


@dataclass
class FigureMetrics:
    """
    Converts millimetres and points into canvas pixels for one figure.

    Declaring every size in physical units is what keeps a figure compliant with a publisher's artwork
    limits: a font asked for at 8 pt is 8 pt on the printed page whatever the render resolution, so a
    low-resolution review render and a high-resolution submission render cannot drift apart. Requests
    below `minimum_point_size` are recorded in `undersized_points` rather than silently honoured, which
    lets a caller fail a render that would breach the limit.
    """

    width_mm: float
    height_mm: float
    dpi: int
    supersample: int = 1
    minimum_point_size: float = 7.0
    font_candidates: dict[FontWeight, tuple[str, ...]] = field(default_factory=lambda: DEFAULT_FONT_CANDIDATES)
    undersized_points: list[float] = field(default_factory=list, init=False, repr=False)

    # Loading a TrueType face is comparatively slow and a figure asks for the same handful of sizes many hundreds
    # of times, so faces are memoised for the lifetime of the metrics object.
    _fonts: dict[tuple[float, FontWeight], ImageFont.FreeTypeFont] = field(
        default_factory=dict, init=False, repr=False
    )

    @property
    def width_px(self) -> int:
        """Returns the output width in pixels, before supersampling."""

        return round(self.width_mm / _MILLIMETRES_PER_INCH * self.dpi)

    @property
    def height_px(self) -> int:
        """Returns the output height in pixels, before supersampling."""

        return round(self.height_mm / _MILLIMETRES_PER_INCH * self.dpi)

    @property
    def canvas_width(self) -> int:
        """Returns the width of the supersampled drawing canvas."""

        return self.width_px * self.supersample

    @property
    def canvas_height(self) -> int:
        """Returns the height of the supersampled drawing canvas."""

        return self.height_px * self.supersample

    def mm(self, millimetres: float) -> float:
        """Converts millimetres to canvas pixels."""

        return millimetres / _MILLIMETRES_PER_INCH * self.dpi * self.supersample

    def pt(self, points: float) -> int:
        """Converts points to canvas pixels, never returning a sub-pixel stroke."""

        # A hairline that rounds to zero would vanish from the render entirely, so the floor is one pixel. At print
        # resolution one pixel is far finer than any publisher's minimum rule width, so nothing is over-inked.
        return max(1, round(points / _POINTS_PER_INCH * self.dpi * self.supersample))

    def font(self, points: float, weight: FontWeight = FontWeight.REGULAR) -> ImageFont.FreeTypeFont:
        """
        Returns a font at the requested point size, caching it for reuse.

        Args:
            points:  Printed size in points, recorded as a breach when below `minimum_point_size`.
            weight:  Weight to load.
        """

        # The breach is recorded rather than raised so one render reports every offending size at once, instead of
        # failing on the first and hiding the rest.
        if points < self.minimum_point_size:
            self.undersized_points.append(points)

        # Rounding the key absorbs floating-point drift in computed sizes, which would otherwise defeat the cache.
        cache_key = (round(points, 2), weight)

        if cache_key not in self._fonts:
            self._fonts[cache_key] = self._load_font(points, weight)

        return self._fonts[cache_key]

    def _load_font(self, points: float, weight: FontWeight) -> ImageFont.FreeTypeFont:
        """
        Returns the first candidate font that exists for a weight.

        A platform with none of the candidates degrades to the Pillow bitmap font, which stays legible but
        is not publication quality, so the miss is reported rather than passed over.
        """

        for candidate in self.font_candidates[weight]:
            if Path(candidate).exists():
                return ImageFont.truetype(candidate, self.pt(points))

        print(f"  warning: no {weight} font found; falling back to the Pillow default")

        return ImageFont.load_default()
