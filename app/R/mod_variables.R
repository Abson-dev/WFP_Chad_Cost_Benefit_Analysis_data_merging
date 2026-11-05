# Variables: every column of the merged file, with its completeness and distribution in each round.

VAR_FLAG_GROUP <- function(v) {
  if (grepl("^(FCS|fcs)", v)) "fcs"
  else if (grepl("^rCSI", v)) "rcsi"
  else if (grepl("^LhCSI|coping", v)) "lcs"
  else if (grepl("^ABI|^HHAsset|^HHTraining|^HHWork", v)) "abi"
  else if (grepl("^HHSize", v)) "hhsize"
  else NA_character_
}

variables_ui <- function(id, d) {
  ns <- shiny::NS(id)
  m <- d$merged_columns
  htmltools::tagList(
    page_intro("Variables", sprintf("All %d columns of the merged file. Select a row to see its completeness and distribution in each round.", nrow(m)), "list-columns-reverse"),
    bslib::layout_columns(
      col_widths = c(5, 3, 4), class = "filters",
      shiny::selectInput(ns("family"), "Group", c("All groups" = "", sort(unique(m$family)))),
      shiny::selectInput(ns("gaps"), "Rounds with data", c("All" = "", "All 10 rounds" = "full", "Fewer than 10" = "gaps", "One round only" = "one")),
      htmltools::div(class = "buttons",
                     shiny::downloadButton(ns("dl_list"), "Variable list (.csv)", class = "btn-sm btn-outline-primary"),
                     shiny::downloadButton(ns("dl_values"), "All distributions (.csv)", class = "btn-sm btn-outline-primary"))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header(shiny::textOutput(ns("count"), inline = TRUE)), reactable::reactableOutput(ns("table"))),
    shiny::uiOutput(ns("profile_head")),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(full_screen = TRUE, bslib::card_header("Distribution by round"), plotly::plotlyOutput(ns("dist"), height = "380px"),
                  bslib::card_footer(class = "table-note", shiny::textOutput(ns("dist_note"), inline = TRUE))),
      bslib::card(full_screen = TRUE, bslib::card_header("Completeness by round"), plotly::plotlyOutput(ns("cover"), height = "380px"),
                  bslib::card_footer(class = "table-note", "Share of households with an answer. Unweighted, for the households surveyed."))
    )
  )
}

variables_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    r <- d$rounds; lv <- as.character(r$label)
    lab <- function(rid) as.character(r$label[match(rid, r$round_id)])
    selected <- shiny::reactiveVal("FCS")

    shown <- shiny::reactive({
      x <- d$merged_columns
      if (nzchar(input$family %||% "")) x <- x[x$family == input$family, ]
      g <- input$gaps %||% ""
      if (g == "full") x <- x[x$rounds_with_data == 10, ]
      if (g == "gaps") x <- x[x$rounds_with_data < 10, ]
      if (g == "one") x <- x[x$rounds_with_data == 1, ]
      x
    })
    output$count <- shiny::renderText(sprintf("%d of %d columns", nrow(shown()), nrow(d$merged_columns)))
    output$table <- reactable::renderReactable({
      x <- shown()
      shiny::validate(shiny::need(nrow(x) > 0, "No column matches these filters."))
      reactable::reactable(
        x[, c("variable", "family", "label", "type", "rounds_with_data", "coverage")], searchable = TRUE, compact = TRUE, striped = TRUE, highlight = TRUE,
        defaultPageSize = 10, selection = "single", onClick = "select", rowStyle = list(cursor = "pointer"),
        columns = list(
          .selection = reactable::colDef(show = FALSE),
          variable = reactable::colDef(name = "Column", minWidth = 170, style = list(fontFamily = "Consolas, monospace", fontSize = ".78rem", fontWeight = 600)),
          family = reactable::colDef(name = "Group", minWidth = 160), label = reactable::colDef(name = "Label", minWidth = 380, style = list(fontSize = ".78rem")),
          type = reactable::colDef(name = "Type", minWidth = 62), rounds_with_data = reactable::colDef(name = "Rounds with data", align = "center", minWidth = 78),
          coverage = reactable::colDef(name = "% answered, all rounds", minWidth = 100, cell = coverage_bar)
        )
      )
    })
    shiny::observe({
      i <- reactable::getReactableState("table", "selected")
      shiny::req(i)
      selected(shown()$variable[i])
    })

    info <- shiny::reactive(d$merged_columns[d$merged_columns$variable == selected(), ])

    output$profile_head <- shiny::renderUI({
      a <- info()
      g <- VAR_FLAG_GROUP(a$variable)
      fl <- if (is.na(g)) d$flags[0, ] else d$flags[d$flags$indicator_group == g, ]
      bslib::card(
        class = "concept-card",
        bslib::card_header(class = "d-flex flex-wrap gap-2 align-items-center", htmltools::code(a$variable), pill(a$family, COL$navy),
                           pill(sprintf("%d / 10 rounds", a$rounds_with_data), if (a$rounds_with_data == 10) "#035537" else "#AA5628")),
        if (nzchar(a$label %||% "") && !is.na(a$label)) htmltools::p(class = "small mb-1", a$label),
        if (!is.na(a$value_labels)) htmltools::p(class = "small text-muted mb-1", htmltools::strong("Values: "), a$value_labels),
        if (a$kind == "hidden") callout(type = "info", "This column can identify households, so the dashboard shows its completeness only."),
        if (nrow(fl)) callout(type = "warning", htmltools::strong("Known defect in its module. "),
                              sprintf("%s: %s", paste(lab(fl$round_id), collapse = ", "), paste(unique(fl$reason), collapse = " ")))
      )
    })

    output$dist <- plotly::renderPlotly({
      a <- info(); v <- a$variable
      shiny::validate(shiny::need(a$kind != "hidden", "Distribution not shown for this column."))
      if (a$kind == "numeric") {
        x <- d$variable_numeric[d$variable_numeric$variable == v, ]
        shiny::validate(shiny::need(nrow(x) > 0, "No answers to show."))
        rl <- factor(lab(x$round_id), levels = lv)
        o <- order(rl); x <- x[o, ]; rl <- rl[o]
        return(plotly::plot_ly() |>
          plotly::add_ribbons(x = rl, ymin = x$p10, ymax = x$p90, name = "10th to 90th percentile", fillcolor = "rgba(0,125,188,.18)", line = list(width = 0), hoverinfo = "skip") |>
          plotly::add_trace(x = rl, y = x$median, type = "scatter", mode = "lines+markers", name = "Median", line = list(color = COL$blue, width = 2.5), marker = list(color = COL$blue, size = 8)) |>
          plotly::add_trace(x = rl, y = x$mean, type = "scatter", mode = "markers", name = "Mean", marker = list(color = COL$orange, size = 9, symbol = "diamond"),
                            text = sprintf("min %s, max %s, %s households", x$min, x$max, fmt_int(x$answered)), hovertemplate = "%{x}: mean %{y}<br>%{text}<extra></extra>") |>
          plotly_style(xaxis = list(tickangle = -30, categoryorder = "array", categoryarray = lv)))
      }
      x <- d$variable_values[d$variable_values$variable == v & !d$variable_values$suppressed, ]
      shiny::validate(shiny::need(nrow(x) > 0, "No answers to show."))
      # Keep the chart readable: the most common answers, the others grouped.
      tot <- tapply(x$households, x$label, sum)
      top <- names(sort(tot, decreasing = TRUE))[seq_len(min(8, length(tot)))]
      x$group <- ifelse(x$label %in% top, x$label, "Other answers")
      g <- stats::aggregate(pct ~ round_id + group, x, sum)
      pal <- c("#007DBC", "#F0512D", "#03924A", "#AA5628", "#950158", "#FAB219", "#002F5A", "#89D1F4", "#B1B3B6")
      groups <- c(top, if ("Other answers" %in% g$group) "Other answers")
      p <- plotly::plot_ly()
      for (k in seq_along(groups)) {
        s <- g[g$group == groups[k], ]
        p <- plotly::add_bars(p, x = factor(lab(s$round_id), levels = lv), y = s$pct, name = substr(groups[k], 1, 42), marker = list(color = pal[k], line = list(color = "#fff", width = .5)),
                              hovertemplate = paste0("%{x}<br>", gsub("%", "%%", substr(groups[k], 1, 60)), ": %{y:.1f}%<extra></extra>"))
      }
      p |> plotly_style(barmode = "stack", xaxis = list(tickangle = -30, categoryorder = "array", categoryarray = lv), yaxis = list(range = c(0, 100), ticksuffix = "%"), margin = list(t = 80))
    })
    output$dist_note <- shiny::renderText({
      a <- info()
      if (a$kind == "numeric") "Median, mean and the range of the middle 80% of households, by round."
      else if (a$kind == "hidden") "Hidden, as this column can identify households."
      else "Share of households who answered. Answers given by fewer than 5 households in a round are not shown, so bars can stop short of 100%."
    })

    output$cover <- plotly::renderPlotly({
      x <- d$column_coverage[d$column_coverage$variable == selected(), ]
      rl <- factor(lab(x$round_id), levels = lv)
      plotly::plot_ly(x = rl, y = x$pct, type = "bar", marker = list(color = ifelse(x$pct >= 95, "#74C48A", ifelse(x$pct > 0, "#ECE1B1", "#E9ECEF"))),
                      text = fmt_pct(x$pct, 0), textposition = "outside", cliponaxis = FALSE, hovertemplate = "%{x}: %{y:.1f}%<extra></extra>") |>
        plotly_style(legend = FALSE, margin = list(t = 26), xaxis = list(tickangle = -30, categoryorder = "array", categoryarray = lv), yaxis = list(range = c(0, 112), ticksuffix = "%"))
    })

    output$dl_list <- shiny::downloadHandler(filename = function() "WFP_Chad_merged_variables.csv", content = function(file) {
      readr::write_csv(d$merged_columns[, c("family", "variable", "label", "type", "kind", "rounds_with_data", "coverage", "value_labels")], file, na = "")
    })
    output$dl_values <- shiny::downloadHandler(filename = function() "WFP_Chad_merged_distributions.csv", content = function(file) {
      x <- d$variable_values; x$round <- lab(x$round_id)
      readr::write_csv(x[, c("variable", "round", "value", "label", "households", "answered", "pct", "suppressed")], file, na = "")
    })
  })
}
