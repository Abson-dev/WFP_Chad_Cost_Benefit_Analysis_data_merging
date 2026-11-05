# Crosswalk explorer: the harmonisation workbook made interactive, with coverage read from the raw files.

cov_fill <- function(v) {
  dplyr::case_when(is.na(v) ~ "#F1F3F5", v == 0 ~ "#FCDCD8", v < 95 ~ "#F5E9CE", TRUE ~ "#D5ECDD")
}

coverage_bar <- function(v) {
  if (is.na(v)) return("—")
  htmltools::div(class = "cov-bar",
                 htmltools::div(class = "cov-fill", style = sprintf("width:%s%%;background:%s", v, if (v >= 95) "#03924A" else if (v > 0) "#AA5628" else "#E3002B")),
                 htmltools::span(fmt_pct(v, 0)))
}

crosswalk_ui <- function(id, d) {
  ns <- shiny::NS(id)
  s <- d$crosswalk_summary
  fams <- unique(s$family)
  htmltools::tagList(
    page_intro("Crosswalk explorer",
               sprintf("Where each of the %d harmonised variables lives in each of the 10 rounds: source column, coverage, type and value labels. %d reach the merged file. Click a row for its profile.",
                       nrow(s), sum(s$in_final)), "table"),
    bslib::layout_sidebar(
      fillable = FALSE,
      sidebar = bslib::sidebar(
        width = 290, open = "desktop",
        shinyWidgets::pickerInput(ns("families"), "Groups", choices = fams, selected = setdiff(fams, c("Migration", "Social capital", "Savings and shocks", "Women's diet (MDDW)", "Child diet (MAD)", "Respondent")),
                                  multiple = TRUE, options = shinyWidgets::pickerOptions(actionsBox = TRUE, selectedTextFormat = "count > 3", countSelectedText = "{0} groups")),
        shiny::selectizeInput(ns("jump"), "Find a variable", choices = c("Type to search…" = "", stats::setNames(s$variable, s$variable))),
        shiny::checkboxInput(ns("gaps_only"), "Only variables missing in some rounds", FALSE),
        htmltools::hr(),
        htmltools::div(class = "legend-block", htmltools::strong("Coverage in the raw file"),
                       legend_row("#D5ECDD", "found, 95% or more answered"),
                       legend_row("#F5E9CE", "found, 1 to 95% (often a skip pattern)"),
                       legend_row("#FCDCD8", "variable exists but empty"),
                       legend_row("#F1F3F5", "no source in that round")),
        htmltools::hr(),
        shiny::downloadButton(ns("dl_xlsx"), "Crosswalk workbook (.xlsx)", class = "btn-sm btn-outline-primary w-100 mb-2"),
        shiny::downloadButton(ns("dl_csv"), "Filtered details (.csv)", class = "btn-sm btn-outline-secondary w-100")
      ),
      bslib::navset_card_underline(
        full_screen = TRUE,
        bslib::nav_panel("Coverage matrix", shiny::uiOutput(ns("matrix_ui"), style = "width:100%")),
        bslib::nav_panel("Crosswalk table", reactable::reactableOutput(ns("table"))),
        bslib::nav_panel("All variable details", reactable::reactableOutput(ns("details"))),
        bslib::nav_panel("Shared source columns", reactable::reactableOutput(ns("dups")))
      ),
      shiny::uiOutput(ns("concept_card"))
    )
  )
}

crosswalk_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    r <- d$rounds; lv <- as.character(r$label)
    selected <- shiny::reactiveVal("rCSIBorrow")

    vars_f <- shiny::reactive({
      x <- d$crosswalk_summary[d$crosswalk_summary$family %in% input$families, ]
      if (isTRUE(input$gaps_only)) x <- x[x$rounds_mapped < 10, ]
      x
    })
    details_f <- shiny::reactive(d$crosswalk[d$crosswalk$variable %in% vars_f()$variable, ])

    shiny::observeEvent(input$jump, if (nzchar(input$jump)) selected(input$jump), ignoreInit = TRUE)

    output$matrix_ui <- shiny::renderUI({
      plotly::plotlyOutput(ns("matrix"), width = "100%", height = paste0(190 + 17 * max(nrow(vars_f()), 1), "px"))
    })
    output$matrix <- plotly::renderPlotly({
      cf <- vars_f()
      shiny::validate(shiny::need(nrow(cf) > 0, "No variable matches the filters."))
      det <- details_f()
      z <- matrix(NA_real_, nrow(cf), length(lv), dimnames = list(cf$variable, lv))
      txt <- matrix("", nrow(cf), length(lv), dimnames = list(cf$variable, lv))
      for (i in seq_len(nrow(det))) {
        a <- det[i, ]; l <- as.character(a$label); v <- a$variable
        if (!is.na(a$source)) z[v, as.character(r$label[match(a$round_id, r$round_id)])] <- a$coverage
        txt[v, as.character(r$label[match(a$round_id, r$round_id)])] <- sprintf(
          "<b>%s</b> · %s<br>Source: <b>%s</b><br>Coverage: %s<br>Type: %s", v, r$label[match(a$round_id, r$round_id)],
          if (is.na(a$source)) "none" else substr(a$source, 1, 45), if (is.na(a$source)) "–" else fmt_pct(a$coverage), if (is.na(a$type)) "–" else a$type)
      }
      counts <- table(factor(cf$family, levels = unique(cf$family)))
      bounds <- unname(cumsum(as.integer(counts)))
      mids <- bounds - as.integer(counts) / 2
      shapes <- lapply(utils::head(bounds, -1), function(b) list(type = "line", xref = "paper", x0 = -0.01, x1 = 1, y0 = b - 0.5, y1 = b - 0.5, line = list(color = COL$navy, width = 1.5)))
      ann <- lapply(seq_along(mids), function(k) list(xref = "paper", x = 1.01, y = mids[k] - 0.5, xanchor = "left", showarrow = FALSE,
                                                      text = sprintf("<b>%s</b>", names(counts)[k]), font = list(size = 11, color = COL$navy)))
      plotly::plot_ly(x = lv, y = cf$variable, z = unname(z), type = "heatmap", source = ns("cov"), text = unname(txt), hovertemplate = "%{text}<extra></extra>",
                      xgap = 2, ygap = 1, colorscale = COVERAGE_SCALE, zmin = 0, zmax = 100, showscale = FALSE) |>
        plotly_style(legend = FALSE, plot_bgcolor = "#F1F3F5",
                     xaxis = list(side = "top", tickangle = -35, showgrid = FALSE, type = "category"),
                     yaxis = list(autorange = "reversed", showgrid = FALSE, tickfont = list(size = 10.5), type = "category"),
                     shapes = shapes, annotations = ann, margin = list(l = 10, r = 170, t = 70, b = 10)) |>
        plotly::event_register("plotly_click")
    })

    shiny::observe({
      ev <- plotly::event_data("plotly_click", source = ns("cov"))
      shiny::req(ev)
      if (ev$y %in% d$crosswalk_summary$variable) selected(ev$y)
    })

    output$table <- reactable::renderReactable({
      cf <- vars_f()
      shiny::validate(shiny::need(nrow(cf) > 0, "No variable matches the filters."))
      det <- details_f()
      det$round_label <- as.character(r$label[match(det$round_id, r$round_id)])
      src <- tidyr::pivot_wider(det[, c("variable", "round_label", "source")], names_from = round_label, values_from = source)
      cov <- tidyr::pivot_wider(det[, c("variable", "round_label", "coverage")], names_from = round_label, values_from = coverage)
      tbl <- merge(cf[, c("family", "variable", "rounds_mapped", "in_final")], src, by = "variable", sort = FALSE)
      tbl <- tbl[match(cf$variable, tbl$variable), c("family", "variable", "rounds_mapped", "in_final", lv)]
      covm <- as.data.frame(cov)[match(tbl$variable, cov$variable), ]
      round_cols <- stats::setNames(lapply(lv, function(rl) reactable::colDef(
        name = rl, minWidth = 140,
        cell = function(v) if (is.na(v)) "—" else v,
        style = function(v, i) { cv <- covm[[rl]][i]; list(background = cov_fill(cv), fontFamily = "Consolas, monospace", fontSize = "0.74em", color = if (is.na(cv)) "#939598" else COL$ink) })), lv)
      reactable::reactable(
        tbl, groupBy = "family", defaultExpanded = TRUE, compact = TRUE, bordered = TRUE, highlight = TRUE, pagination = FALSE, height = 620, searchable = TRUE,
        selection = "single", onClick = "select", rowStyle = list(cursor = "pointer"),
        theme = reactable::reactableTheme(headerStyle = list(background = COL$navy, color = "#fff")),
        columns = c(list(
          .selection = reactable::colDef(show = FALSE),
          family = reactable::colDef(name = "Group", minWidth = 150, sticky = "left"),
          variable = reactable::colDef(name = "Harmonised", minWidth = 170, sticky = "left", style = list(fontFamily = "Consolas, monospace", fontSize = "0.82em", fontWeight = 600)),
          rounds_mapped = reactable::colDef(name = "Rounds", minWidth = 62, align = "center", cell = function(v) paste0(v, "/10")),
          in_final = reactable::colDef(name = "In merged file", minWidth = 70, align = "center", cell = function(v) if (isTRUE(v)) "Yes" else "No")
        ), round_cols)
      )
    })
    shiny::observe({
      i <- reactable::getReactableState("table", "selected")
      shiny::req(i)
      selected(vars_f()$variable[i])
    })

    output$details <- reactable::renderReactable({
      x <- details_f()
      x <- data.frame(group = x$family, variable = x$variable, round = as.character(r$label[match(x$round_id, r$round_id)]), source = x$source, type = x$type, coverage = x$coverage, range = x$range, label = x$label, value_labels = x$value_labels, stringsAsFactors = FALSE)
      reactable::reactable(x, filterable = TRUE, searchable = TRUE, compact = TRUE, striped = TRUE, defaultPageSize = 15, defaultColDef = reactable::colDef(na = "—"),
                           columns = list(group = reactable::colDef(minWidth = 130), variable = reactable::colDef(minWidth = 140), round = reactable::colDef(minWidth = 95),
                                          source = reactable::colDef(minWidth = 180, style = list(fontFamily = "Consolas, monospace", fontSize = "0.8em")),
                                          type = reactable::colDef(minWidth = 75), coverage = reactable::colDef(name = "% answered", minWidth = 105, cell = coverage_bar), range = reactable::colDef(minWidth = 90),
                                          label = reactable::colDef(name = "SPSS label", minWidth = 260, style = list(fontSize = ".8em")), value_labels = reactable::colDef(name = "Value labels", minWidth = 240, style = list(fontSize = ".8em"))))
    })

    output$dups <- reactable::renderReactable({
      x <- d$mapping_duplicates
      x <- data.frame(Round = as.character(r$label[match(x$round_id, r$round_id)]), `Source column` = x$source, `Harmonised variables` = x$targets, Status = ifelse(x$source == "rCSILessQlty", "Error: the file has its own rCSIBorrow", "To review"), check.names = FALSE)
      x <- x[order(x$Status), ]
      reactable::reactable(x, compact = TRUE, striped = TRUE, pagination = FALSE, class = "dark-table",
                           columns = list(Round = reactable::colDef(minWidth = 100, class = "cell-label"), `Source column` = reactable::colDef(minWidth = 190, style = list(fontFamily = "Consolas, monospace", fontSize = ".78rem")), `Harmonised variables` = reactable::colDef(minWidth = 280), Status = reactable::colDef(minWidth = 220)))
    })

    output$concept_card <- shiny::renderUI({
      h <- selected()
      shiny::req(h)
      cc <- d$crosswalk_summary[d$crosswalk_summary$variable == h, ]
      fl <- d$mapping_duplicates[grepl(paste0("(^|, )", h, "($|,)"), d$mapping_duplicates$targets), ]
      bslib::card(
        class = "concept-card",
        bslib::card_header(class = "d-flex flex-wrap gap-2 align-items-center",
                           htmltools::code(cc$variable), pill(cc$family, COL$navy),
                           pill(sprintf("%d / 10 rounds", cc$rounds_mapped), if (cc$rounds_mapped == 10) "#035537" else "#AA5628"),
                           if (cc$in_final) pill("in merged file", "#035537") else pill("not in merged file", "#636466")),
        if (nrow(fl)) callout(type = "warning", sprintf("Shares a source column with another variable in %s. See the Shared source columns tab.", paste(r$label[match(fl$round_id, r$round_id)], collapse = ", "))),
        reactable::reactableOutput(ns("concept_rounds"))
      )
    })
    output$concept_rounds <- reactable::renderReactable({
      x <- d$crosswalk[d$crosswalk$variable == selected(), ]
      x <- data.frame(round = as.character(r$label[match(x$round_id, r$round_id)]), source = x$source, coverage = x$coverage, type = x$type, range = x$range, label = x$label, value_labels = x$value_labels, stringsAsFactors = FALSE)
      reactable::reactable(x, compact = TRUE, pagination = FALSE, striped = TRUE, sortable = FALSE, defaultColDef = reactable::colDef(na = "—"),
                           rowStyle = function(i) if (is.na(x$source[i])) list(color = "#939598"),
                           columns = list(round = reactable::colDef(name = "Round", minWidth = 100, style = list(fontWeight = 600)),
                                          source = reactable::colDef(name = "Source", minWidth = 200, style = list(fontFamily = "Consolas, monospace", fontSize = "0.8em")),
                                          coverage = reactable::colDef(name = "% answered", minWidth = 110, cell = coverage_bar), type = reactable::colDef(name = "Type", minWidth = 75), range = reactable::colDef(name = "Range", minWidth = 80),
                                          label = reactable::colDef(name = "SPSS label", minWidth = 280, style = list(fontSize = "0.82em")), value_labels = reactable::colDef(name = "Value labels", minWidth = 260, style = list(fontSize = "0.8em"))))
    })

    output$dl_xlsx <- shiny::downloadHandler(filename = function() "WFP_Chad_crosswalk_2018-2023.xlsx", content = function(file) file.copy(d$xlsx_path, file))
    output$dl_csv <- shiny::downloadHandler(filename = function() "WFP_Chad_crosswalk_details.csv", content = function(file) {
      x <- details_f(); x$round_label <- as.character(r$label[match(x$round_id, r$round_id)])
      readr::write_csv(x[, c("family", "variable", "round_label", "source", "type", "coverage", "range", "label", "value_labels")], file, na = "")
    })
  })
}
