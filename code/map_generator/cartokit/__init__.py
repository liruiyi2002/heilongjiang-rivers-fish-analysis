"""
Print-metric cartographic drawing toolkit built on Pillow.

Author:     Pouria Hadjibagheri
Email:      pouria.hadjibagheri@partners-cap.com
Copyright:  (c) 2026 Pouria Hadjibagheri
License:    PolyForm Noncommercial 1.0.0 (attribution required, noncommercial use only)
"""

# Star imports are used deliberately here: every module declares an explicit `__all__`, so the exported surface
# stays bounded and this module only aggregates it rather than widening it.
# ruff: noqa: F403


from .drawing import *
from .drawing import __all__ as drawing_all
from .geojson import *
from .geojson import __all__ as geojson_all
from .geometry import *
from .geometry import __all__ as geometry_all
from .labels import *
from .labels import __all__ as labels_all
from .layout import *
from .layout import __all__ as layout_all


__all__ = [
    *drawing_all,
    *geojson_all,
    *geometry_all,
    *labels_all,
    *layout_all,
]
