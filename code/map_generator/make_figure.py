"""
Renders Figure 1 of the Ussuri River eDNA manuscript.

Panel (a) is the study reach with the 13 eDNA sampling sites; panel (b) places each site in the river
network by its distance to the Ussuri-Amur confluence. Site records come from `data/site_metadata.csv`
and `data/site_environment.csv`; the basemap comes from the clipped extracts in `data/geo`, whose
provenance and licences are recorded in `data/geo/SOURCES.md`.

Sizes are declared in physical units through `cartokit`, so the output meets the printed artwork limits
by construction, and every label is placed through a collision registry that is audited after
rendering.

How the figure is assembled
---------------------------
1.  `load_sampling_sites` reads the 13 sites once, joining the two study tables into one record per site.
2.  `StudyAreaPanel` renders panel (a) into an image of its own. Layers go down back to front: land, then
    hydrography, then the furniture (locator, scale bar, north arrow), and finally the sites. Before any
    decoration is placed, the marker footprints are reserved, so a graticule or town label always yields
    to a data mark rather than the other way round.
3.  `render_figure` pastes that panel onto the full canvas, reserves its footprint in a second registry,
    and hands the remaining width to `draw_network_panel` for panel (b).
4.  The canvas is drawn at `supersample` times the output size and downsampled once at the end, which is
    what smooths the primitives; Pillow itself does not antialias.
5.  `report_audit` re-checks both registries and the requested font sizes, and `main` turns the verdict
    into an exit code so a broken figure fails a build rather than shipping quietly.

绘制稿件图 1
-----------
面板 (a) 为研究河段及 13 个 eDNA 采样点；面板 (b) 按各点距乌苏里江—阿穆尔河汇口的距离展示其在河网中的
位置。采样点记录来自 `data/site_metadata.csv` 与 `data/site_environment.csv`；底图来自 `data/geo` 中的
裁剪子集，其来源与许可记录于 `data/geo/SOURCES.md`。

尺寸通过 `cartokit` 以物理单位声明，因此输出天然符合印刷插图规范；每条标注均经冲突登记表放置，并在渲染
后接受审计。

成图流程
--------
1.  `load_sampling_sites` 一次性读入 13 个采样点，将两张研究数据表合并为每点一条记录。
2.  `StudyAreaPanel` 将面板 (a) 渲染到独立图像中。图层自后向前依次为：陆地、水系、图面要素（定位小图、
    比例尺、指北针），最后是采样点。在绘制任何装饰性内容之前先登记标记的占位框，因此经纬网或城镇标注
    总是让位于数据标记，而非相反。
3.  `render_figure` 将该面板贴入整幅画布，在第二个登记表中占位，并把剩余宽度交给 `draw_network_panel`
    绘制面板 (b)。
4.  画布以输出尺寸的 `supersample` 倍绘制，最后一次性缩减取样，以此实现抗锯齿；Pillow 自身不做抗锯齿。
5.  `report_audit` 复核两个登记表与所请求的字号，`main` 将结论转为退出码，使有缺陷的图在构建时报错，
    而不是悄然发布。
"""

# Python imports
# ============================
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path

# Third party imports
# ============================
from PIL import Image, ImageDraw

# Internal imports
# ============================
from cartokit import drawing, geojson, geometry, labels, layout


# Paths
# -----
_SCRIPT_DIR = Path(__file__).resolve().parent
_REPOSITORY_DIR = _SCRIPT_DIR.parents[1]

DATA_DIR = _REPOSITORY_DIR / "data"
GEO_DIR = DATA_DIR / "geo"
OUTPUT_DIR = _REPOSITORY_DIR / "outputs"

_SITE_METADATA_FILE = DATA_DIR / "site_metadata.csv"
_SITE_ENVIRONMENT_FILE = DATA_DIR / "site_environment.csv"


# Artwork limits
# --------------
# Common publisher limits: full-width figures are 190 mm across, printed lettering must be at least 7 pt, and
# combination artwork wants 500 dpi or better, with 300 dpi the usual floor for a raster submission. Some
# publishers instead quote a minimum label height near 2 mm, which is roughly 8 pt in a humanist sans, so body
# labels here stay at or above 7.5 pt and satisfy both forms of the rule at once.

_COLUMN_WIDTH_MM = 190.0
_FIGURE_HEIGHT_MM = 150.0
_MINIMUM_POINT_SIZE = 7.0
_PRINT_DPI = 500
_SUBMISSION_PNG_DPI = 300
_REVIEW_DPI = 150

# Supersampling smooths Pillow's unantialiased primitives. The print renders need less of it because the extra
# pixels are invisible at 300 dpi and above but cost a great deal of memory.
_SUPERSAMPLE_REVIEW = 3
_SUPERSAMPLE_PRINT = 2


# Map geometry
# ------------
_MAP_EXTENT = (132.95, 45.28, 135.10, 48.52)
_LOCATOR_EXTENT = (99.0, 27.0, 143.0, 55.5)
_MAP_PROJECTION = (134.0, 47.0, 45.6, 48.4)
_LOCATOR_PROJECTION = (115.0, 42.0, 30.0, 54.0)
_GRATICULE_STEP_DEG = 1.0
_SCALE_BAR_ANCHOR = (134.0, 47.0)

# The upper and lower main stem meet between W02, 392 km from the confluence, and W03, 258 km from it. The map
# splits the centreline on latitude while the network panel splits it on distance, so both constants describe the
# same place on the river.
_SECTION_SPLIT_LAT = 46.39
_MAIN_STEM_SPLIT_KM = 325.0

# An OpenStreetMap channel closer than this to a tributary site is taken to be the sampled channel and is drawn in
# the tributary colour rather than as background hydrography.
_SAMPLED_TRIBUTARY_RADIUS_KM = 4.0

# A town this close to a sampling site is the same settlement the site is named after, so drawing both would
# double-symbolise one place.
_TOWN_DEDUPE_KM = 6.0

_STUDY_RIVER = "Ussuri"
_MAJOR_RIVERS = frozenset({"Amur", "Songhua"})
_SAMPLED_TRIBUTARY_RIVERS = frozenset({"Muling", "Song’acha", "Song'acha"})
_CHINA = "China"


# Palette
# -------
# The three section hues are the leading slots of a colourblind-validated categorical order. Marker shape repeats
# the same distinction, so section identity never rests on colour alone.

class RiverSection(StrEnum):
    """Identifies the three reaches the sampling design distinguishes."""

    UPSTREAM = "Upstream"
    DOWNSTREAM = "Downstream"
    TRIBUTARY = "Tributary"


_SECTION_COLOUR = {
    RiverSection.UPSTREAM: "#2a78d6",
    RiverSection.DOWNSTREAM: "#eb6834",
    RiverSection.TRIBUTARY: "#1baf7a",
}
_SECTION_SHAPE = {
    RiverSection.UPSTREAM: drawing.Symbol.CIRCLE,
    RiverSection.DOWNSTREAM: drawing.Symbol.SQUARE,
    RiverSection.TRIBUTARY: drawing.Symbol.TRIANGLE,
}
_SECTION_LABEL = {
    RiverSection.UPSTREAM: "Upper main stem",
    RiverSection.DOWNSTREAM: "Lower main stem",
    RiverSection.TRIBUTARY: "Tributary",
}
_INK = {
    "surface": "#fcfcfb",
    "white": "#ffffff",
    "primary": "#0b0b0b",
    "secondary": "#52514e",
    "muted": "#898781",
    "rule": "#c3c2b7",
    "graticule": "#e1e0d9",
    "hydrography": "#4d7fa6",
}
_TERRAIN = {
    "land_china": "#fbfaf6",
    "land_other": "#f0eee7",
    "land_edge": "#cfcabb",
    "province_edge": "#e0dbcd",
    "border": "#8d8677",
    "water_fill": "#cfe3f2",
    "water_edge": "#a9cbe6",
    "river_minor": "#c8dfee",
    "river_major": "#9cc4e0",
    "locator_sea": "#e7f0f8",
    "locator_land_edge": "#d8d3c6",
    "locator_mark": "#d03b3b",
}

_CONTEXT_LABELS = (
    (geometry.Coordinate(133.55, 47.72), "CHINA"),
    (geometry.Coordinate(134.80, 46.30), "RUSSIA"),
)
_HYDROGRAPHY_LABELS = (
    (geometry.Coordinate(134.22, 48.34), "Amur R."),
    (geometry.Coordinate(133.02, 45.62), "L. Khanka"),
)

_CREDIT = "Natural Earth; © OpenStreetMap contributors (ODbL)."
_SITE_RADIUS_MM = 0.95
_SITE_LABEL_OFFSET_MM = 1.9
_LEADER_CANDIDATE_INDEX = 8
_NETWORK_AXIS_KM = (505.0, 20.0)
_NETWORK_AXIS_TICKS_KM = (500, 400, 300, 200, 100, 42)


@dataclass(frozen=True)
class SamplingSite:
    """Represents one eDNA sampling site and the network attributes the figure encodes."""

    code: str
    name: str
    section: RiverSection
    coordinate: geometry.Coordinate
    strahler_order: int
    distance_to_mouth_km: float

    @property
    def short_name(self) -> str:
        """Returns the site name trimmed to fit the network panel's label column."""

        return self.name.replace(" River site", " R.").replace("Bawuba (858) Farm", "Bawuba Farm")


def load_sampling_sites() -> tuple[SamplingSite, ...]:
    """
    Loads the sampling sites, ordered by site code.

    Site metadata holds one row per site-season, so those rows collapse to one record per site; the
    network attributes come from the environment table, which is already one row per site.
    """

    sections = dict()
    names = dict()
    coordinates = dict()

    # Each site appears once per season with identical location and section, so the first row wins and the rest are
    # ignored. `setdefault` expresses that without a membership test on every row.
    with _SITE_METADATA_FILE.open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            sections.setdefault(row["site"], RiverSection(row["section"]))
            names.setdefault(row["site"], row["site_name"])
            coordinates.setdefault(row["site"], geometry.Coordinate(float(row["lon"]), float(row["lat"])))

    orders = dict()
    distances = dict()

    with _SITE_ENVIRONMENT_FILE.open(encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            orders[row["site"]] = int(float(row["strahler"]))
            distances[row["site"]] = float(row["dist_mouth_km"])

    sites = tuple(
        SamplingSite(code=code, name=names[code], section=sections[code], coordinate=coordinates[code],
                     strahler_order=orders[code], distance_to_mouth_km=distances[code])
        for code in sorted(sections)
    )

    return sites


@dataclass
class StudyAreaPanel:
    """
    Renders panel (a) into its own image.

    The panel owns an image so that a stray polygon or an oversized inset cannot bleed across a panel
    boundary; Pillow does no clipping of its own.
    """

    metrics: layout.FigureMetrics
    width: int
    height: int
    sites: tuple[SamplingSite, ...]
    image: Image.Image = field(init=False)
    label_set: labels.LabelSet = field(init=False)

    def __post_init__(self) -> None:
        """Builds the panel image, its viewport, and its label registry."""

        # The background is the water colour rather than white: everything not covered by a land polygon is
        # either river or lake, so starting from water means a gap in the coastline reads as water, not as a hole.
        self.image = Image.new("RGB", (self.width, self.height), _TERRAIN["locator_sea"])
        self._draw = ImageDraw.Draw(self.image)

        # The projection is centred on the reach and its standard parallels bracket it, which keeps distortion
        # across the mapped strip small. The viewport then fits that projection to this panel's pixel box.
        projection = geometry.AlbersEqualArea(*_MAP_PROJECTION)
        self._viewport = geometry.Viewport(projection, _MAP_EXTENT, self.width, self.height)
        self._halo = self.metrics.pt(1.0)
        self.label_set = labels.LabelSet(width=self.width, height=self.height, padding=self.metrics.mm(0.35))

    def build(self, minimum_population: int, maximum_towns: int, locator_mm: tuple[float, float]) -> StudyAreaPanel:
        """
        Draws every layer in back-to-front order.

        Ordering matters twice over. Painted layers go down before the marks that sit on them, and the
        site footprints are reserved before any decoration competes for the same space, so a graticule
        label or a town name is dropped rather than drawn over a sampling site.
        """

        self._draw_land()
        self._draw_rivers()
        self._draw_locator(*locator_mm)
        self._draw_furniture()

        self._reserve_sites()

        drawing.draw_graticule(self._draw, self.metrics, self._viewport, self.label_set, _MAP_EXTENT,
                               _GRATICULE_STEP_DEG, colour=_INK["graticule"], text_colour=_INK["muted"],
                               halo=_INK["surface"])
        self._draw_context_labels()
        self._draw_towns(minimum_population, maximum_towns)
        self._draw_sites()

        return self

    def _draw_land(self) -> None:
        """Draws land, the provincial boundary, the national border, and standing water."""

        land = _load_geo("land_50m.geojson")

        # Land is drawn in two passes over the same features: every fill goes down first, then every outline. A
        # single pass would let one country's fill paint over its neighbour's border where the two polygons meet.
        for feature in land:
            fill = _TERRAIN["land_china"] if feature.name == _CHINA else _TERRAIN["land_other"]
            drawing.draw_polygon_rings(self._draw, self._viewport, feature.geometry, fill=fill)

        for feature in _load_geo("provinces_cn.geojson"):
            drawing.draw_polygon_rings(self._draw, self._viewport, feature.geometry, outline=_TERRAIN["province_edge"],
                               width=self.metrics.pt(0.4))

        # China's own outline is the China-Russia border along this reach, so it is stroked more strongly than the
        # neighbouring coastline.
        for feature in land:
            border = _TERRAIN["border"] if feature.name == _CHINA else _TERRAIN["land_edge"]
            drawing.draw_polygon_rings(self._draw, self._viewport, feature.geometry, outline=border,
                               width=self.metrics.pt(0.65))

        for feature in _load_geo("lakes_10m.geojson"):
            drawing.draw_polygon_rings(self._draw, self._viewport, feature.geometry, fill=_TERRAIN["water_fill"],
                               outline=_TERRAIN["water_edge"], width=self.metrics.pt(0.4))

    def _draw_rivers(self) -> None:
        """Draws the detailed channel network first, then the named rivers over it."""

        tributary_colour = _SECTION_COLOUR[RiverSection.TRIBUTARY]

        # The dense OpenStreetMap network goes down first as background texture, so the named rivers drawn after it
        # read as the primary hydrography rather than competing with a thousand minor channels.
        for feature in _load_geo("rivers_osm.geojson"):
            coordinates = feature.geometry["coordinates"]

            # The extract is clipped to a window wider than the panel, so off-panel ways are skipped before the
            # more expensive proximity test runs.
            if not self._is_visible(coordinates):
                continue

            sampled = self._is_sampled_tributary(coordinates)
            colour = tributary_colour if sampled else _TERRAIN["river_minor"]
            drawing.draw_polyline(self._draw, self._viewport, coordinates, colour,
                          self.metrics.pt(1.0 if sampled else 0.4))

        for feature in _load_geo("rivers_named_10m.geojson"):
            self._draw_named_river(feature)

    def _draw_named_river(self, feature: geojson.GeoFeature) -> None:
        """Draws one named river, splitting the study river into its two reaches."""

        # Natural Earth ranks rivers from 1 for the largest, so the width is inverted from the rank. An absent rank
        # is treated as the least prominent value the dataset uses.
        scalerank = float(feature.properties.get("scalerank") or 10)

        # Named rivers get a generous visibility margin because a single feature can run far beyond the frame and
        # still need to be stroked across it; a tight test would drop the whole line.
        for line in geojson.line_strings(feature.geometry):
            if not self._is_visible(line, margin=self.metrics.mm(40.0)):
                continue

            # Four tiers of prominence, from the study river down to background hydrography. The study river is the
            # only one split by reach, because it is the only one whose sections the figure distinguishes.
            if feature.name == _STUDY_RIVER:
                for section, reach in _split_main_stem(line):
                    drawing.draw_polyline(self._draw, self._viewport, reach, _SECTION_COLOUR[section],
                                  self.metrics.pt(1.5))
            elif feature.name in _SAMPLED_TRIBUTARY_RIVERS:
                drawing.draw_polyline(self._draw, self._viewport, line, _SECTION_COLOUR[RiverSection.TRIBUTARY],
                              self.metrics.pt(1.0))
            elif feature.name in _MAJOR_RIVERS:
                drawing.draw_polyline(self._draw, self._viewport, line, _TERRAIN["river_major"],
                              self.metrics.pt(max(0.9, (11.0 - scalerank) * 0.2)))
            else:
                drawing.draw_polyline(self._draw, self._viewport, line, _TERRAIN["river_minor"], self.metrics.pt(0.55))

    def _draw_context_labels(self) -> None:
        """Draws the country names and the two water bodies that orient the reader."""

        country_font = self.metrics.font(9.0, layout.FontWeight.BOLD)

        for coordinate, name in _CONTEXT_LABELS:
            position = self._viewport(coordinate.longitude, coordinate.latitude)
            self.label_set.text(self._draw, position, name, country_font, _INK["muted"], anchor="mm",
                             halo=_INK["surface"], halo_width=self.metrics.pt(1.4), tag="country")

        hydrography_font = self.metrics.font(8.0, layout.FontWeight.ITALIC)

        for coordinate, name in _HYDROGRAPHY_LABELS:
            position = self._viewport(coordinate.longitude, coordinate.latitude)
            self.label_set.text(self._draw, position, name, hydrography_font, _INK["hydrography"], anchor="lm",
                             halo=_INK["surface"], halo_width=self._halo, tag="hydrography")

    def _draw_towns(self, minimum_population: int, maximum_towns: int) -> None:
        """Draws the largest towns that fit, skipping any that duplicate a sampling site."""

        font = self.metrics.font(8.0)
        half = self.metrics.mm(0.62)
        margin = self.metrics.mm(4.0)
        ranked = sorted(_load_geo("places_osm.geojson"), key=lambda feature: -feature.population())
        drawn = 0

        for feature in ranked:
            if drawn >= maximum_towns:
                break

            if feature.population() < minimum_population:
                continue

            longitude, latitude = feature.geometry["coordinates"]
            place = geometry.Coordinate(longitude, latitude)

            if any(geometry.ground_distance_km(place, site.coordinate) <= _TOWN_DEDUPE_KM for site in self.sites):
                continue

            x, y = self._viewport(longitude, latitude)

            if not (margin <= x <= self.width - margin and margin <= y <= self.height - margin):
                continue

            to_right = x < self.width * 0.7
            text_x = x + (self.metrics.mm(1.6) if to_right else -self.metrics.mm(1.6))
            anchor = "lm" if to_right else "rm"

            # The symbol and its name are reserved as one box, so a later label cannot land between them.
            text_box = self.label_set.text_box(self._draw, (text_x, y), feature.name, font, anchor)
            combined = labels.Rectangle(min(text_box.left, x - half), min(text_box.top, y - half),
                                 max(text_box.right, x + half), max(text_box.bottom, y + half))

            if not self.label_set.fits(combined):
                continue

            drawing.draw_marker(self._draw, x, y, drawing.Symbol.HOLLOW_SQUARE, half, _INK["white"],
                                ring=_INK["secondary"], ring_width=self.metrics.pt(0.6))
            self._draw.text((text_x, y), feature.name, font=font, fill=_INK["secondary"], anchor=anchor,
                            stroke_width=self._halo, stroke_fill=_INK["surface"])
            self.label_set.reserve(combined, "town")
            drawn += 1

    def _reserve_sites(self) -> None:
        """Claims every marker footprint before decoration is placed."""

        # This runs before the graticule, the country names, and the towns. Reserving first is the whole mechanism
        # by which decoration yields to data: a label that would sit on a site simply fails to fit and is dropped.
        radius = self.metrics.mm(_SITE_RADIUS_MM)

        for site in self.sites:
            x, y = self._viewport(site.coordinate.longitude, site.coordinate.latitude)
            self.label_set.reserve(labels.Rectangle(x - radius, y - radius, x + radius, y + radius),
                                f"site-marker-{site.code}")

    def _draw_sites(self) -> None:
        """Draws the site markers, then their codes through the collision search."""

        radius = self.metrics.mm(_SITE_RADIUS_MM)
        ring_width = self.metrics.pt(0.75)

        # All the markers are drawn before any of the codes, so a marker can never cover a code that was already
        # placed. Shape and colour both encode the river section, so the marks stay legible in greyscale.
        for site in self.sites:
            x, y = self._viewport(site.coordinate.longitude, site.coordinate.latitude)
            drawing.draw_marker(self._draw, x, y, _SECTION_SHAPE[site.section], radius, _SECTION_COLOUR[site.section],
                        ring=_INK["surface"], ring_width=ring_width)

        font = self.metrics.font(8.5, layout.FontWeight.BOLD)
        candidates = _site_label_candidates(self.metrics.mm(_SITE_LABEL_OFFSET_MM))

        # South to north keeps the crowded southern cluster deterministic between renders.
        for site in sorted(self.sites, key=lambda item: (item.coordinate.latitude, item.coordinate.longitude)):
            x, y = self._viewport(site.coordinate.longitude, site.coordinate.latitude)
            self.label_set.anchored(self._draw, x, y, site.code, font, _INK["primary"], candidates,
                                 halo=_INK["surface"], halo_width=self.metrics.pt(1.1),
                                 tag=f"site-label-{site.code}", leader_from=_LEADER_CANDIDATE_INDEX,
                                 leader_fill=_INK["muted"], leader_width=self.metrics.pt(0.4))

    def _draw_furniture(self) -> None:
        """Draws the scale bar and the north arrow, reserving the space they take."""

        # The bar sits bottom-left and the arrow top-right, the two corners the sampling corridor does not reach.
        # Both boxes are reserved so a later graticule or town label cannot land on them.
        scale_box = drawing.draw_scale_bar(self._draw, self.metrics,
                                   km_per_pixel=self._viewport.km_per_pixel(*_SCALE_BAR_ANCHOR),
                                   left=self.metrics.mm(5.0),
                                   top=self.height - self.metrics.mm(6.5) - self.metrics.mm(1.3),
                                   fill=_INK["primary"], alternate=_INK["white"], halo=_INK["surface"])
        self.label_set.reserve(scale_box, "scale-bar")

        north_box = drawing.draw_north_arrow(self._draw, self.metrics, self.width - self.metrics.mm(6.5),
                                     self.metrics.mm(7.5), fill=_INK["primary"], surface=_INK["white"])
        self.label_set.reserve(north_box, "north-arrow")

    def _draw_locator(self, width_mm: float, height_mm: float) -> None:
        """Pastes an East Asia locator into the top-left corner."""

        box_width = round(self.metrics.mm(width_mm))
        box_height = round(self.metrics.mm(height_mm))
        inset = _render_locator(self.metrics, box_width, box_height)
        margin = round(self.metrics.mm(2.0))

        self.image.paste(inset, (margin, margin))
        self.label_set.reserve(labels.Rectangle(margin, margin, margin + box_width, margin + box_height), "locator")

    def _is_visible(self, coordinates: list[tuple[float, float]], margin: float = 40.0) -> bool:
        """Returns `True` when any vertex falls inside the panel plus a margin."""

        for longitude, latitude in coordinates:
            x, y = self._viewport(longitude, latitude)

            if -margin <= x <= self.width + margin and -margin <= y <= self.height + margin:
                return True

        return False

    def _is_sampled_tributary(self, coordinates: list[tuple[float, float]]) -> bool:
        """
        Returns `True` when a channel passes close to one of the tributary sampling sites.

        The basemap extract does not record which channel each site was sampled from, so proximity stands in
        for that link. Four kilometres is loose enough to catch the channel through a site whose coordinate
        sits slightly off the mapped centreline, and tight enough not to catch a neighbouring stream.
        """

        tributaries = [site for site in self.sites if site.section is RiverSection.TRIBUTARY]

        for longitude, latitude in coordinates:
            vertex = geometry.Coordinate(longitude, latitude)

            if any(geometry.ground_distance_km(vertex, site.coordinate) <= _SAMPLED_TRIBUTARY_RADIUS_KM
                   for site in tributaries):
                return True

        return False


def draw_network_panel(draw: ImageDraw.ImageDraw, metrics: layout.FigureMetrics, label_set: labels.LabelSet,
                       sites: tuple[SamplingSite, ...], left: float, right: float, top: float,
                       bottom: float) -> None:
    """
    Draws panel (b): the main stem as a tapering line, with the tributaries branching from it.

    The stem thickens downstream so the reader can see the river growing, and every site sits at its true
    distance from the confluence. Main-stem labels go to the left of the stem and tributary labels to the
    right, which keeps the two families from competing for the same space.
    """

    # The axis runs from the headwater end at the top to the confluence at the bottom, matching the way the map
    # beside it is oriented. The stem is placed off-centre to the left so the branches have room to fan out right.
    axis_maximum, axis_minimum = _NETWORK_AXIS_KM
    panel_width = right - left
    stem_x = left + panel_width * 0.22
    halo = metrics.pt(1.0)
    label_font = metrics.font(8.0, layout.FontWeight.BOLD)
    axis_font = metrics.font(7.5)

    def y_for(distance_km: float) -> float:
        """Returns the vertical position of one distance on the axis."""

        # Larger distances are further upstream, so they map towards the top of the panel.
        return bottom - (distance_km - axis_minimum) / (axis_maximum - axis_minimum) * (bottom - top)

    # The stem is stroked as many short segments rather than one line so its width can grow continuously from
    # headwater to mouth. Drawing it as two constant-width reaches would lose that cue.
    steps = 140

    for index in range(steps):
        upper = axis_maximum - (axis_maximum - axis_minimum) * index / steps
        lower = axis_maximum - (axis_maximum - axis_minimum) * (index + 1) / steps
        section = (RiverSection.UPSTREAM if 0.5 * (upper + lower) > _MAIN_STEM_SPLIT_KM
                   else RiverSection.DOWNSTREAM)
        draw.line([(stem_x, y_for(upper)), (stem_x, y_for(lower))], fill=_SECTION_COLOUR[section],
                  width=metrics.pt(0.9 + 1.9 * index / steps))

    label_set.text(draw, (stem_x, y_for(axis_minimum) + metrics.mm(4.5)), "↓  to Amur confluence",
                axis_font, _INK["muted"], anchor="mm", halo=_INK["surface"], halo_width=halo, tag="mouth",
                required=True)

    for distance in _NETWORK_AXIS_TICKS_KM:
        y = y_for(distance)
        draw.line([(left - metrics.mm(6.5), y), (left - metrics.mm(5.2), y)], fill=_INK["rule"],
                  width=metrics.pt(0.4))
        label_set.text(draw, (left - metrics.mm(7.5), y), f"{distance}", axis_font, _INK["muted"], anchor="rm",
                    tag="axis", required=True)

    label_set.text(draw, (left - metrics.mm(7.5), top - metrics.mm(4.5)), "km", axis_font, _INK["muted"],
                anchor="rm", tag="axis-unit", required=True)

    main_stem_offsets = tuple(labels.LabelOffset(-metrics.mm(2.6), metrics.mm(shift), "rm")
                              for shift in (0.0, -3.0, 3.0, -5.6, 5.6))

    for site in sites:
        if site.section is RiverSection.TRIBUTARY:
            continue

        y = y_for(site.distance_to_mouth_km)
        drawing.draw_marker(draw, stem_x, y, _SECTION_SHAPE[site.section], metrics.mm(0.95),
                    _SECTION_COLOUR[site.section], ring=_INK["surface"], ring_width=metrics.pt(0.75))
        label_set.reserve(labels.Rectangle(stem_x - metrics.mm(1.0), y - metrics.mm(1.0), stem_x + metrics.mm(1.0),
                                 y + metrics.mm(1.0)), f"stem-marker-{site.code}")
        label_set.anchored(draw, stem_x, y, f"{site.code}  {site.short_name}", label_font, _INK["primary"],
                        main_stem_offsets, halo=_INK["surface"], halo_width=halo, tag=f"stem-{site.code}")

    tributaries = sorted((site for site in sites if site.section is RiverSection.TRIBUTARY),
                         key=lambda site: -site.distance_to_mouth_km)
    tributary_offsets = (labels.LabelOffset(metrics.mm(2.2), 0.0, "lm"),
                         labels.LabelOffset(metrics.mm(2.2), -metrics.mm(2.8), "lm"),
                         labels.LabelOffset(metrics.mm(2.2), metrics.mm(2.8), "lm"),
                         labels.LabelOffset(-metrics.mm(2.2), -metrics.mm(2.8), "rm"))

    for index, site in enumerate(tributaries):
        # Branch lengths cycle so that neighbouring confluences do not stack their labels in one column.
        length = panel_width * (0.20 + 0.085 * (index % 3))
        y = y_for(site.distance_to_mouth_km)
        end_x, end_y = stem_x + length, y - metrics.mm(3.4)

        # Branch thickness scales with Strahler order, so a reader can see that the sampled tributaries range from
        # a second-order headwater stream to a sixth-order river without reading the numbers.
        draw.line([(stem_x, y), (end_x, end_y)], fill=_SECTION_COLOUR[RiverSection.TRIBUTARY],
                  width=metrics.pt(0.55 + 0.13 * site.strahler_order))
        drawing.draw_marker(draw, end_x, end_y, _SECTION_SHAPE[RiverSection.TRIBUTARY], metrics.mm(0.95),
                    _SECTION_COLOUR[RiverSection.TRIBUTARY], ring=_INK["surface"], ring_width=metrics.pt(0.75))
        label_set.reserve(labels.Rectangle(end_x - metrics.mm(1.0), end_y - metrics.mm(1.0), end_x + metrics.mm(1.0),
                                 end_y + metrics.mm(1.0)), f"trib-marker-{site.code}")
        label_set.anchored(draw, end_x, end_y, f"{site.code}  {site.short_name}", label_font, _INK["primary"],
                        tributary_offsets, halo=_INK["surface"], halo_width=halo, tag=f"trib-{site.code}")


type RenderResult = tuple[Image.Image, layout.FigureMetrics, tuple[labels.LabelAudit, ...]]


def render_figure(dpi: int, supersample: int) -> RenderResult:
    """
    Composes both panels at the requested resolution.

    Returns:
        The rendered image, the metrics it was drawn against, and one audit per panel.
    """

    # Everything downstream of here is sized through `metrics`, so changing the dpi or the supersample factor
    # rescales the whole figure without altering any printed dimension.
    metrics = layout.FigureMetrics(width_mm=_COLUMN_WIDTH_MM, height_mm=_FIGURE_HEIGHT_MM, dpi=dpi,
                            supersample=supersample, minimum_point_size=_MINIMUM_POINT_SIZE)
    sites = load_sampling_sites()
    canvas = Image.new("RGB", (metrics.canvas_width, metrics.canvas_height), _INK["surface"])

    # The map takes slightly under half the width: the study reach is a narrow north-south corridor, so the map
    # needs height rather than width, and the surplus goes to the network panel where the labels are long.
    map_width = int(metrics.canvas_width * 0.48)
    map_height = metrics.canvas_height - int(metrics.mm(5.0))
    panel = StudyAreaPanel(metrics=metrics, width=map_width, height=map_height, sites=sites)
    panel.build(minimum_population=60000, maximum_towns=4, locator_mm=(30.0, 23.0))
    canvas.paste(panel.image, (0, 0))

    # The network panel gets its own registry over the whole canvas, with the map's footprint reserved. That keeps
    # the two panels' label searches independent while still stopping a network label from crossing into the map.
    draw = ImageDraw.Draw(canvas)
    label_set = labels.LabelSet(width=metrics.canvas_width, height=metrics.canvas_height, padding=metrics.mm(0.3))
    label_set.reserve(labels.Rectangle(0.0, 0.0, map_width, map_height), "map-panel")

    draw.line([(map_width, 0), (map_width, map_height)], fill=_INK["rule"], width=metrics.pt(0.55))
    draw.text((metrics.mm(2.5), map_height - metrics.mm(2.5)), "(a)", font=metrics.font(11.0, layout.FontWeight.BOLD),
              fill=_INK["primary"], anchor="ls")
    draw.text((map_width + metrics.mm(2.5), metrics.mm(4.0)), "(b)",
              font=metrics.font(11.0, layout.FontWeight.BOLD), fill=_INK["primary"], anchor="la")

    panel_left = map_width + metrics.mm(16.0)
    panel_right = metrics.canvas_width - metrics.mm(5.0)
    panel_top = metrics.mm(24.0)
    panel_bottom = map_height - metrics.mm(34.0)

    draw.text((panel_left - metrics.mm(6.0), metrics.mm(4.0)), "Position in the river network",
              font=metrics.font(9.5, layout.FontWeight.BOLD), fill=_INK["primary"], anchor="la")
    draw.text((panel_left - metrics.mm(6.0), metrics.mm(9.5)),
              "vertical axis: distance to the Ussuri–Amur confluence", font=metrics.font(7.5),
              fill=_INK["muted"], anchor="la")

    draw_network_panel(draw, metrics, label_set, sites, panel_left, panel_right, panel_top, panel_bottom)

    drawing.draw_horizontal_legend(draw, metrics, panel_left - metrics.mm(6.0), panel_bottom + metrics.mm(8.0),
                           _legend_entries(), metrics.canvas_width - panel_left - metrics.mm(4.0),
                           text_colour=_INK["secondary"], title_colour=_INK["primary"], surface=_INK["white"],
                           outline=_INK["secondary"], title="eDNA sampling site")
    draw.text((panel_left - metrics.mm(6.0), map_height - metrics.mm(3.0)),
              "Tributary marker size scales with Strahler stream order.",
              font=metrics.font(7.5, layout.FontWeight.ITALIC), fill=_INK["muted"], anchor="ls")
    draw.text((metrics.mm(3.0), metrics.canvas_height - metrics.mm(1.6)), _CREDIT, font=metrics.font(7.0),
              fill=_INK["muted"], anchor="ls")

    # The single downsample at the end is what antialiases the whole figure. Doing it once, rather than per layer,
    # keeps hairlines and glyph edges consistent across the panels.
    rendered = canvas.resize((metrics.width_px, metrics.height_px), Image.LANCZOS)

    return rendered, metrics, (panel.label_set.audit("map"), label_set.audit("network"))


def save_figure(image: Image.Image, path: Path, dpi: int) -> None:
    """Writes the figure, compressing TIFF output so the print file stays a reasonable size."""

    # The dpi is written into the file header as well as being used for layout, so a publisher's checker reads the
    # resolution the figure was actually designed at rather than inferring it from the pixel count.
    path.parent.mkdir(parents=True, exist_ok=True)

    if path.suffix.lower() in (".tif", ".tiff"):
        image.save(path, dpi=(dpi, dpi), compression="tiff_lzw")
    else:
        image.save(path, dpi=(dpi, dpi))

    print(f"wrote {path}  ({image.width}x{image.height} px, "
          f"{_COLUMN_WIDTH_MM:g}x{_FIGURE_HEIGHT_MM:g} mm @ {dpi} dpi)")


def main() -> int:
    """
    Renders Figure 1 and reports the label audit.

    Returns:
        Process exit code: zero when every panel is clean, one when the audit needs attention.
    """

    parser = argparse.ArgumentParser(description="Render Figure 1 of the Ussuri River eDNA manuscript.")
    parser.add_argument(
        "--print",
        action="store_true",
        dest="print_quality",
        help="Render the submission files instead of the on-screen review proof.",
    )
    parsed_args = parser.parse_args()

    # The review proof and the submission files differ only in resolution and supersampling. Both go through the
    # same layout code, so what a reviewer approves on screen is what the print file contains.
    if parsed_args.print_quality:
        # The two submission files are rendered separately rather than resampled from one master, so each is laid
        # out at its own resolution and its text keeps the exact stroke weight the metrics asked for.
        tiff, metrics, audits = render_figure(_PRINT_DPI, _SUPERSAMPLE_PRINT)
        save_figure(tiff, OUTPUT_DIR / "Figure1.tif", _PRINT_DPI)

        png, _, _ = render_figure(_SUBMISSION_PNG_DPI, _SUPERSAMPLE_PRINT)
        save_figure(png, OUTPUT_DIR / "Figure1.png", _SUBMISSION_PNG_DPI)
    else:
        proof, metrics, audits = render_figure(_REVIEW_DPI, _SUPERSAMPLE_REVIEW)
        save_figure(proof, OUTPUT_DIR / "Figure1_review.png", _REVIEW_DPI)

    clean = labels.report_audit(audits, metrics.undersized_points, metrics.minimum_point_size)

    return 0 if clean else 1


def _legend_entries() -> tuple[drawing.LegendEntry, ...]:
    """Returns the legend rows shared by both panels."""

    entries = tuple(drawing.LegendEntry(_SECTION_SHAPE[section], _SECTION_COLOUR[section], _SECTION_LABEL[section])
                    for section in RiverSection)

    return entries + (
        drawing.LegendEntry(drawing.Symbol.HOLLOW_SQUARE, None, "Town"),
        drawing.LegendEntry(drawing.Symbol.LINE, _SECTION_COLOUR[RiverSection.UPSTREAM], "Ussuri, upper"),
        drawing.LegendEntry(drawing.Symbol.LINE, _SECTION_COLOUR[RiverSection.DOWNSTREAM], "Ussuri, lower"),
        drawing.LegendEntry(drawing.Symbol.LINE, _SECTION_COLOUR[RiverSection.TRIBUTARY], "Tributary channel"),
    )


def _site_label_candidates(offset: float) -> tuple[labels.LabelOffset, ...]:
    """Returns candidate label positions, ordered from the tightest placement to the loosest."""

    # The order matters: the search takes the first that fits, so the tight cardinal positions come first, then the
    # diagonals, then progressively longer offsets. Everything from index 8 onwards gets a leader line, because at
    # that distance the reader can no longer tell which mark the label belongs to.
    candidates = (
        labels.LabelOffset(offset, 0.0, "lm"),
        labels.LabelOffset(-offset, 0.0, "rm"),
        labels.LabelOffset(0.0, -offset * 1.15, "ms"),
        labels.LabelOffset(0.0, offset * 1.15, "ms"),
        labels.LabelOffset(offset * 0.85, -offset * 0.85, "lm"),
        labels.LabelOffset(-offset * 0.85, -offset * 0.85, "rm"),
        labels.LabelOffset(offset * 0.85, offset * 0.85, "lm"),
        labels.LabelOffset(-offset * 0.85, offset * 0.85, "rm"),
        labels.LabelOffset(offset * 2.0, -offset * 1.1, "lm"),
        labels.LabelOffset(-offset * 2.0, offset * 1.1, "rm"),
        labels.LabelOffset(offset * 2.7, 0.0, "lm"),
        labels.LabelOffset(-offset * 2.7, 0.0, "rm"),
        labels.LabelOffset(offset * 3.6, -offset * 1.8, "lm"),
        labels.LabelOffset(-offset * 3.6, offset * 1.8, "rm"),
    )

    return candidates


def _split_main_stem(line: list[tuple[float, float]]) -> list[tuple[RiverSection, list[tuple[float, float]]]]:
    """Splits the study river's centreline into consecutive upper and lower reaches."""

    # Segments are accumulated into runs so each reach is stroked as one polyline. Stroking segment by segment
    # would show a bead at every vertex where the round line caps overlap.
    runs = list()
    current_section: RiverSection | None = None
    current = list()

    for start, end in zip(line, line[1:]):
        section = (RiverSection.UPSTREAM if 0.5 * (start[1] + end[1]) < _SECTION_SPLIT_LAT
                   else RiverSection.DOWNSTREAM)

        if section is not current_section:
            if current:
                runs.append((current_section, current))

            current_section = section
            current = [start, end]
        else:
            current.append(end)

    if current:
        runs.append((current_section, current))

    return runs


def _load_geo(filename: str) -> tuple[geojson.GeoFeature, ...]:
    """Loads one committed basemap extract from `data/geo`."""

    return geojson.load_feature_collection(GEO_DIR / filename)


def _render_locator(metrics: layout.FigureMetrics, width: int, height: int) -> Image.Image:
    """
    Renders the East Asia locator inset as a standalone image.

    Drawing into its own image is what keeps the inset self-contained: country polygons that extend well
    beyond the frame are cropped by the paste rather than spilling across the map.
    """

    image = Image.new("RGB", (width, height), _TERRAIN["locator_sea"])
    draw = ImageDraw.Draw(image)
    viewport = geometry.Viewport(geometry.AlbersEqualArea(*_LOCATOR_PROJECTION), _LOCATOR_EXTENT, width, height)

    for feature in _load_geo("locator_countries.geojson"):
        fill = _TERRAIN["land_china"] if feature.name == _CHINA else _TERRAIN["land_other"]
        drawing.draw_polygon_rings(draw, viewport, feature.geometry, fill=fill, outline=_TERRAIN["locator_land_edge"],
                           width=metrics.pt(0.35))

    lon_min, lat_min, lon_max, lat_max = _MAP_EXTENT
    centre_x, centre_y = viewport(0.5 * (lon_min + lon_max), 0.5 * (lat_min + lat_max))
    radius = max(metrics.mm(1.2), width * 0.05)
    halo = metrics.pt(1.0)
    font = metrics.font(7.5, layout.FontWeight.BOLD)

    draw.ellipse([centre_x - radius, centre_y - radius, centre_x + radius, centre_y + radius],
                 outline=_TERRAIN["locator_mark"], width=metrics.pt(0.9))
    draw.text((centre_x - radius * 1.5, centre_y + radius * 1.4), "study area", font=font,
              fill=_TERRAIN["locator_mark"], anchor="rm", stroke_width=halo, stroke_fill=_TERRAIN["locator_sea"])
    draw.text(viewport(106.0, 36.5), "CHINA", font=font, fill=_INK["muted"], anchor="mm", stroke_width=halo,
              stroke_fill=_TERRAIN["land_china"])
    draw.text(viewport(121.0, 52.8), "RUSSIA", font=font, fill=_INK["muted"], anchor="mm", stroke_width=halo,
              stroke_fill=_TERRAIN["land_other"])
    draw.rectangle([0, 0, width - 1, height - 1], outline=_INK["secondary"], width=metrics.pt(0.7))

    return image


if __name__ == "__main__":
    raise SystemExit(main())
