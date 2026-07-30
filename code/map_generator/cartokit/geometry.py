"""
Map projection, pixel viewport, and ground-distance helpers.

Author:     Pouria Hadjibagheri
Email:      pouria.hadjibagheri@partners-cap.com
Copyright:  (c) 2026 Pouria Hadjibagheri
License:    PolyForm Noncommercial 1.0.0 (attribution required, noncommercial use only)
"""

# Python imports
# ============================
from __future__ import annotations

import math
from dataclasses import dataclass

# Third party imports
# ============================
# None

# Internal imports
# ============================
# None


__all__ = [
    "AlbersEqualArea",
    "Coordinate",
    "EARTH_RADIUS_KM",
    "Viewport",
    "ground_distance_km",
]

EARTH_RADIUS_KM = 6371.0

# A cone constant of zero means the two standard parallels are mirror images, which collapses the conic into a
# cylindrical projection and divides by zero. Clamping to a tiny value keeps the arithmetic finite for that
# degenerate input rather than raising from inside the projection.
_MINIMUM_CONE = 1e-12

# Points sampled along each edge of the extent when fitting a viewport. Forty is far more than the four corners a
# rectangular projection would need, and cheap enough to run once per panel.
_EDGE_SAMPLES = 40

# Probe length used to measure the local scale. Small enough that the local scale factor still applies, large
# enough that floating-point noise in the projected difference stays negligible.
_PROBE_DEGREES = 0.1
_KM_PER_DEGREE = 111.0


@dataclass(frozen=True)
class Coordinate:
    """Represents a longitude and latitude pair in decimal degrees."""

    longitude: float
    latitude: float


class AlbersEqualArea:
    """
    Projects degrees onto a spherical Albers equal-area conic, returning kilometres.

    An equal-area projection keeps quoted buffer or catchment areas comparable with what the map shows,
    which a Mercator-style projection would distort badly at high latitudes.
    """

    def __init__(self, central_lon: float, central_lat: float, parallel_1: float, parallel_2: float) -> None:
        """
        Initializes the projection from its centre and its two standard parallels.

        Args:
            central_lon:  Longitude of the projection centre.
            central_lat:  Latitude of the projection centre.
            parallel_1:   Southern standard parallel.
            parallel_2:   Northern standard parallel.
        """

        self._central_lon = math.radians(central_lon)

        # The cone and area constants depend only on the standard parallels, and the origin radius only on the
        # centre, so all three are derived once here instead of per projected point.
        first, second = math.radians(parallel_1), math.radians(parallel_2)
        self._cone = 0.5 * (math.sin(first) + math.sin(second)) or _MINIMUM_CONE
        self._constant = math.cos(first) ** 2 + 2.0 * self._cone * math.sin(first)
        self._rho_origin = self._rho(math.radians(central_lat))

    def __call__(self, longitude: float, latitude: float) -> tuple[float, float]:
        """Returns the easting and northing, in kilometres, of one coordinate."""

        rho = self._rho(math.radians(latitude))
        theta = self._cone * (math.radians(longitude) - self._central_lon)

        # Northings are measured down from the origin radius, so a point north of the centre yields a positive
        # value and callers can treat the result as a conventional right-handed plane.
        return rho * math.sin(theta), self._rho_origin - rho * math.cos(theta)

    def _rho(self, latitude_rad: float) -> float:
        """Returns the polar radius of one parallel."""

        # Past the projection's usable latitude range the radicand turns negative and `sqrt` would raise. Clamping
        # collapses those points onto the pole, which is the conventional behaviour and stops one stray
        # out-of-range vertex from failing an entire render.
        radius = max(self._constant - 2.0 * self._cone * math.sin(latitude_rad), _MINIMUM_CONE)

        return EARTH_RADIUS_KM / self._cone * math.sqrt(radius)


class Viewport:
    """
    Fits a geographic extent to a pixel panel, preserving the projected aspect ratio.

    The extent is sampled along its edges rather than at its corners because a conic projection bows the
    parallels, so the corners alone would clip the widest part of the frame.
    """

    def __init__(self, projection: AlbersEqualArea, extent: tuple[float, float, float, float], width: float,
                 height: float) -> None:
        """
        Initializes the viewport for one panel.

        Args:
            projection:  Projection the viewport draws through.
            extent:      Geographic extent as longitude and latitude minima followed by maxima.
            width:       Panel width in canvas pixels.
            height:      Panel height in canvas pixels.
        """

        self._projection = projection
        self._width = width
        self._height = height

        # Projecting the sampled perimeter and transposing it with `zip` yields the two coordinate axes directly,
        # so the bounding box falls out of two passes rather than a hand-rolled running minimum and maximum.
        eastings, northings = zip(*map(lambda point: projection(*point), _edge_points(extent)))
        span_east = (max(eastings) - min(eastings)) or 1.0
        span_north = (max(northings) - min(northings)) or 1.0

        # A single scale factor is applied to both axes so the projection is never stretched. Taking the smaller of
        # the two fits the whole extent inside the panel and letterboxes the surplus instead of cropping data.
        self._scale = min(width / span_east, height / span_north)
        self._centre_east = 0.5 * (min(eastings) + max(eastings))
        self._centre_north = 0.5 * (min(northings) + max(northings))

    def __call__(self, longitude: float, latitude: float) -> tuple[float, float]:
        """Returns the canvas pixel a coordinate falls on."""

        easting, northing = self._projection(longitude, latitude)

        # Pixel rows increase downwards while northings increase upwards, hence the subtraction on the second axis.
        return (self._width * 0.5 + (easting - self._centre_east) * self._scale,
                self._height * 0.5 - (northing - self._centre_north) * self._scale)

    def km_per_pixel(self, longitude: float, latitude: float) -> float:
        """
        Returns the ground distance one pixel represents near a coordinate.

        Measured from a short probe rather than derived from the scale factor, so a scale bar built on it
        stays honest wherever the panel is sampled.
        """

        origin_east, origin_north = self._projection(longitude, latitude)
        probe_east, probe_north = self._projection(longitude + _PROBE_DEGREES, latitude)

        origin_pixel = self(longitude, latitude)
        probe_pixel = self(longitude + _PROBE_DEGREES, latitude)
        pixel_span = math.hypot(probe_pixel[0] - origin_pixel[0], probe_pixel[1] - origin_pixel[1])

        # A zero span only arises from a degenerate extent. Returning unity keeps a dependent caller such as a
        # scale bar drawable instead of dividing by zero.
        if not pixel_span:
            return 1.0

        return math.hypot(probe_east - origin_east, probe_north - origin_north) / pixel_span


def ground_distance_km(first: Coordinate, second: Coordinate) -> float:
    """
    Returns the small-angle ground distance between two coordinates.

    Accurate enough for proximity tests over a few tens of kilometres, and far cheaper than a full
    geodesic solution.
    """

    # Degrees of longitude shorten towards the poles, so the east-west leg is scaled by the cosine of the
    # latitude. Degrees of latitude keep a near-constant length and need no correction.
    east_west = (first.longitude - second.longitude) * _KM_PER_DEGREE * math.cos(math.radians(second.latitude))
    north_south = (first.latitude - second.latitude) * _KM_PER_DEGREE

    return math.hypot(east_west, north_south)


def _edge_points(extent: tuple[float, float, float, float]) -> list[tuple[float, float]]:
    """Returns points sampled along the four edges of a geographic extent."""

    lon_min, lat_min, lon_max, lat_max = extent
    points = list()

    # Each step contributes one point to all four edges at once, so a single pass walks the whole perimeter.
    for step in range(_EDGE_SAMPLES + 1):
        fraction = step / _EDGE_SAMPLES
        along_lon = lon_min + fraction * (lon_max - lon_min)
        along_lat = lat_min + fraction * (lat_max - lat_min)

        points.extend([(along_lon, lat_min), (along_lon, lat_max), (lon_min, along_lat), (lon_max, along_lat)])

    return points
