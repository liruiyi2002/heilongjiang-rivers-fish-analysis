"""
Drawing primitives and map furniture.

Author:     Pouria Hadjibagheri
Email:      p.bagheri@ucl.ac.uk
Copyright:  (c) 2026 Pouria Hadjibagheri
License:    PolyForm Noncommercial 1.0.0 (attribution required, noncommercial use only)
"""

# Python imports
# ============================
from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass
from enum import StrEnum

# Third party imports
# ============================
from PIL import ImageDraw

# Internal imports
# ============================
from .geojson import Position, Ring, polygon_rings
from .geometry import Viewport
from .labels import LabelSet, Rectangle
from .layout import FigureMetrics, FontWeight


__all__ = [
    "LegendEntry",
    "Symbol",
    "draw_dashed_polyline",
    "draw_graticule",
    "draw_horizontal_legend",
    "draw_marker",
    "draw_north_arrow",
    "draw_polygon_rings",
    "draw_polyline",
    "draw_scale_bar",
]


# A ring needs three points to enclose an area and a line needs two to have direction; anything shorter is a
# degenerate fragment from a clipped extract and is skipped rather than drawn as a dot.
_MINIMUM_RING_POINTS = 3
_MINIMUM_LINE_POINTS = 2

# Points traced along each graticule line. A conic projection bows the parallels, so they are drawn as sampled
# polylines rather than straight segments between their endpoints.
_GRATICULE_SAMPLES = 60

_SCALE_BAR_SEGMENTS = 4
_DEFAULT_SCALE_STEPS_KM = (1, 2, 5, 10, 20, 25, 50, 75, 100, 150, 200, 250, 500)
_HOLLOW_HALF_MM = 0.62


class Symbol(StrEnum):
    """Identifies a symbol the renderer can draw for a mark or a legend row."""

    CIRCLE = "circle"
    SQUARE = "square"
    TRIANGLE = "triangle"
    DIAMOND = "diamond"
    LINE = "line"
    HOLLOW_SQUARE = "hollow_square"


@dataclass(frozen=True)
class LegendEntry:
    """Represents one legend row: a symbol, the colour it is drawn in, and its label."""

    symbol: Symbol
    colour: str | None
    label: str


def draw_polygon_rings(draw: ImageDraw.ImageDraw, viewport: Viewport, geometry: dict[str, object],
                       fill: str | None = None, outline: str | None = None, width: int = 1) -> None:
    """
    Fills and strokes every ring of a polygon geometry.

    Pillow has no notion of polygon holes, so rings are drawn independently. Enclosed features such as
    lakes therefore have to be painted over the land rather than punched out of it.
    """

    for ring in polygon_rings(geometry):
        points = [viewport(longitude, latitude) for longitude, latitude in ring]

        if len(points) < _MINIMUM_RING_POINTS:
            continue

        if fill:
            draw.polygon(points, fill=fill)

        # The outline is stroked as a closed polyline rather than through `polygon`, because Pillow's polygon
        # outline is always one pixel wide and ignores the width argument.
        if outline:
            draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def draw_polyline(draw: ImageDraw.ImageDraw, viewport: Viewport, coordinates: Ring, colour: str,
                  width: float) -> None:
    """Strokes a projected line, rounding the width up to a visible stroke."""

    points = [viewport(longitude, latitude) for longitude, latitude in coordinates]

    if len(points) < _MINIMUM_LINE_POINTS:
        return

    # Curved joints stop a thick river from showing mitre spikes where its vertices turn sharply.
    draw.line(points, fill=colour, width=max(1, round(width)), joint="curve")


def draw_dashed_polyline(draw: ImageDraw.ImageDraw, points: Sequence[Position], colour: str, width: int,
                         dash_length: float) -> None:
    """
    Strokes a dashed line.

    The dash phase carries across segment boundaries, so a bowed line keeps an even rhythm instead of
    restarting its dash at every vertex.
    """

    pen_down = True
    run = 0.0

    for (start_x, start_y), (end_x, end_y) in zip(points, points[1:]):
        segment = math.hypot(end_x - start_x, end_y - start_y)

        # Coincident vertices are common in simplified extracts and would divide by zero below.
        if not segment:
            continue

        travelled = 0.0

        # One segment may span several dashes, or only part of one, so the walk is driven by whichever runs out
        # first: the remainder of the current dash or the remainder of the segment.
        while travelled < segment:
            step = min(dash_length - run, segment - travelled)

            if pen_down:
                head = travelled / segment
                tail = (travelled + step) / segment
                draw.line([(start_x + (end_x - start_x) * head, start_y + (end_y - start_y) * head),
                           (start_x + (end_x - start_x) * tail, start_y + (end_y - start_y) * tail)],
                          fill=colour, width=max(1, width))

            travelled += step
            run += step

            # The pen only flips once a whole dash length has been consumed, which is what carries the phase into
            # the next segment.
            if run >= dash_length:
                run = 0.0
                pen_down = not pen_down


def draw_marker(draw: ImageDraw.ImageDraw, x: float, y: float, symbol: Symbol, radius: float, fill: str | None,
                ring: str, ring_width: int = 2) -> None:
    """
    Draws a data marker with a ring in the surface colour.

    The ring is what keeps neighbouring marks separable where a map crowds them, so it is applied even
    when the marks do not currently overlap.

    Raises:
        ValueError:  Raised when the symbol has no mark form, such as `Symbol.LINE`.
    """

    stroke = max(1, ring_width)

    # Shapes are sized so they read as visually equal in area rather than sharing one bounding box: a square at the
    # full radius looks heavier than a circle, and a triangle needs extra height to look the same weight.
    match symbol:
        case Symbol.CIRCLE:
            draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=fill, outline=ring, width=stroke)
        case Symbol.SQUARE:
            half = radius * 0.90
            draw.rectangle([x - half, y - half, x + half, y + half], fill=fill, outline=ring, width=stroke)
        case Symbol.HOLLOW_SQUARE:
            draw.rectangle([x - radius, y - radius, x + radius, y + radius], fill=fill, outline=ring, width=stroke)
        case Symbol.TRIANGLE:
            height = radius * 1.16
            corners = [(x, y - height), (x + height * 0.95, y + height * 0.72), (x - height * 0.95, y + height * 0.72)]
            draw.polygon(corners, fill=fill)
            draw.line(corners + [corners[0]], fill=ring, width=stroke, joint="curve")
        case Symbol.DIAMOND:
            corners = [(x, y - radius * 1.22), (x + radius * 1.12, y), (x, y + radius * 1.22),
                       (x - radius * 1.12, y)]
            draw.polygon(corners, fill=fill)
            draw.line(corners + [corners[0]], fill=ring, width=stroke, joint="curve")
        case _:
            raise ValueError(f"{symbol} has no mark form")


def draw_graticule(draw: ImageDraw.ImageDraw, metrics: FigureMetrics, viewport: Viewport, labels: LabelSet,
                   extent: tuple[float, float, float, float], step: float, colour: str, text_colour: str,
                   halo: str, points: float = 7.5, width_pt: float = 0.35,
                   dash_mm: float = 1.6) -> None:
    """
    Draws a dashed graticule and labels it on the bottom and left edges.

    Edge labels are placed through `labels`, so they are dropped rather than drawn over an inset, a
    legend, or a data mark when the frame is tight.
    """

    font = metrics.font(points)
    dash = metrics.mm(dash_mm)
    stroke = metrics.pt(width_pt)
    lon_min, lat_min, lon_max, lat_max = extent

    for meridian in _degree_ticks(lon_min, lon_max, step):
        line = [viewport(meridian, latitude) for latitude in _even_span(lat_min, lat_max)]
        draw_dashed_polyline(draw, line, colour, stroke, dash)

        # Each label is positioned from where its own line meets the frame edge, so it stays aligned with the line
        # even where the projection bows it away from vertical.
        x, _ = viewport(meridian, lat_min)
        labels.text(draw, (x, labels.height - metrics.mm(1.2)), f"{meridian:g}°E", font, text_colour,
                    anchor="ms", halo=halo, halo_width=metrics.pt(1.0), tag="graticule")

    for parallel in _degree_ticks(lat_min, lat_max, step):
        line = [viewport(longitude, parallel) for longitude in _even_span(lon_min, lon_max)]
        draw_dashed_polyline(draw, line, colour, stroke, dash)

        _, y = viewport(lon_min, parallel)
        labels.text(draw, (metrics.mm(1.2), y), f"{parallel:g}°N", font, text_colour, anchor="lm",
                    halo=halo, halo_width=metrics.pt(1.0), tag="graticule")


def draw_scale_bar(draw: ImageDraw.ImageDraw, metrics: FigureMetrics, km_per_pixel: float, left: float, top: float,
                   fill: str, alternate: str, halo: str, target_mm: float = 26.0, height_mm: float = 1.3,
                   points: float = 7.5, steps_km: Sequence[int] = _DEFAULT_SCALE_STEPS_KM) -> Rectangle:
    """
    Draws an alternating scale bar whose length is a round number of kilometres.

    Args:
        draw:           Target drawing context.
        metrics:        Metrics the bar is sized against.
        km_per_pixel:   Ground distance one pixel represents, from `Viewport.km_per_pixel`.
        left:           Left edge of the bar in canvas pixels.
        top:            Top edge of the bar in canvas pixels.
        fill:           Colour of the filled segments and of the labels.
        alternate:      Colour of the alternating segments.
        halo:           Halo colour drawn behind the labels.
        target_mm:      Preferred printed length, used to pick from `steps_km`.
        height_mm:      Printed bar height.
        points:         Label size in points.
        steps_km:       Round distances the bar may represent.

    Returns:
        The box the bar and its labels occupy, for reservation against later labels.
    """

    # The bar is sized to a round distance rather than to an exact width, because a reader can measure "50 km" off
    # the page but cannot use "47.3 km". The nearest round step to the requested width wins.
    kilometres = min(steps_km, key=lambda step: abs(step - metrics.mm(target_mm) * km_per_pixel))
    length = kilometres / km_per_pixel
    bar_height = metrics.mm(height_mm)
    segment = length / _SCALE_BAR_SEGMENTS

    for index in range(_SCALE_BAR_SEGMENTS):
        shade = fill if index % 2 == 0 else alternate
        draw.rectangle([left + index * segment, top, left + (index + 1) * segment, top + bar_height],
                       fill=shade, outline=fill, width=metrics.pt(0.4))

    font = metrics.font(points)
    label_y = top - metrics.mm(0.7)

    # Only the two ends are labelled. Intermediate ticks add ink without adding information at this size.
    for x, text in ((left, "0"), (left + length, f"{kilometres:g} km")):
        draw.text((x, label_y), text, font=font, fill=fill, anchor="ms", stroke_width=metrics.pt(1.0),
                  stroke_fill=halo)

    # The reserved box is wider than the bar itself so the end label, which overhangs to the right, is covered too.
    occupied = Rectangle(left - metrics.mm(3.0), top - metrics.mm(4.0), left + length + metrics.mm(6.0),
                         top + bar_height)

    return occupied


def draw_north_arrow(draw: ImageDraw.ImageDraw, metrics: FigureMetrics, x: float, y: float, fill: str,
                     surface: str, size_mm: float = 2.6, points: float = 8.0) -> Rectangle:
    """
    Draws a half-filled north arrow with an `N` above it.

    Returns:
        The box the arrow and its letter occupy, for reservation against later labels.
    """

    size = metrics.mm(size_mm)
    outline = [(x, y - size), (x + size * 0.52, y + size * 0.62), (x, y + size * 0.26),
               (x - size * 0.52, y + size * 0.62)]

    # The whole kite is filled with the surface colour first so the arrow stays legible over any basemap, then the
    # right half is over-painted to give the conventional half-solid form.
    draw.polygon(outline, fill=surface)
    draw.line(outline + [outline[0]], fill=fill, width=metrics.pt(0.6), joint="curve")
    draw.polygon(outline[:3], fill=fill)
    draw.text((x, y - size - metrics.mm(0.8)), "N", font=metrics.font(points, FontWeight.BOLD), fill=fill,
              anchor="ms", stroke_width=metrics.pt(1.0), stroke_fill=surface)

    occupied = Rectangle(x - size, y - size - metrics.mm(4.0), x + size, y + size)

    return occupied


def draw_horizontal_legend(draw: ImageDraw.ImageDraw, metrics: FigureMetrics, x: float, y: float,
                           entries: Sequence[LegendEntry], max_width: float, text_colour: str, title_colour: str,
                           surface: str, outline: str, title: str | None = None, points: float = 7.5,
                           title_points: float = 8.5) -> float:
    """
    Lays a legend out in rows, wrapping at `max_width`.

    A wrapping horizontal legend suits a panel with width to spare but little height, where a boxed
    vertical legend would either overflow or cover the map.

    Returns:
        The height the legend consumed, in canvas pixels.
    """

    font = metrics.font(points)
    cursor_y = y

    if title:
        draw.text((x, cursor_y), title, font=metrics.font(title_points, FontWeight.BOLD), fill=title_colour,
                  anchor="la")
        cursor_y += metrics.mm(4.4)

    swatch = metrics.mm(2.6)
    row_height = metrics.mm(4.2)
    cursor_x = x

    for entry in entries:
        entry_width = swatch + metrics.mm(1.5) + draw.textlength(entry.label, font=font) + metrics.mm(4.5)

        # Each entry is measured before it is placed, so a row wraps on the entry that would overflow rather than
        # after it. The first entry on a row is always drawn, even if it alone exceeds the width.
        if cursor_x > x and cursor_x + entry_width > x + max_width:
            cursor_x = x
            cursor_y += row_height

        middle = cursor_y + metrics.mm(1.5)
        _draw_legend_symbol(draw, metrics, entry, cursor_x, middle, swatch, surface, outline)
        draw.text((cursor_x + swatch + metrics.mm(1.5), middle), entry.label, font=font, fill=text_colour,
                  anchor="lm")
        cursor_x += entry_width

    return cursor_y + row_height - y


def _draw_legend_symbol(draw: ImageDraw.ImageDraw, metrics: FigureMetrics, entry: LegendEntry, x: float, y: float,
                        swatch: float, surface: str, outline: str) -> None:
    """Draws one legend swatch on the given baseline."""

    match entry.symbol:
        case Symbol.LINE:
            draw.line([(x, y), (x + swatch, y)], fill=entry.colour, width=metrics.pt(1.4))
        case Symbol.HOLLOW_SQUARE:
            # A hollow symbol carries no fill colour of its own, so it borrows the surface and the outline ink.
            draw_marker(draw, x + swatch * 0.5, y, Symbol.HOLLOW_SQUARE, metrics.mm(_HOLLOW_HALF_MM), surface,
                        ring=outline, ring_width=metrics.pt(0.6))
        case _:
            draw_marker(draw, x + swatch * 0.5, y, entry.symbol, metrics.mm(0.78), entry.colour, ring=surface,
                        ring_width=metrics.pt(0.6))


def _degree_ticks(start: float, end: float, step: float) -> list[float]:
    """Returns the whole-step graticule positions inside a span."""

    # Rounding up to the first whole step keeps the graticule on round degrees rather than on the extent's own
    # arbitrary bounds, which is what a reader expects to measure against.
    first = math.ceil(start / step) * step
    count = int((end - first) / step) + 1

    return [first + index * step for index in range(max(0, count))]


def _even_span(start: float, end: float, samples: int = _GRATICULE_SAMPLES) -> list[float]:
    """Returns evenly spaced values across a span, used to trace a bowed graticule line."""

    return [start + (end - start) * index / samples for index in range(samples + 1)]
