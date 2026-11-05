# Rounds: fieldwork calendar, file inventory, and where each round was carried out.

rounds_ui <- function(id, d) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    page_intro("Survey rounds", "When each round took place, what its file holds and where households were surveyed.", "calendar3"),
    bslib::card(full_screen = TRUE, bslib::card_header("Fieldwork calendar"), plotly::plotlyOutput(ns("calendar"), height = "340px"),
                bslib::card_footer(class = "table-note", "Bars run from the 1st to the 99th percentile of interview dates, so that isolated wrong dates do not stretch them.")),
    bslib::card(full_screen = TRUE, bslib::card_header("Inventory"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("inventory")))),
    bslib::card(full_screen = TRUE, bslib::card_header("Households by department and round"), plotly::plotlyOutput(ns("departments"), height = "640px"),
                bslib::card_footer(class = "table-note", "Blank: not surveyed. <30: fewer than 30 households, count not shown."))
  )
}

rounds_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    r <- d$rounds

    output$calendar <- plotly::renderPlotly({
      x <- r[order(r$round, decreasing = TRUE), ]
      shapes <- lapply(seq_len(nrow(x)), function(i) list(type = "rect", xref = "x", yref = "y", x0 = as.character(x$date_p01[i]), x1 = as.character(as.Date(x$date_p99[i]) + 12),
                                                          y0 = i - 1.34, y1 = i - 0.66, fillcolor = SERIES_COL[[x$series[i]]], line = list(width = 0)))
      plotly::plot_ly() |>
        plotly::add_markers(x = as.character(x$date_median), y = x$label, marker = list(color = unname(SERIES_COL[x$series]), size = 7), showlegend = FALSE,
                            text = sprintf("<b>%s</b><br>%s<br>%s households", x$label, fmt_dates(x$date_p01, x$date_p99), fmt_int(x$final_rows)), hoverinfo = "text") |>
        plotly_style(legend = FALSE, shapes = shapes, margin = list(t = 40, r = 20, b = 30, l = 10),
                     xaxis = list(type = "date", title = "", dtick = "M12", tickformat = "%Y", side = "top"),
                     yaxis = list(title = "", type = "category", categoryorder = "array", categoryarray = x$label),
                     annotations = list(list(xref = "paper", yref = "paper", x = 0, y = 1.13, showarrow = FALSE, xanchor = "left",
                                             text = sprintf("<span style='color:%s'>■</span> Post-harvest   <span style='color:%s'>■</span> Lean season", COL$blue, COL$orange))))
    })

    output$inventory <- reactable::renderReactable({
      t <- data.frame(Round = r$label, Series = r$series, Fieldwork = fmt_dates(r$date_p01, r$date_p99), `Raw file` = r$raw_file, Households = r$final_rows,
                      Regions = r$regions, Departments = r$departments, Villages = r$villages, `GPS` = r$gps_pct, Dates = sprintf("%d / %d", r$dates_outside, r$dates_missing), check.names = FALSE)
      reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, striped = TRUE, class = "dark-table",
                           columns = list(Round = reactable::colDef(class = "cell-label", minWidth = 105), Series = reactable::colDef(minWidth = 90),
                                          Fieldwork = reactable::colDef(minWidth = 190), `Raw file` = reactable::colDef(minWidth = 240, style = list(fontSize = ".74rem")),
                                          Households = reactable::colDef(align = "right", minWidth = 88, format = reactable::colFormat(separators = TRUE)), Regions = reactable::colDef(align = "right", minWidth = 65), Departments = reactable::colDef(align = "right", minWidth = 98),
                                          Villages = reactable::colDef(align = "right", minWidth = 62), GPS = reactable::colDef(name = "GPS %", align = "right", minWidth = 58), Dates = reactable::colDef(name = "Dates outside / missing", align = "right", minWidth = 90)))
    })

    output$departments <- plotly::renderPlotly({
      a <- d$admin2
      a$department[is.na(a$department) | a$department == ""] <- "(no department)"
      a$rowlab <- paste0(a$region, " · ", a$department)
      rows <- sort(unique(a$rowlab)); lv <- as.character(r$label)
      a$rl <- as.character(r$label[match(a$round_id, r$round_id)])
      g <- function(col) tapply(a[[col]], list(factor(a$rowlab, levels = rows), factor(a$rl, levels = lv)), function(v) v[1])
      z <- g("households"); small <- g("small_cell")
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s", rep(rows, length(lv)), rep(lv, each = length(rows)),
                            ifelse(small %in% TRUE, "fewer than 30 households", ifelse(is.na(z), "not surveyed", paste(fmt_int(z), "households")))), nrow = length(rows))
      cell <- matrix(ifelse(small %in% TRUE, "<30", ifelse(is.na(z), "", fmt_int(z))), nrow = length(rows))
      zz <- z; zz[small %in% TRUE] <- 0
      round_heatmap(rows, lv, unname(zz), hov, cell, list(c(0, "#E6F2F8"), c(.25, "#89D1F4"), c(1, "#007DBC")), colorbar = FALSE)
    })
  })
}
