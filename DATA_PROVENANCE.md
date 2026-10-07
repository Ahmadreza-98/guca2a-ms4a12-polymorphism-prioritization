# Data provenance

This document records the origin and role of the archived files used by `analysis.R` for the GUCA2A/MS4A12 polymorphism-prioritization workflow.

The exact historical dbSNP download date and Ensembl release were not retained in the project materials. Those details are therefore reported as **not recorded** rather than reconstructed later from current databases.

## Raw dbSNP exports

### `data/raw/GUCA2A_SNPs_dbSNP.txt`
### `data/raw/MS4A12_SNPs_dbSNP.txt`

Source: **NCBI dbSNP**  
Website: https://www.ncbi.nlm.nih.gov/snp/

According to the manuscript Methods, the study workflow queried `"ms4a12"[Gene Name]` and `"guca2a"[Gene Name]`, applied **MAF > 0.01**, and filtered for **SNVs** (`"snv"[SNP Class]`). The archived exports contain repeated records for some variants, so counts in the cleaned analysis are based on unique rsIDs after the SNV filter.

Archived counts used as a reproducibility check:

- GUCA2A: 19 unique SNVs
- MS4A12: 126 unique SNVs

Historical retrieval date / dbSNP release: **not recorded in the retained files**.

## Curated Ensembl SNP annotations

### `data/curated/GUCA2A_curated_annotations.xlsx`
### `data/curated/MS4A12_curated_annotations.xlsx`

Source used in the original workflow: **Ensembl SNP BioMart (`hsapiens_snp`)**  
Website: https://www.ensembl.org/biomart/martview/

These workbooks are **derived and manually checked files**, not untouched primary downloads. As described in the manuscript Methods, the original workflow used the `biomaRt` R package with Ensembl SNP BioMart (`hsapiens_snp`) to obtain MAF, variant type, reference/alternate alleles and GRCh38 genomic coordinates. The resulting tables were then reviewed before the final analysis.

The archived files contain:

- GUCA2A: 19 allele-specific rows / 19 unique rsIDs
- MS4A12: 127 allele-specific rows / 126 unique rsIDs

The second MS4A12 allele-specific row beyond the unique-rsID count is due to `rs2298556`, which is represented by two alternate alleles.

Historical Ensembl release / archive and retrieval date: **not recorded in the retained files**.

## CADD results

### `data/cadd/GUCA2A_CADD_results.tsv`
### `data/cadd/MS4A12_CADD_results.tsv`

Source: **CADD (Combined Annotation Dependent Depletion), version 1.7**  
Website: https://cadd.gs.washington.edu/

The retained files contain the PHRED-scaled CADD scores used for PSI calculation:

```text
PSI = MAF × CADD PHRED
```

The cleaned workflow matches CADD rows to curated variants using **GRCh38 position + reference allele + alternate allele**. All retained curated rows have an exact match in the archived CADD result files.

### Publication-matched interpretation of MAF and CADD

The accepted manuscript defines PSI as `C-score × MAF`. In this repository, `MAF` is the retained Ensembl/BioMart **minor-allele-frequency** field from the manually checked annotation table, and the CADD PHRED score is the score for the exact Ref/Alt submission row. Some curated rows have a minor allele that is not the same nucleotide as the CADD `Alt` allele. The public repository intentionally **does not convert MAF to alternate-allele frequency** in those rows; it preserves the calculation as stated and used in the accepted manuscript. This clarification documents the historical method and does not change the analysis logic.

CADD states on its website that scores are freely available for non-commercial applications; commercial users should consult the current CADD terms. These data are not relicensed by the repository's MIT software license.

## Archived CADD submission files

### `archived_cadd_submission/GUCA2A_CADD_input_original.txt`
### `archived_cadd_submission/MS4A12_CADD_input_original.txt`

These five-column files were prepared for the external CADD scoring step and are retained for provenance. They contain chromosome, GRCh38 position, rsID, reference allele and alternate allele.

`analysis.R` regenerates equivalent CADD-input files under `results/cadd_input/` but does not submit variants to CADD.

## Fixed gene metadata used for figures

The cleaned script retains the GRCh38 gene coordinates used by the analysis rather than querying live annotation services during plotting. This is intentional: a later database release can change metadata and would make a historical figure harder to reproduce exactly.

## Reproducibility rule

When reproducing the accepted manuscript analysis, use the archived files in this repository. A future re-analysis using current dbSNP, Ensembl or CADD data should be treated as a **new database-version analysis**, stored separately, and documented with retrieval dates and release/model versions.
