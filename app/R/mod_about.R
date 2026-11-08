# About: reproduce the dashboard, provenance of each input, and what is and is not in the app.

about_ui <- function(id, d) {
  ns <- shiny::NS(id)
  m <- d$manifest
  htmltools::tagList(
    page_intro("About", "What this dashboard is, how to refresh it, and where each figure comes from.", "info-circle"),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(bslib::card_header("What this is"),
                  htmltools::p(class = "small", "A view of the data merging process behind the cost-benefit analysis of WFP's resilience interventions in Chad, 2018 to 2023. It shows how 10 household survey rounds became one dataset, and how far the result can be trusted."),
                  htmltools::p(class = "small mb-0", "It reads the pipeline's files and changes none of them. Figures are preliminary, unweighted and are not official WFP results.")),
      bslib::card(bslib::card_header("Data statement"),
                  htmltools::tags$ul(class = "small mb-0",
                                     htmltools::tags$li("The app holds only aggregates and metadata: no household identifier, no village name, no GPS coordinate."),
                                     htmltools::tags$li(sprintf("Regional cells under %d households are suppressed. Department counts under %d are not shown.", m$min_cell, m$min_cell)),
                                     htmltools::tags$li("On a server, the app requires a login and refuses to start without accounts."),
                                     htmltools::tags$li("Check with the data owners (WFP) before sharing regional figures outside the team.")))
    ),
    bslib::card(bslib::card_header("Data assistant"),
                htmltools::p(class = "small", "An AI assistant answers questions in English or French on the same aggregates as this dashboard: how the data were merged, what is wrong or fixed, what the indicators show, and the costs per household. Each answer shows its table, its sources, and a link back to the page of this dashboard that holds the figures.",
                             " Code and setup: ", htmltools::tags$a(href = "https://github.com/Abson-dev/wfp-chad-data-assistant", target = "_blank", rel = "noopener", "github.com/Abson-dev/wfp-chad-data-assistant"), "."),
                htmltools::p(class = "small mb-0", if (nzchar(Sys.getenv("WFP_ASSISTANT_URL"))) htmltools::tagList("Open it: ", htmltools::tags$a(href = Sys.getenv("WFP_ASSISTANT_URL"), target = "_blank", rel = "noopener", Sys.getenv("WFP_ASSISTANT_URL")), ".")
                             else "It is not hosted yet: it runs on the team's computers (run_web.bat). Regional aggregates reach the Anthropic API when a question needs them, so hosting it for others waits for WFP's agreement.",
                             " Pages of this dashboard can be opened directly: add #page=costs (or merge, validation, issues, variables, trends, regions, assistance, process, crosswalk, rounds, data) to its address.")),
    bslib::card(bslib::card_header("Refresh after a change in the pipeline"),
                htmltools::p(class = "small", "After fixing the Rmds, the workbook or the do-files and rebuilding the merged file, from the app folder:"),
                htmltools::tags$pre(class = "code-block", "Rscript prepare_app_data.R     # recomputes all aggregates, checks and flags\nRscript tests/test_app.R        # tests every page and the data boundary\nrun_app.bat                     # opens the dashboard"),
                htmltools::p(class = "small mb-0", "Flags and checks are computed from the data, so a fix clears them by itself. The text of the Data issues page is in config/issues.csv: update it too, and a test warns if a stated figure no longer holds. If the merged file has a new name, update FINAL_FILE in prepare_app_data.R.")),
    bslib::card(full_screen = TRUE,
                bslib::card_header(sprintf("Inputs of this data refresh (%s UTC)", gsub("T|Z", " ", m$run_utc))),
                reactable::reactableOutput(ns("inputs")))
  )
}

about_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    output$inputs <- reactable::renderReactable({
      i <- d$manifest$inputs
      i$round <- as.character(d$rounds$label[match(i$round_id, d$rounds$round_id)])
      i$round[is.na(i$round)] <- ""
      reactable::reactable(i[, c("role", "round", "file", "size_mb", "modified", "sha256")], compact = TRUE, striped = TRUE, pagination = FALSE, searchable = TRUE,
                           columns = list(role = reactable::colDef(name = "Role", minWidth = 150), round = reactable::colDef(name = "Round", minWidth = 100), file = reactable::colDef(name = "File", minWidth = 320, style = list(fontSize = ".78rem")),
                                          size_mb = reactable::colDef(name = "MB", align = "right", minWidth = 60), modified = reactable::colDef(name = "Modified", minWidth = 90),
                                          sha256 = reactable::colDef(name = "SHA-256", minWidth = 180, cell = function(v) htmltools::span(title = v, style = "font-family:Consolas,monospace;font-size:.76rem", paste0(substr(v, 1, 16), "…")))))
    })
  })
}
