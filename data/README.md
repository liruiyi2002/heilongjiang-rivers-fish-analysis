# Data provenance

**English** · [中文](README.zh-CN.md)

Every file in this folder and where it comes from. Numeric precision is kept at a level the data can
support: Gower distances to 4 dp; coordinates and PC scores to 3 dp; continuous traits to 1-2 dp; read
counts are integers.

## Files

| File                             | Contents and source                                                              |
| -------------------------------- | -------------------------------------------------------------------------------- |
| `site_by_species_reads.csv`      | 26 site-seasons x 100 taxa; eDNA reads; the exact sum of the 3 field replicates. |
| `replicate_by_species_reads.csv` | 78 samples x 100 taxa; per-replicate reads (spring = BZ2023, autumn = BZ2024).   |
| `species_taxonomy.csv`           | 100 taxa -> genus / family / order (12 / 27 / 72); from the provider lineage.    |
| `species_traits.csv`             | 100 taxa x 9 functional traits; FishBase, regional refs, primary literature.     |
| `trait_value_glossary.csv`       | Original-to-English mapping for the categorical trait levels.                    |
| `gower_distance.csv`             | 100 x 100 Gower distance among taxa; computed from species_traits.csv.           |
| `site_environment.csv`           | 13 sites x hydro-geographic variables + PC1-PC3; from open datasets.             |
| `site_metadata.csv`              | 26 site-seasons: site, season, river section, name, channel type, coords.        |
| `site_water_quality_seasonal.csv` | 26 site-seasons x 7 variables incl. ammonia nitrogen; the authors' field/lab table. |
| `site_land_use.csv`              | 13 sites x 9 CLCD land-cover shares in a 2 km buffer, plus the pixel count.      |
| `geo/`                           | Clipped basemap extracts for Figure 1 - see [`geo/SOURCES.md`](geo/SOURCES.md).  |

## How the community data were assembled

The two sequencing-provider deliveries each hold 13 sites x 3 field replicates. Summed per site they
give the site-level table (`site_by_species_reads.csv`), and they map to season unambiguously:
**BZ2023 = spring** (sampled April 2023), **BZ2024 = autumn** (sampled October 2024). Chum salmon
(*Oncorhynchus keta*), an autumn spawner, is ~14% of reads in the autumn delivery and ~0% in the
spring one. The summed replicates reproduce the site-level table exactly (max difference 0 across all
2,600 taxon x site-season cells).

Raw FASTQ sequence reads are **not** included here; they are to be deposited in the NCBI Sequence Read
Archive and cited in the manuscript. The upstream bioinformatics (reads -> species table) was run by
the sequencing provider and is outside this package.

## Environmental data

**Water quality.** `site_water_quality_seasonal.csv` holds the authors' own measurements for both
seasons: water temperature, pH, conductivity, dissolved oxygen, total phosphorus, total nitrogen and
ammonia nitrogen. Field variables were read with a YSI ProQuatro meter; nutrients were determined in
the laboratory. Each site-season carries its own row, so the chemistry is joined to the community data
on **season and site** rather than on site alone.

**Land cover.** `site_land_use.csv` gives the share of each of the nine CLCD classes within a **2 km
buffer** of every site, computed from the original per-class pixel counts (CLCD 30 m; Yang & Huang,
2021). The buffer radius is confirmed by the counts themselves: the five inland tributary buffers
each cover 12.55 km², against pi x 2^2 = 12.57 km². CLCD covers China only, so buffers at the eight
border sites are clipped at the channel (5.4-8.8 km²); shares are therefore of the **classified**
area, and `classified_pixels` and `buffer_area_km2` are included so this is explicit. Land cover is a
fixed site property and does not vary between seasons. Snow/ice is zero at every site.

## Taxon naming

One taxon carries a different label between annotations: the study's *Chanodichthys erythropterus* is
*Chanodichthys ilishaeformis* in the provider's current reference library (same genus, identical
reads). The study name is retained here.

## License

The data and documentation in this repository are licensed under **CC BY-NC 4.0** (attribution,
non-commercial); the analysis code is licensed separately under the **PolyForm Noncommercial License
1.0.0**. See `../LICENSE`, `../LICENSE-DATA` and `../LICENSE-CODE`.
