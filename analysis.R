# ==============================================================================
# GUCA2A and MS4A12 polymorphism prioritization
# ==============================================================================
# Reproducible analysis accompanying:
# "GUCA2A and MS4A12 Predicted Deleterious Polymorphisms: Prioritization and
#  Association with Colorectal Cancer"
#
# Genome build: GRCh38
# Functional score: CADD PHRED (v1.7 in the accepted manuscript analysis)
# Polymorphism Selection Index (PSI): MAF * CADD
# Publication-matched definition: MAF is the retained Ensembl minor-allele
# frequency annotation; CADD is matched to the exact GRCh38 Ref/Alt row.
# MAF is not converted to alternate-allele frequency.
#
# This script uses the archived, manually checked annotation files and archived
# CADD results used for the accepted manuscript. That keeps the analysis reproducible even if
# Ensembl/dbSNP annotations change later.
#
# Run from R/RStudio with:
#   source("analysis.R")
#
# Outputs are written to:
#   results/figures/
#   results/tables/
#   results/cadd_input/
#
# This repository is self-contained: keep analysis.R next to the data/ folder.
# Legacy layouts using a GUCA2A_MS4A12_required_inputs/ subfolder are also supported.
# ==============================================================================

# ---- Package setup ------------------------------------------------------------

cran_packages <- c(
  "dplyr",
  "ggplot2",
  "ggrepel",
  "ggtext",
  "openxlsx"
)

missing_packages <- cran_packages[
  !vapply(cran_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(ggrepel)
  library(ggtext)
  library(openxlsx)
})

# grid ships with R and is used for arrow/unit objects in the plots.
library(grid)


# ---- Project paths ------------------------------------------------------------

# Try to determine the location of this script without relying on setwd().
# This supports Rscript, source(), the RStudio Source button, and (when
# rstudioapi is available) running code from the active RStudio document.
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) > 0) {
    script_file <- sub("^--file=", "", file_arg[1])
    if (file.exists(script_file)) {
      return(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)))
    }
  }

  # source() stores the file path in an 'ofile' field, but not necessarily
  # in sys.frames()[[1]]. Search all active frames from newest to oldest.
  frames <- sys.frames()
  if (length(frames) > 0) {
    for (i in rev(seq_along(frames))) {
      source_file <- tryCatch(frames[[i]]$ofile, error = function(e) NULL)
      if (!is.null(source_file) && length(source_file) == 1 && file.exists(source_file)) {
        return(dirname(normalizePath(source_file, winslash = "/", mustWork = TRUE)))
      }
    }
  }

  # Helpful when the user selects code in an open RStudio script and presses Run.
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    active_file <- tryCatch(
      rstudioapi::getActiveDocumentContext()$path,
      error = function(e) ""
    )
    if (nzchar(active_file) && file.exists(active_file)) {
      return(dirname(normalizePath(active_file, winslash = "/", mustWork = TRUE)))
    }
  }

  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

has_expected_input_tree <- function(path) {
  dir.exists(file.path(path, "data", "raw")) &&
    dir.exists(file.path(path, "data", "curated")) &&
    dir.exists(file.path(path, "data", "cadd"))
}

# Locate the archived input folder. The public repository uses the primary layout:
#
#      project/
#        analysis.R
#        data/
#
# Older local copies that placed data under a
# GUCA2A_MS4A12_required_inputs/ subfolder remain supported for backward
# compatibility. If neither direct layout is found, the function searches below
# the script/current directory for that legacy folder name.
find_project_paths <- function() {
  script_dir <- get_script_dir()
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  roots <- unique(c(script_dir, cwd))

  for (root in roots) {
    # Primary public-repository layout: analysis.R is next to data/.
    if (has_expected_input_tree(root)) {
      return(list(project_dir = root, input_dir = root))
    }

    # Legacy layout: analysis.R is next to GUCA2A_MS4A12_required_inputs/.
    adjacent <- file.path(root, "GUCA2A_MS4A12_required_inputs")
    if (has_expected_input_tree(adjacent)) {
      return(list(project_dir = root, input_dir = adjacent))
    }
  }

  # Fallback: search subdirectories under the script directory and working
  # directory. We only accept a folder with the exact expected name and tree.
  matches <- character(0)
  for (root in roots) {
    dirs <- tryCatch(
      list.dirs(root, recursive = TRUE, full.names = TRUE),
      error = function(e) character(0)
    )
    dirs <- dirs[basename(dirs) == "GUCA2A_MS4A12_required_inputs"]
    dirs <- dirs[vapply(dirs, has_expected_input_tree, logical(1))]
    matches <- c(matches, dirs)
  }

  matches <- unique(normalizePath(matches, winslash = "/", mustWork = TRUE))

  if (length(matches) == 1) {
    return(list(
      project_dir = dirname(matches[1]),
      input_dir = matches[1]
    ))
  }

  if (length(matches) > 1) {
    stop(
      "More than one GUCA2A_MS4A12_required_inputs folder was found.\n",
      "Please keep only the intended project copy under the current folder, or ",
      "open the intended repository folder in RStudio before running analysis.R.\n\n",
      paste0("  - ", matches, collapse = "\n"),
      call. = FALSE
    )
  }

  stop(
    "Could not locate the required input data.\n\n",
    "Recommended public-repository layout:\n",
    "  project/\n",
    "    analysis.R\n",
    "    data/raw/\n",
    "    data/curated/\n",
    "    data/cadd/\n\n",
    "Legacy layouts using a GUCA2A_MS4A12_required_inputs/ subfolder ",
    "are also supported.\n\n",
    "Do not paste the whole script into the Console. Use the Source button or ",
    "source(\"analysis.R\") so R can identify the script location.",
    call. = FALSE
  )
}

paths <- find_project_paths()
PROJECT_DIR <- paths$project_dir
INPUT_DIR <- paths$input_dir

message("Project directory: ", PROJECT_DIR)
message("Input directory:   ", INPUT_DIR)

RAW_DIR     <- file.path(INPUT_DIR, "data", "raw")
CURATED_DIR <- file.path(INPUT_DIR, "data", "curated")
CADD_DIR    <- file.path(INPUT_DIR, "data", "cadd")

RESULTS_DIR    <- file.path(PROJECT_DIR, "results")
FIGURES_DIR    <- file.path(RESULTS_DIR, "figures")
TABLES_DIR     <- file.path(RESULTS_DIR, "tables")
CADD_INPUT_DIR <- file.path(RESULTS_DIR, "cadd_input")

invisible(lapply(
  c(RESULTS_DIR, FIGURES_DIR, TABLES_DIR, CADD_INPUT_DIR),
  dir.create,
  recursive = TRUE,
  showWarnings = FALSE
))


# ---- Files used in the accepted manuscript analysis --------------------------

files <- list(
  ms4a12_raw       = file.path(RAW_DIR, "MS4A12_SNPs_dbSNP.txt"),
  guca2a_raw       = file.path(RAW_DIR, "GUCA2A_SNPs_dbSNP.txt"),
  ms4a12_curated   = file.path(CURATED_DIR, "MS4A12_curated_annotations.xlsx"),
  guca2a_curated   = file.path(CURATED_DIR, "GUCA2A_curated_annotations.xlsx"),
  ms4a12_cadd      = file.path(CADD_DIR, "MS4A12_CADD_results.tsv"),
  guca2a_cadd      = file.path(CADD_DIR, "GUCA2A_CADD_results.tsv")
)

missing_files <- unlist(files)[!file.exists(unlist(files))]
if (length(missing_files) > 0) {
  stop(
    "Required input file(s) not found:\n",
    paste0("  - ", missing_files, collapse = "\n"),
    call. = FALSE
  )
}


# ---- Fixed gene metadata used for the manuscript figures ---------------------
# Keeping these coordinates fixed is intentional: querying a live annotation
# service can produce different coordinates/metadata in the future.

gene_meta <- list(
  MS4A12 = list(
    chromosome = 11L,
    chromosome_label = "chr11",
    gene_start = 60492778L,
    gene_end = 60507430L,
    strand = "+",
    tick_by = 2000L
  ),
  GUCA2A = list(
    chromosome = 1L,
    chromosome_label = "chr1",
    gene_start = 42162690L,
    gene_end = 42164746L,
    strand = "-",
    tick_by = 1000L
  )
)


# ---- Small validation helpers -------------------------------------------------

check_columns <- function(data, required, object_name) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(
      object_name, " is missing required column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

read_raw_dbsnp <- function(path) {
  read.delim(
    path,
    sep = "\t",
    header = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    comment.char = ""
  )
}


# ---- Check the archived dbSNP exports -----------------------------------------
# The text exports contain repeated rows for some records. The counts reported
# here are therefore based on unique rsIDs after keeping SNVs only.

ms4a12_raw <- read_raw_dbsnp(files$ms4a12_raw)
guca2a_raw <- read_raw_dbsnp(files$guca2a_raw)

check_columns(ms4a12_raw, c("variant_type", "snp_id"), "MS4A12 dbSNP export")
check_columns(guca2a_raw, c("variant_type", "snp_id"), "GUCA2A dbSNP export")

ms4a12_unique_snvs <- ms4a12_raw %>%
  filter(variant_type == "snv") %>%
  transmute(snp_id = paste0("rs", snp_id)) %>%
  distinct()

guca2a_unique_snvs <- guca2a_raw %>%
  filter(variant_type == "snv") %>%
  transmute(snp_id = paste0("rs", snp_id)) %>%
  distinct()

message("Archived dbSNP SNVs: MS4A12 = ", nrow(ms4a12_unique_snvs),
        "; GUCA2A = ", nrow(guca2a_unique_snvs))


# ---- Read the manually checked annotation files -------------------------------

read_curated_annotations <- function(path, gene_name, meta) {
  x <- openxlsx::read.xlsx(path, sheet = 1, check.names = FALSE)

  required <- c(
    "refsnp_id",
    "allele",
    "Alt",
    "minor_allele",
    "minor_allele_freq",
    "consequence_type_tv",
    "chrom_start"
  )
  check_columns(x, required, paste(gene_name, "curated annotation"))

  x %>%
    mutate(
      Ref = sub("^([A-Z]).*", "\\1", allele),
      Alt = as.character(Alt),
      minor_allele_freq = as.numeric(minor_allele_freq),
      chrom_start = as.integer(chrom_start)
    ) %>%
    transmute(
      `SNP ID` = as.character(refsnp_id),
      `GRCh38 Pos` = chrom_start,
      Allele = as.character(allele),
      Ref = Ref,
      Alt = Alt,
      Minor = as.character(minor_allele),
      MAF = minor_allele_freq,
      Type = as.character(consequence_type_tv),
      Gene = gene_name,
      Chromosome = meta$chromosome,
      `Gene Start Pos` = meta$gene_start,
      `Gene End Pos` = meta$gene_end
    )
}

ms4a12_annotations <- read_curated_annotations(
  files$ms4a12_curated,
  "MS4A12",
  gene_meta$MS4A12
)

guca2a_annotations <- read_curated_annotations(
  files$guca2a_curated,
  "GUCA2A",
  gene_meta$GUCA2A
)


# ---- Write CADD input files ---------------------------------------------------
# These reproduce the 5-column files used for the external CADD scoring step.
# CADD itself is not queried automatically here; the archived v1.7 results are
# read below so the accepted manuscript analysis remains reproducible.

write_cadd_input <- function(data, output_path) {
  cadd_input <- data %>%
    select(Chromosome, `GRCh38 Pos`, `SNP ID`, Ref, Alt)

  write.table(
    cadd_input,
    file = output_path,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE,
    col.names = FALSE
  )
}

write_cadd_input(
  ms4a12_annotations,
  file.path(CADD_INPUT_DIR, "MS4A12_CADD_input.tsv")
)
write_cadd_input(
  guca2a_annotations,
  file.path(CADD_INPUT_DIR, "GUCA2A_CADD_input.tsv")
)


# ---- Read archived CADD results and calculate PSI -----------------------------

read_cadd_results <- function(path, gene_name) {
  x <- read.delim(
    path,
    sep = "\t",
    header = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  check_columns(x, c("Pos", "Ref", "Alt", "PHRED"), paste(gene_name, "CADD results"))

  x <- x %>%
    transmute(
      Pos = as.integer(Pos),
      Ref = as.character(Ref),
      Alt = as.character(Alt),
      PHRED = as.numeric(PHRED)
    )

  duplicated_keys <- x %>%
    count(Pos, Ref, Alt, name = "n") %>%
    filter(n > 1)

  if (nrow(duplicated_keys) > 0) {
    stop(
      gene_name,
      " CADD results contain duplicate Pos/Ref/Alt keys. Please check the input file.",
      call. = FALSE
    )
  }

  x
}

calculate_psi <- function(annotation_data, cadd_data, gene_name) {
  out <- annotation_data %>%
    left_join(
      cadd_data,
      by = c("GRCh38 Pos" = "Pos", "Ref" = "Ref", "Alt" = "Alt")
    ) %>%
    rename(CADD = PHRED) %>%
    mutate(
      CADD = as.numeric(CADD),
      PSI = round(MAF * CADD, 4)
    )

  missing_cadd <- out %>% filter(is.na(CADD))
  if (nrow(missing_cadd) > 0) {
    stop(
      gene_name, " has ", nrow(missing_cadd),
      " annotation row(s) without an exact CADD Pos/Ref/Alt match: ",
      paste(missing_cadd$`SNP ID`, collapse = ", "),
      call. = FALSE
    )
  }

  if (any(!is.finite(out$PSI))) {
    stop(gene_name, " contains non-finite PSI values.", call. = FALSE)
  }

  out
}

ms4a12_cadd <- read_cadd_results(files$ms4a12_cadd, "MS4A12")
guca2a_cadd <- read_cadd_results(files$guca2a_cadd, "GUCA2A")

ms4a12_psi <- calculate_psi(ms4a12_annotations, ms4a12_cadd, "MS4A12")
guca2a_psi <- calculate_psi(guca2a_annotations, guca2a_cadd, "GUCA2A")

message(
  "PSI rows: MS4A12 = ", nrow(ms4a12_psi),
  " allele-specific rows (", dplyr::n_distinct(ms4a12_psi$`SNP ID`), " unique rsIDs); ",
  "GUCA2A = ", nrow(guca2a_psi),
  " allele-specific rows (", dplyr::n_distinct(guca2a_psi$`SNP ID`), " unique rsIDs)."
)


# ---- Plotting -----------------------------------------------------------------

make_gene_plot <- function(psi_data, gene_name, meta, top_n = 10L) {
  gene_start <- meta$gene_start
  gene_end <- meta$gene_end
  strand <- meta$strand
  chromosome <- meta$chromosome_label

  polymorphisms <- psi_data %>%
    select(`GRCh38 Pos`, PSI, `SNP ID`) %>%
    rename(
      position = `GRCh38 Pos`,
      risk = PSI,
      snp_id = `SNP ID`
    ) %>%
    filter(!is.na(risk), risk > 0) %>%
    arrange(desc(risk)) %>%
    mutate(
      rank = row_number(),
      ypos = rep(c(-0.4, 0.4), length.out = n()),
      log_risk = log2(risk)
    ) %>%
    arrange(position)

  if (nrow(polymorphisms) == 0) {
    stop("No positive PSI values available for ", gene_name, ".", call. = FALSE)
  }

  if (strand == "+") {
    upstream_start <- gene_start - 2000L
    upstream_end <- gene_start - 1L
    downstream_start <- gene_end + 1L
    downstream_end <- gene_end + 500L
  } else {
    upstream_start <- gene_end + 1L
    upstream_end <- gene_end + 2000L
    downstream_start <- gene_start - 500L
    downstream_end <- gene_start - 1L
  }

  gene_body <- data.frame(
    xstart = if (strand == "+") gene_start else gene_end,
    xend = if (strand == "+") gene_end else gene_start
  )

  min_bound <- min(upstream_start, upstream_end, downstream_start, downstream_end, gene_start, gene_end)
  max_bound <- max(upstream_start, upstream_end, downstream_start, downstream_end, gene_start, gene_end)

  tick_start <- floor(min_bound / meta$tick_by) * meta$tick_by
  tick_end <- ceiling(max_bound / meta$tick_by) * meta$tick_by
  regular_ticks <- seq(tick_start, tick_end, by = meta$tick_by)
  regular_ticks <- regular_ticks[regular_ticks >= min_bound & regular_ticks <= max_bound]

  # Label both ends of the plotted interval and both gene boundaries.
  # Omit nearby regular ticks to avoid overlapping labels.
  essential_ticks <- sort(unique(c(min_bound, gene_start, gene_end, max_bound)))
  min_label_gap <- 0.055 * (max_bound - min_bound)
  spare_ticks <- regular_ticks[vapply(
    regular_ticks,
    function(x) all(abs(x - essential_ticks) >= min_label_gap),
    logical(1)
  )]
  x_ticks <- sort(unique(c(essential_ticks, spare_ticks)))

  x_labels <- vapply(x_ticks, function(x) {
    label <- format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
    # Emphasize the gene boundaries and the ends of the displayed interval.
    if (x %in% essential_ticks) paste0("**", label, "**") else label
  }, character(1))

  top_snps <- polymorphisms %>%
    arrange(desc(risk)) %>%
    slice_head(n = top_n)

  log_breaks <- seq(
    min(polymorphisms$log_risk),
    max(polymorphisms$log_risk),
    length.out = 5
  )
  log_breaks <- trunc(log_breaks * 10) / 10
  log_breaks <- unique(log_breaks)

  log_labels <- ifelse(
    log_breaks >= 0,
    sprintf("+%.1f", log_breaks),
    sprintf("%.1f", log_breaks)
  )

  # Use a common fill scale to label the three genomic regions.
  region_data <- data.frame(
    xmin = c(upstream_start, gene_start, downstream_start),
    xmax = c(upstream_end, gene_end, downstream_end),
    region = factor(
      c("Upstream (2000 bp)", "Gene body", "Downstream (500 bp)"),
      levels = c("Upstream (2000 bp)", "Gene body", "Downstream (500 bp)")
    )
  )

  p <- ggplot() +
    geom_rect(
      data = region_data,
      aes(xmin = xmin, xmax = xmax, ymin = -1, ymax = 1, fill = region),
      inherit.aes = FALSE
    ) +
    scale_fill_manual(
      name = "Genomic region",
      values = c(
        "Upstream (2000 bp)" = "#B3E5FC",
        "Gene body" = "#FFECB3",
        "Downstream (500 bp)" = "#C8E6C9"
      ),
      guide = guide_legend(order = 1)
    ) +
    geom_rect(
      aes(xmin = gene_start, xmax = gene_end, ymin = -1, ymax = 1),
      fill = NA,
      color = "orange",
      linewidth = 0.5,
      inherit.aes = FALSE
    ) +
    geom_segment(
      data = gene_body,
      aes(x = xstart, xend = xend, y = 0, yend = 0),
      linewidth = 2,
      color = "darkorange",
      arrow = arrow(type = "closed", length = unit(0.25, "inches"))
    ) +
    geom_point(
      data = polymorphisms,
      aes(x = position, y = ypos, color = log_risk, size = risk),
      shape = 16,
      alpha = 0.9
    ) +
    scale_color_gradientn(
      colors = c("#4575B4", "#91BFDB", "#FC8D59", "#D73027"),
      name = "PSI\n(log scale)",
      breaks = log_breaks,
      labels = log_labels,
      guide = guide_colorbar(barheight = unit(3, "cm"), order = 2)
    ) +
    scale_size_continuous(range = c(1.5, 5), guide = "none") +
    scale_x_continuous(
      breaks = x_ticks,
      labels = x_labels,
      expand = expansion(mult = c(0.05, 0.07))
    ) +
    coord_cartesian(ylim = c(-1.2, 1.2), clip = "off") +
    geom_vline(
      xintercept = c(upstream_start, upstream_end, gene_start, gene_end, downstream_start, downstream_end),
      linetype = "dashed",
      alpha = 0.8,
      color = "gray40",
      linewidth = 0.5
    ) +
    geom_vline(
      xintercept = regular_ticks,
      linetype = "dotted",
      alpha = 0.5,
      color = "gray60",
      linewidth = 0.3
    ) +
    theme_minimal(base_size = 14.5) +
    theme(
      axis.text.x = ggtext::element_markdown(angle = 45, hjust = 1, size = 12.25),
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.ticks.x = element_line(color = "gray50", linewidth = 0.5),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line.x = element_line(color = "black", linewidth = 0.6),
      plot.title = element_text(
        hjust = 0.5,
        face = "bold",
        size = 17.5,
        margin = margin(b = 12)
      ),
      legend.position = "right",
      legend.key.height = unit(1.2, "cm"),
      legend.key.width = unit(0.4, "cm"),
      legend.text = element_text(size = 11.5),
      legend.title = element_text(size = 12.5, face = "bold"),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(t = 10, r = 15, b = 14, l = 28)
    ) +
    labs(
      title = paste("Polymorphisms around", gene_name, "Gene on", chromosome),
      x = bquote(bold("Genomic Position on " ~ .(chromosome))),
      y = NULL
    )

  if (nrow(top_snps) > 0) {
    p <- p +
      ggrepel::geom_text_repel(
        data = top_snps,
        aes(x = position, y = ypos, label = snp_id),
        size = 3.5,
        box.padding = 0.3,
        point.padding = 0.15,
        min.segment.length = 0.05,
        max.iter = 200000,
        force = 0.8,
        nudge_y = ifelse(top_snps$ypos > 0, 0.25, -0.25),
        color = "darkred",
        fontface = "bold",
        segment.color = "gray50",
        segment.linetype = "dashed",
        segment.size = 0.5,
        segment.alpha = 0.8,
        bg.color = "white",
        bg.r = 0.15,
        seed = 42
      )
  }

  p
}

p_ms4a12 <- make_gene_plot(ms4a12_psi, "MS4A12", gene_meta$MS4A12)
p_guca2a <- make_gene_plot(guca2a_psi, "GUCA2A", gene_meta$GUCA2A)

# Save figures in both vector and high-resolution raster formats.
ggsave(
  file.path(FIGURES_DIR, "gene_polymorphisms_chr11_ms4a12.pdf"),
  plot = p_ms4a12,
  width = 15,
  height = 5,
  units = "in"
)
ggsave(
  file.path(FIGURES_DIR, "gene_polymorphisms_chr11_ms4a12.png"),
  plot = p_ms4a12,
  width = 15,
  height = 5,
  units = "in",
  dpi = 600
)

ggsave(
  file.path(FIGURES_DIR, "gene_polymorphisms_chr1_guca2a.pdf"),
  plot = p_guca2a,
  width = 15,
  height = 5,
  units = "in"
)
ggsave(
  file.path(FIGURES_DIR, "gene_polymorphisms_chr1_guca2a.png"),
  plot = p_guca2a,
  width = 15,
  height = 5,
  units = "in",
  dpi = 600
)


# ---- Combined figures ---------------------------------------------------------

# The standalone figures retain their titles and full legends. Combined panels
# use only the A/B labels and share one key for the genomic regions.
p_guca2a_A <- p_guca2a +
  labs(title = NULL, tag = "A") +
  guides(fill = "none") +
  theme(
    plot.tag = element_text(face = "bold", size = 23),
    plot.tag.position = c(0.012, 0.98)
  )

p_ms4a12_B <- p_ms4a12 +
  labs(title = NULL, tag = "B") +
  guides(fill = "none") +
  theme(
    plot.tag = element_text(face = "bold", size = 23),
    plot.tag.position = c(0.012, 0.98)
  )

region_labels <- c("Upstream (2000 bp)", "Gene body", "Downstream (500 bp)")
region_colors <- c("#B3E5FC", "#FFECB3", "#C8E6C9")

# Version 1: a vertical genomic-region key between the two PSI colorbars.
draw_region_key_vertical <- function() {
  grid::grid.text(
    "Genomic region", x = grid::unit(0.05, "in"), y = 0.88,
    just = c("left", "top"),
    gp = grid::gpar(fontsize = 12.5, fontface = "bold")
  )
  for (i in seq_along(region_labels)) {
    key_y <- c(0.61, 0.39, 0.17)[i]
    grid::grid.rect(
      x = grid::unit(0.16, "in"), y = key_y,
      width = grid::unit(0.18, "in"), height = grid::unit(0.18, "in"),
      gp = grid::gpar(fill = region_colors[i], col = "grey65")
    )
    grid::grid.text(
      region_labels[i], x = grid::unit(0.34, "in"), y = key_y,
      just = "left", gp = grid::gpar(fontsize = 11.5)
    )
  }
}

# Version 2: the same shared key on a single row below both panels.
# The row occupies only half an inch, leaving the plot area nearly unchanged.
draw_region_key_horizontal <- function() {
  grid::grid.text(
    "Genomic region", x = 0.14, y = 0.53, just = "left",
    gp = grid::gpar(fontsize = 12.5, fontface = "bold")
  )
  box_x <- c(0.31, 0.53, 0.68)
  text_x <- c(0.33, 0.55, 0.70)
  for (i in seq_along(region_labels)) {
    grid::grid.rect(
      x = box_x[i], y = 0.53,
      width = grid::unit(0.18, "in"), height = grid::unit(0.18, "in"),
      gp = grid::gpar(fill = region_colors[i], col = "grey65")
    )
    grid::grid.text(
      region_labels[i], x = text_x[i], y = 0.53,
      just = "left", gp = grid::gpar(fontsize = 11.5)
    )
  }
}

# Each gene retains its own PSI scale because the plotted ranges differ.
get_psi_legend <- function(p) {
  plot_grob <- ggplot2::ggplotGrob(p)
  guide_names <- c("guide-box-right", "guide-box")
  for (guide_name in guide_names) {
    idx <- match(guide_name, plot_grob$layout$name)
    if (!is.na(idx) && !inherits(plot_grob$grobs[[idx]], "zeroGrob")) {
      return(plot_grob$grobs[[idx]])
    }
  }
  stop("Could not extract the PSI legend for the combined figure.")
}

# Compact right-hand column: PSI (A), genomic regions, PSI (B).
draw_combined_figure <- function() {
  psi_A <- get_psi_legend(p_guca2a_A)
  psi_B <- get_psi_legend(p_ms4a12_B)
  plot_A <- p_guca2a_A + theme(legend.position = "none")
  plot_B <- p_ms4a12_B + theme(legend.position = "none")

  grid::grid.newpage()
  grid::pushViewport(grid::viewport(
    layout = grid::grid.layout(
      nrow = 2, ncol = 2,
      widths = grid::unit.c(grid::unit(1, "null"), grid::unit(1.95, "in")),
      heights = grid::unit(c(1, 1), "null")
    )
  ))

  print(plot_A, newpage = FALSE,
        vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
  print(plot_B, newpage = FALSE,
        vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))

  grid::pushViewport(grid::viewport(
    layout.pos.row = 1:2, layout.pos.col = 2,
    layout = grid::grid.layout(
      nrow = 3, ncol = 1,
      heights = grid::unit.c(
        grid::unit(1, "null"), grid::unit(1.65, "in"), grid::unit(1, "null")
      )
    )
  ))
  grid::pushViewport(grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
  grid::grid.draw(psi_A)
  grid::popViewport()
  grid::pushViewport(grid::viewport(layout.pos.row = 2, layout.pos.col = 1))
  draw_region_key_vertical()
  grid::popViewport()
  grid::pushViewport(grid::viewport(layout.pos.row = 3, layout.pos.col = 1))
  grid::grid.draw(psi_B)
  grid::popViewport(3)
}

# Alternative layout: the original right-side PSI legends and a short shared
# genomic-region key at the bottom. No extra horizontal legend column is added.
draw_combined_figure_region_bottom <- function() {
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(
    layout = grid::grid.layout(
      nrow = 3, ncol = 1,
      heights = grid::unit.c(
        grid::unit(1, "null"), grid::unit(1, "null"), grid::unit(0.5, "in")
      )
    )
  ))
  print(p_guca2a_A, newpage = FALSE,
        vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
  print(p_ms4a12_B, newpage = FALSE,
        vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))
  grid::pushViewport(grid::viewport(layout.pos.row = 3, layout.pos.col = 1))
  draw_region_key_horizontal()
  grid::popViewport(2)
}

# Both layouts are exported at the same size and resolution.
save_combined_figure <- function(filename, draw_fun) {
  output <- file.path(FIGURES_DIR, filename)

  grDevices::png(paste0(output, ".png"), width = 15, height = 11,
                 units = "in", res = 600, bg = "white")
  tryCatch(draw_fun(), finally = grDevices::dev.off())

  grDevices::pdf(paste0(output, ".pdf"), width = 15, height = 11,
                 onefile = FALSE, useDingbats = FALSE)
  tryCatch(draw_fun(), finally = grDevices::dev.off())

  if (capabilities("tiff")) {
    grDevices::tiff(paste0(output, ".tif"), width = 15, height = 11,
                    units = "in", res = 600, compression = "lzw", bg = "white")
    tryCatch(draw_fun(), finally = grDevices::dev.off())
  }
}

# A = GUCA2A (upper panel); B = MS4A12 (lower panel).
save_combined_figure(
  "Figure_AB_GUCA2A_MS4A12_600dpi",
  draw_combined_figure
)
save_combined_figure(
  "Figure_AB_GUCA2A_MS4A12_region_bottom_600dpi",
  draw_combined_figure_region_bottom
)

# ---- Supplementary PSI tables ------------------------------------------------

make_supplementary_table <- function(psi_data) {
  psi_data %>%
    transmute(
      `SNP ID` = `SNP ID`,
      Type = tools::toTitleCase(gsub("_", " ", Type)),
      Allele = paste0(Ref, ">", Alt),
      MAF = round(MAF, 3),
      CADD = round(CADD, 2),
      PSI = PSI
    ) %>%
    arrange(desc(PSI))
}

ms4a12_supplement <- make_supplementary_table(ms4a12_psi)
guca2a_supplement <- make_supplementary_table(guca2a_psi)

openxlsx::write.xlsx(
  ms4a12_supplement,
  file.path(TABLES_DIR, "MS4A12_SNPs_PSI.xlsx"),
  rowNames = FALSE,
  overwrite = TRUE
)

openxlsx::write.xlsx(
  guca2a_supplement,
  file.path(TABLES_DIR, "GUCA2A_SNPs_PSI.xlsx"),
  rowNames = FALSE,
  overwrite = TRUE
)

# Plain-text copies are useful for Git diffs and automated workflows.
write.csv(
  ms4a12_supplement,
  file.path(TABLES_DIR, "MS4A12_SNPs_PSI.csv"),
  row.names = FALSE
)
write.csv(
  guca2a_supplement,
  file.path(TABLES_DIR, "GUCA2A_SNPs_PSI.csv"),
  row.names = FALSE
)


# ---- Final checks -------------------------------------------------------------

ms4a12_top <- ms4a12_supplement %>% slice_head(n = 1)
guca2a_top <- guca2a_supplement %>% slice_head(n = 1)

if (ms4a12_top$`SNP ID` != "rs2298553") {
  warning("Top MS4A12 PSI variant is not rs2298553. Please inspect the inputs.")
}
if (guca2a_top$`SNP ID` != "rs2071499") {
  warning("Top GUCA2A PSI variant is not rs2071499. Please inspect the inputs.")
}

capture.output(sessionInfo(), file = file.path(RESULTS_DIR, "sessionInfo.txt"))

message("\nAnalysis finished successfully.")
message("Top MS4A12 variant: ", ms4a12_top$`SNP ID`, " (PSI = ", ms4a12_top$PSI, ")")
message("Top GUCA2A variant: ", guca2a_top$`SNP ID`, " (PSI = ", guca2a_top$PSI, ")")
message("Results saved in: ", RESULTS_DIR)
