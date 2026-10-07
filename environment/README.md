# R environment

The exact historical R/package library used during the study was not retained, so this repository does not include a reconstructed `renv.lock`. Creating one after the fact would imply restore fidelity that has not been verified.

`analysis.R` uses the following CRAN packages:

- `dplyr`
- `ggplot2`
- `ggrepel`
- `ggtext`
- `openxlsx`

The `grid` package ships with R. Missing CRAN packages are installed by the script from CRAN.

Every successful run writes the actual runtime information to:

```text
results/sessionInfo.txt
```

Because R was not available in the packaging environment used to prepare this public archive, no `sessionInfo_tested.txt` has been fabricated or bundled. If the repository is validated on a reference machine before/after GitHub publication, the resulting `results/sessionInfo.txt` can be copied here as `sessionInfo_tested.txt` and committed as a permanent record of that tested environment.
