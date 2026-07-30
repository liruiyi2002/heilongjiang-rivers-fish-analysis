"""
Minimal GeoJSON reader for committed basemap extracts.

Author:     Pouria Hadjibagheri
Email:      pouria.hadjibagheri@partners-cap.com
Copyright:  (c) 2026 Pouria Hadjibagheri
License:    PolyForm Noncommercial 1.0.0 (attribution required, noncommercial use only)
"""

# Python imports
# ============================
from __future__ import annotations

import json
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

# Third party imports
# ============================
# None

# Internal imports
# ============================
# None


__all__ = [
    "GeoFeature",
    "Position",
    "Ring",
    "line_strings",
    "load_feature_collection",
    "polygon_rings",
]

type Position = tuple[float, float]
type Ring = list[Position]

# Natural Earth spells its name field in upper case while OpenStreetMap uses lower case, so both are accepted and
# the caller never has to know which source a feature came from.
_NAME_KEYS = ("name", "NAME")


@dataclass(frozen=True)
class GeoFeature:
    """Represents one GeoJSON feature and its properties."""

    properties: dict[str, object]
    geometry: dict[str, object]

    @property
    def name(self) -> str:
        """Returns the feature's name, or an empty string when it is unnamed."""

        for key in _NAME_KEYS:
            value = self.properties.get(key)

            if value:
                return str(value)

        return str()

    def population(self) -> int:
        """
        Returns the feature's population, treating a missing or unparsable value as zero.

        OpenStreetMap population tags are free text and appear with thousands separators, spaces, and
        occasional notes, so the digits are extracted rather than parsed strictly. A settlement with an
        unusable tag then sorts last instead of failing the render.
        """

        digits = str().join(filter(str.isdigit, str(self.properties.get("population") or str())))

        return int(digits or 0)


def load_feature_collection(path: Path) -> tuple[GeoFeature, ...]:
    """
    Loads one GeoJSON feature collection.

    A missing file degrades to an empty collection with a warning rather than raising, so a partial
    checkout still renders the layers it does have.
    """

    if not path.exists():
        print(f"  warning: missing basemap extract {path.name}")

        return tuple()

    with path.open(encoding="utf-8") as handle:
        collection = json.load(handle)

    # A feature without properties is legal GeoJSON, so the mapping is defaulted rather than assumed. Geometry is
    # required, and a collection missing it is malformed and should fail loudly here.
    features = tuple(GeoFeature(properties=feature.get("properties") or dict(), geometry=feature["geometry"])
                     for feature in collection.get("features") or list())

    return features


def polygon_rings(geometry: dict[str, object]) -> Iterator[Ring]:
    """
    Yields every coordinate ring of a Polygon or MultiPolygon geometry.

    Flattening both shapes to a single stream of rings lets a caller draw either without branching. Inner
    rings are yielded alongside outer ones, so a renderer that cannot punch holes must paint enclosed
    features over the top instead.
    """

    match geometry.get("type"):
        case "Polygon":
            yield from geometry["coordinates"]
        case "MultiPolygon":
            for polygon in geometry["coordinates"]:
                yield from polygon


def line_strings(geometry: dict[str, object]) -> Iterator[Ring]:
    """Yields every coordinate line of a LineString or MultiLineString geometry."""

    match geometry.get("type"):
        case "LineString":
            yield geometry["coordinates"]
        case "MultiLineString":
            yield from geometry["coordinates"]
