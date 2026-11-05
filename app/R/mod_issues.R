# Data issues: what was found, with where it comes from and what to do. Text in config/issues.csv.

SEV_COL <- c(High = "#E3002B", Medium = "#AA5628", Low = "#636466")
STAT_COL <- c(Open = "#7F1724", Documented = "#004670", Handled = "#035537")

issues_ui <- function(id, d) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    page_intro("Data issues", "What was found while auditing the merge, where it comes from and what to do. Open issues change results until they are fixed in the pipeline.", "exclamation-triangle"),
    bslib::layout_columns(
      col_widths = c(5, 5, 2), class = "filters",
      shiny::radioButtons(ns("severity"), "Severity", c("All", "High", "Medium", "Low"), inline = TRUE),
      shiny::radioButtons(ns("state"), "Status", c("All", "Open", "Documented", "Handled"), inline = TRUE),
      htmltools::div(class = "issue-count", shiny::textOutput(ns("count"), inline = TRUE))
    ),
    shiny::uiOutput(ns("cards"))
  )
}

issues_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    shown <- shiny::reactive({
      x <- d$issues
      if (!identical(input$severity, "All") && !is.null(input$severity)) x <- x[x$severity == input$severity, ]
      if (!identical(input$state, "All") && !is.null(input$state)) x <- x[x$status == input$state, ]
      x
    })
    output$count <- shiny::renderText(sprintf("%d of %d issues", nrow(shown()), nrow(d$issues)))
    output$cards <- shiny::renderUI({
      x <- shown()
      if (!nrow(x)) return(htmltools::p(class = "text-muted", "No issue matches these filters."))
      htmltools::div(class = "issue-grid", lapply(seq_len(nrow(x)), function(i) {
        r <- x[i, ]
        htmltools::div(class = "issue-card", style = sprintf("border-top-color:%s", SEV_COL[[r$severity]]),
                       htmltools::div(class = "d-flex justify-content-between gap-2 align-items-start",
                                      htmltools::h5(r$title),
                                      htmltools::div(class = "d-flex gap-1 flex-wrap justify-content-end", pill(r$severity, SEV_COL[[r$severity]]), pill(r$status, STAT_COL[[r$status]]))),
                       htmltools::div(class = "issue-rounds", bsicons::bs_icon("calendar3"), " ", r$rounds),
                       htmltools::p(class = "small", r$found),
                       htmltools::div(class = "issue-fix", bsicons::bs_icon("wrench"), " ", r$handling),
                       htmltools::div(class = "issue-where", bsicons::bs_icon("file-earmark-code"), " ", r$where))
      }))
    })
  })
}
