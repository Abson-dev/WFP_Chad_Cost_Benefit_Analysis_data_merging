# Installs the R packages the dashboard needs, if they are missing. Called by run_app.bat.
needed <- c("shiny", "bslib", "bsicons", "plotly", "reactable", "visNetwork", "shinyWidgets",
            "readr", "dplyr", "tidyr", "jsonlite", "htmltools", "writexl")
missing <- needed[!vapply(needed, requireNamespace, TRUE, quietly = TRUE)]
if (length(missing)) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
  still <- missing[!vapply(missing, requireNamespace, TRUE, quietly = TRUE)]
  if (length(still)) stop("Could not install: ", paste(still, collapse = ", "), call. = FALSE)
}
