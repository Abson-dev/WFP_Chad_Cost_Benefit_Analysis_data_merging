# Data: filter the aggregate indicators and download them. No household-level data here or anywhere in the app.

data_ui <- function(id, d) {
  ns <- shiny::NS(id)
  x <- d$ind_long
  htmltools::tagList(
    page_intro("Data", "Filter the aggregate indicators and download them. Household data stay in the pipeline's folders.", "download"),
    bslib::layout_columns(
      col_widths = c(4, 3, 3, 2), class = "filters",
      shinyWidgets::pickerInput(ns("indicators"), "Indicators", choices = IND$label, multiple = TRUE,
                                options = shinyWidgets::pickerOptions(actionsBox = TRUE, liveSearch = TRUE, noneSelectedText = "All", selectedTextFormat = "count > 2")),
      shinyWidgets::pickerInput(ns("geo"), "Area", choices = c("All surveyed households", sort(unique(x$geography[x$level == "Region"]))), multiple = TRUE,
                                options = shinyWidgets::pickerOptions(actionsBox = TRUE, noneSelectedText = "All", selectedTextFormat = "count > 2")),
      shinyWidgets::pickerInput(ns("rounds"), "Rounds", choices = as.character(d$rounds$label), multiple = TRUE,
                                options = shinyWidgets::pickerOptions(actionsBox = TRUE, noneSelectedText = "All", selectedTextFormat = "count > 2")),
      shiny::selectInput(ns("series"), "Series", c("Both" = "", "Post-harvest", "Lean season"))
    ),
    bslib::layout_columns(
      col_widths = c(8, 4),
      htmltools::div(class = "issue-count", shiny::textOutput(ns("count"), inline = TRUE)),
      htmltools::div(class = "buttons",
                     shiny::downloadButton(ns("csv"), "CSV", class = "btn-sm btn-outline-primary"),
                     shiny::downloadButton(ns("excel"), "Excel", class = "btn-sm btn-outline-primary"))
    ),
    bslib::card(full_screen = TRUE, reactable::reactableOutput(ns("table")),
                bslib::card_footer(class = "table-note", "Unweighted. Flagged: known defect in the merged value. With corrections: indicative value rebuilt from the raw files. Regional cells under 30 households are suppressed."))
  )
}

data_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    shown <- shiny::reactive({
      x <- d$ind_long
      if (length(input$indicators)) x <- x[x$indicator %in% input$indicators, ]
      if (length(input$geo)) x <- x[x$geography %in% input$geo, ]
      if (length(input$rounds)) x <- x[x$round %in% input$rounds, ]
      if (nzchar(input$series %||% "")) x <- x[x$series == input$series, ]
      x
    })
    output$count <- shiny::renderText(sprintf("%s of %s rows", fmt_int(nrow(shown())), fmt_int(nrow(d$ind_long))))
    output$table <- reactable::renderReactable({
      x <- shown()
      reactable::reactable(
        x[, c("geography", "round", "series", "indicator", "unit", "as_merged", "with_corrections", "flagged", "households")],
        compact = TRUE, striped = TRUE, defaultPageSize = 15, sortable = TRUE, defaultColDef = reactable::colDef(na = "–"),
        columns = list(geography = reactable::colDef(name = "Area", minWidth = 165), round = reactable::colDef(name = "Round", minWidth = 105), series = reactable::colDef(name = "Series", minWidth = 95),
                       indicator = reactable::colDef(name = "Indicator", minWidth = 280), unit = reactable::colDef(name = "Unit", minWidth = 60),
                       as_merged = reactable::colDef(name = "As merged", align = "right", minWidth = 75), with_corrections = reactable::colDef(name = "With corrections", align = "right", minWidth = 85),
                       flagged = reactable::colDef(name = "Flagged", align = "center", minWidth = 65, cell = function(v) if (isTRUE(v)) "†" else ""),
                       households = reactable::colDef(name = "Households", align = "right", minWidth = 85, format = reactable::colFormat(separators = TRUE)))
      )
    })
    output$csv <- shiny::downloadHandler(filename = function() "WFP_Chad_indicators.csv", content = function(file) readr::write_csv(shown(), file, na = ""))
    output$excel <- shiny::downloadHandler(filename = function() "WFP_Chad_indicators.xlsx", content = function(file) writexl::write_xlsx(shown(), file))
  })
}
