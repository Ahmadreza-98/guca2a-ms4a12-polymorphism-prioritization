# GUCA2A and MS4A12 polymorphism prioritization

Reproducible R code and archived inputs for the SNP-prioritization component of the accepted manuscript:

**GUCA2A and MS4A12 Predicted Deleterious Polymorphisms: Prioritization and Association with Colorectal Cancer**

| Item | Details |
| --- | --- |
| Authors | Seyed Ahmadreza Siadat; Mostafa Saadat |
| Journal | International Journal of Molecular and Cellular Medicine (IJMCM) |
| Status | Accepted for publication on 23 August 2026 |
| DOI | Pending publication |
| PubMed / PMC | Pending publication |

Journal website: https://www.ijmcmed.org/

This repository covers the **polymorphism-prioritization workflow**. It should not be interpreted as a complete reproduction of every analysis described in the manuscript.

## Analysis overview

The prioritization uses the **Polymorphism Selection Index (PSI)** exactly as defined in the accepted manuscript and originally introduced by **Omidpanah & Saadat (2022)**:

```text
PSI = minor allele frequency (MAF) × CADD PHRED score
```

**PSI reference:** Omidpanah, N., & Saadat, M. (2022). Introducing a new index for selecting genetic polymorphisms for association studies. *EXCLI Journal, 21*, 814–817. https://doi.org/10.17179/excli2022-5004

In the retained workflow, `MAF` is the Ensembl/BioMart minor-allele-frequency annotation preserved in the manually checked study tables, while CADD v1.7 is matched to the exact **GRCh38 position + reference allele + alternate allele** submitted for scoring. The script does **not** reinterpret MAF as alternate-allele frequency when the minor allele differs from the CADD alternate allele; it preserves the manuscript's stated `C-score × MAF` calculation. No PSI calculation logic has been changed for this public repository.

The retained workflow uses **GRCh38** coordinates and the archived **CADD v1.7** scores used for the accepted manuscript.

## Quick start

Clone or download the repository, then keep `analysis.R` next to the `data/` folder:

```text
guca2a-ms4a12-polymorphism-prioritization/
├── analysis.R
├── README.md
├── DATA_PROVENANCE.md
├── CITATION.cff
├── LICENSE
├── .gitignore
├── environment/
│   └── README.md
├── data/
│   ├── raw/
│   │   ├── GUCA2A_SNPs_dbSNP.txt
│   │   └── MS4A12_SNPs_dbSNP.txt
│   ├── curated/
│   │   ├── GUCA2A_curated_annotations.xlsx
│   │   └── MS4A12_curated_annotations.xlsx
│   └── cadd/
│       ├── GUCA2A_CADD_results.tsv
│       └── MS4A12_CADD_results.tsv
└── archived_cadd_submission/
    ├── GUCA2A_CADD_input_original.txt
    └── MS4A12_CADD_input_original.txt
```

In RStudio, open `analysis.R` and use **Source**. You can also run:

```r
source("analysis.R")
```

or from a terminal:

```text
Rscript analysis.R
```

No manual `setwd()` or path editing is required when the repository is kept in the layout above.

## Archived inputs

The archived inputs are intentionally kept with the code because dbSNP, Ensembl and CADD-related annotations can change over time. The default analysis therefore uses the retained study files rather than making live database queries.

### NCBI dbSNP exports

- `data/raw/GUCA2A_SNPs_dbSNP.txt`
- `data/raw/MS4A12_SNPs_dbSNP.txt`

According to the manuscript Methods, the study workflow queried the gene names (`"ms4a12"[Gene Name]` and `"guca2a"[Gene Name]`), applied **MAF > 0.01**, and filtered for **SNVs** (`"snv"[SNP Class]`). The archived files contain repeated records for some entries; after retaining SNVs and deduplicating rsIDs, they yield:

- **GUCA2A:** 19 unique SNVs
- **MS4A12:** 126 unique SNVs

### Curated Ensembl annotations

- `data/curated/GUCA2A_curated_annotations.xlsx`
- `data/curated/MS4A12_curated_annotations.xlsx`

These are **derived and manually checked annotation files**, not untouched primary downloads. As described in the manuscript Methods, the original workflow used the `biomaRt` R package with Ensembl SNP BioMart (`hsapiens_snp`) to obtain MAF, variant type, reference/alternate alleles and GRCh38 genomic coordinates, followed by manual review of the resulting annotation tables before the final analysis.

The retained files contain:

- **GUCA2A:** 19 allele-specific rows / 19 unique rsIDs
- **MS4A12:** 127 allele-specific rows / 126 unique rsIDs

`rs2298556` is represented by two alternate-allele rows in the MS4A12 curated file.

### CADD v1.7 results

- `data/cadd/GUCA2A_CADD_results.tsv`
- `data/cadd/MS4A12_CADD_results.tsv`

CADD results are joined to the curated variants using the exact combination of **GRCh38 position + reference allele + alternate allele**. This avoids unintended many-to-many matching at multiallelic sites. PSI is then calculated from the archived CADD PHRED score and the retained Ensembl minor-allele-frequency field, matching the manuscript definition above.

The original five-column submission files are retained in `archived_cadd_submission/`. The script also regenerates equivalent CADD input tables under `results/cadd_input/`; it does **not** submit variants to the CADD server automatically.

More detail is provided in `DATA_PROVENANCE.md`.

## Sanity checks

The repository inputs were checked independently during packaging. All curated rows have an exact CADD match using position/ref/alt, and the highest PSI variants are:

- **MS4A12:** `rs2298553` (PSI = 16.7370)
- **GUCA2A:** `rs2071499` (PSI = 4.4622)

`analysis.R` checks these expected top variants at the end of each run and issues a warning if the result changes.

## Outputs

A successful run creates:

```text
results/
├── figures/
│   ├── gene_polymorphisms_chr11_ms4a12.pdf
│   ├── gene_polymorphisms_chr11_ms4a12.png
│   ├── gene_polymorphisms_chr1_guca2a.pdf
│   └── gene_polymorphisms_chr1_guca2a.png
├── tables/
│   ├── MS4A12_SNPs_PSI.xlsx
│   ├── MS4A12_SNPs_PSI.csv
│   ├── GUCA2A_SNPs_PSI.xlsx
│   └── GUCA2A_SNPs_PSI.csv
├── cadd_input/
│   ├── MS4A12_CADD_input.tsv
│   └── GUCA2A_CADD_input.tsv
└── sessionInfo.txt
```

PNG figures are written at 600 dpi and the PDF figures are vector graphics.

## R packages

The main script uses:

- `dplyr`
- `ggplot2`
- `ggrepel`
- `ggtext`
- `openxlsx`

`grid` is included with R. Missing CRAN packages are installed automatically by the script.

An `renv.lock` file is not included because the exact historical package library used during the study was not retained. Creating a lockfile now would imply a level of version pinning that the archived project cannot support. Each run writes `results/sessionInfo.txt` so that the actual environment used for that run is recorded. A short environment note is retained in `environment/README.md`. No `sessionInfo_tested.txt` is bundled here because the packaging environment did not contain R and the repository was therefore not re-run during packaging; fabricating a tested-session record would be misleading.

## Reproducibility and database refreshes

The exact historical dbSNP download date and Ensembl release were not retained in the study files. A live query performed later may therefore return different annotations.

For that reason, the files under `data/` are the reproducibility snapshot and should **not** be overwritten when reproducing the accepted analysis. If a future user wants to repeat the prioritization with current databases, the refreshed annotations and CADD scores should be saved separately and clearly labelled with their retrieval dates and database versions.

No automatic live-refresh script is included here because the original workflow included **manual review of Ensembl-derived annotations** and an **external CADD scoring step**. Automating those steps as if they were interchangeable with the archived analysis would be misleading.

## Citation

Until the article receives its final bibliographic information, `CITATION.cff` describes this repository as software. Once the article is published, the final DOI, volume/issue/pages and PubMed/PMC identifiers should be added to this README and the article should be added as the preferred citation in `CITATION.cff`.

The PSI method used in this repository should be attributed to:

Omidpanah, N., & Saadat, M. (2022). Introducing a new index for selecting genetic polymorphisms for association studies. *EXCLI Journal, 21*, 814–817. https://doi.org/10.17179/excli2022-5004

## License and third-party data

The code and repository documentation are released under the **MIT License**; see `LICENSE`.

Bundled third-party database content and derived scores remain subject to the terms of their original sources. In particular, the CADD website states that CADD scores are freely available for non-commercial applications and directs commercial users to contact the CADD team. See https://cadd.gs.washington.edu/ for current terms.

The MIT License does not override third-party data or database terms.
