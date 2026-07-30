"""
Collision-avoiding label placement and the post-render audit.

Author:     Pouria Hadjibagheri
Email:      p.bagheri@ucl.ac.uk
Copyright:  (c) 2026 Pouria Hadjibagheri
License:    PolyForm Noncommercial 1.0.0 (attribution required, noncommercial use only)
"""

# Python imports
# ============================
from __future__ import annotations

from dataclasses import dataclass, field
from itertools import combinations

# Third party imports
# ============================
from PIL import ImageDraw, ImageFont

# Internal imports
# ============================
# None


__all__ = [
    "LabelAudit",
    "LabelOffset",
    "LabelSet",
    "Rectangle",
    "report_audit",
]


# Labels are held this far inside the panel edge. Text flush against a trimmed edge reads as a printing error even
# when it is technically inside the frame.
_PANEL_INSET_PX = 3

# Audit output is truncated so one badly crowded panel cannot bury the summary in thousands of lines.
_MAX_REPORTED_CLASHES = 8
_MAX_REPORTED_DROPS = 8

# A leader stops just short of the label so the line does not collide with the glyphs it points at.
_LEADER_LENGTH_FRACTION = 0.82


@dataclass(frozen=True)
class Rectangle:
    """Represents an axis-aligned box in canvas pixels."""

    left: float
    top: float
    right: float
    bottom: float

    def overlaps(self, other: Rectangle) -> bool:
        """Returns `True` when the two boxes share any area."""

        # Separation on any single axis is enough to prove no overlap, which is cheaper than computing an
        # intersection. Touching edges count as clear, so boxes may sit flush against each other.
        return not (self.right <= other.left or self.left >= other.right
                    or self.bottom <= other.top or self.top >= other.bottom)

    def padded(self, padding: float) -> Rectangle:
        """Returns the same box grown by `padding` on every side."""

        return Rectangle(self.left - padding, self.top - padding, self.right + padding, self.bottom + padding)


@dataclass(frozen=True)
class LabelOffset:
    """Represents one candidate position for a label, relative to the feature it annotates."""

    dx: float
    dy: float
    anchor: str


@dataclass(frozen=True)
class LabelAudit:
    """Summarizes what one panel's label pass produced."""

    panel: str
    placed: int
    clashes: tuple[tuple[str, str], ...]
    dropped: tuple[tuple[str, str], ...]

    @property
    def is_clean(self) -> bool:
        """Returns `True` when nothing overlaps; dropped decoration alone does not fail a panel."""

        # A dropped graticule or lake label is the mechanism working as intended: the label yielded instead of
        # overprinting. Only a genuine overlap means the placement rules were bypassed.
        return not self.clashes


@dataclass
class LabelSet:
    """
    Tracks the boxes a panel has already committed to, so nothing is ever overprinted.

    Every piece of text is placed through this class. Reserving the footprints of the data marks before
    any decoration is drawn is what makes the ordering safe: decoration yields to data rather than the
    reverse, and a label that cannot be placed is dropped and reported instead of overlapping.
    """

    width: float
    height: float
    padding: float
    _boxes: list[tuple[Rectangle, str]] = field(default_factory=list, init=False, repr=False)
    _dropped: list[tuple[str, str]] = field(default_factory=list, init=False, repr=False)

    def reserve(self, box: Rectangle, tag: str = "furniture") -> None:
        """Claims a box so later labels avoid it."""

        self._boxes.append((box, tag))

    def fits(self, box: Rectangle) -> bool:
        """Returns `True` when a box lies inside the panel and clears everything already reserved."""

        inside_panel = (box.left >= _PANEL_INSET_PX and box.top >= _PANEL_INSET_PX
                        and box.right <= self.width - _PANEL_INSET_PX
                        and box.bottom <= self.height - _PANEL_INSET_PX)

        # The cheap bounds test runs first so an off-panel candidate never pays for the reservation scan.
        if not inside_panel:
            return False

        return not any(box.overlaps(reserved) for reserved, _ in self._boxes)

    def text_box(self, draw: ImageDraw.ImageDraw, position: tuple[float, float], text: str,
                 font: ImageFont.FreeTypeFont, anchor: str) -> Rectangle:
        """
        Returns the padded box a piece of text would occupy without drawing it.

        Exposed so a caller can measure a label, combine it with the symbol it belongs to, and reserve the
        pair as one box.
        """

        left, top, right, bottom = draw.textbbox(position, text, font=font, anchor=anchor)

        return Rectangle(left, top, right, bottom).padded(self.padding)

    def text(self, draw: ImageDraw.ImageDraw, position: tuple[float, float], text: str,
             font: ImageFont.FreeTypeFont, fill: str, anchor: str = "lm", halo: str | None = None,
             halo_width: int = 0, tag: str = "label", required: bool = False) -> Rectangle | None:
        """
        Draws text at one fixed position, skipping it on collision unless it is required.

        Args:
            draw:        Target drawing context.
            position:    Anchor point in canvas pixels.
            text:        Text to draw.
            font:        Font to draw with.
            fill:        Text colour.
            anchor:      Pillow anchor code.
            halo:        Optional halo colour drawn behind the glyphs.
            halo_width:  Halo stroke width in pixels.
            tag:         Identifier reported by the audit.
            required:    Draws the text even where it collides, for content that must appear.

        Returns:
            The committed box, or `None` when the label was dropped.
        """

        box = self.text_box(draw, position, text, font, anchor)

        if not required and not self.fits(box):
            self._dropped.append((tag, text))

            return None

        draw.text(position, text, font=font, fill=fill, anchor=anchor, stroke_width=halo_width, stroke_fill=halo)

        # A required label is reserved as well, so later optional labels still keep clear of it.
        self.reserve(box, tag)

        return box

    def anchored(self, draw: ImageDraw.ImageDraw, x: float, y: float, text: str, font: ImageFont.FreeTypeFont,
                 fill: str, candidates: tuple[LabelOffset, ...], halo: str | None = None, halo_width: int = 0,
                 tag: str = "label", leader_from: int = 8, leader_fill: str | None = None,
                 leader_width: int = 1) -> Rectangle | None:
        """
        Draws text near a feature, taking the first candidate offset that fits.

        Candidates are searched in order, so they should run from the tightest placement to the loosest.
        Once the search passes `leader_from` the label sits far enough away to be ambiguous, so a leader
        line is drawn back to the feature.

        Args:
            draw:          Target drawing context.
            x:             Feature position on the horizontal axis.
            y:             Feature position on the vertical axis.
            text:          Text to draw.
            font:          Font to draw with.
            fill:          Text colour.
            candidates:    Offsets to try, ordered from tightest to loosest.
            halo:          Optional halo colour drawn behind the glyphs.
            halo_width:    Halo stroke width in pixels.
            tag:           Identifier reported by the audit.
            leader_from:   Candidate index from which a leader line is drawn.
            leader_fill:   Leader line colour; omitting it suppresses the leader.
            leader_width:  Leader line width in pixels.

        Returns:
            The committed box, or `None` when no candidate fitted.
        """

        for index, offset in enumerate(candidates):
            position = (x + offset.dx, y + offset.dy)
            box = self.text_box(draw, position, text, font, offset.anchor)

            if not self.fits(box):
                continue

            # The leader is drawn before the text so the halo of the glyphs covers where the line arrives.
            if index >= leader_from and leader_fill:
                draw.line([(x, y), (x + offset.dx * _LEADER_LENGTH_FRACTION, y + offset.dy * _LEADER_LENGTH_FRACTION)],
                          fill=leader_fill, width=leader_width)

            draw.text(position, text, font=font, fill=fill, anchor=offset.anchor, stroke_width=halo_width,
                      stroke_fill=halo)
            self.reserve(box, tag)

            return box

        self._dropped.append((tag, text))

        return None

    def audit(self, panel: str) -> LabelAudit:
        """
        Re-checks every committed box against every other one and summarizes the panel.

        The placement rules should already guarantee no overlap, so this is a second, independent pass over
        the finished panel. It catches a caller that reserved a box in the wrong order, or that drew text
        directly rather than through this class.
        """

        clashes = tuple((first_tag, second_tag)
                        for (first, first_tag), (second, second_tag) in combinations(self._boxes, 2)
                        if first.overlaps(second))
        audit = LabelAudit(panel=panel, placed=len(self._boxes), clashes=clashes, dropped=tuple(self._dropped))

        return audit


def report_audit(audits: tuple[LabelAudit, ...], undersized_points: list[float], minimum_point_size: float) -> bool:
    """
    Prints the label and typography audit for a figure.

    Args:
        audits:              One audit per panel.
        undersized_points:   Point sizes requested below the minimum, as collected by `FigureMetrics`.
        minimum_point_size:  Smallest point size the target publisher accepts.

    Returns:
        `True` when no panel has an overlap and no font breached the minimum.
    """

    clean = all(audit.is_clean for audit in audits) and not undersized_points

    for audit in audits:
        print(f"  panel {audit.panel}: {audit.placed} labels placed")

        if audit.clashes:
            print(f"    OVERLAPS: {list(audit.clashes[:_MAX_REPORTED_CLASHES])}")

        # Drops are reported but do not fail the figure, so a reviewer can still see which decoration gave way.
        if audit.dropped:
            dropped_text = [text for _, text in audit.dropped[:_MAX_REPORTED_DROPS]]
            print(f"    dropped {len(audit.dropped)} low-priority label(s): {dropped_text}")

    if undersized_points:
        breaches = sorted(set(map(lambda points: round(points, 2), undersized_points)))
        print(f"    FONTS BELOW {minimum_point_size} pt: {breaches}")
    else:
        print(f"  all fonts >= {minimum_point_size} pt")

    print(f"  RESULT: {'PASS' if clean else 'NEEDS ATTENTION'}")

    return clean
