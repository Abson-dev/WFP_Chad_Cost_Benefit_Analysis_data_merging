# Assistance: which intervention was asked in which round, what households answered, and the recoding audit.

assistance_ui <- function(id, d) {
  ns <- shiny::NS(id)
  iv <- d$interventions
  choices <- lapply(split(iv, factor(iv$group, levels = unique(iv$group))), function(g) stats::setNames(g$variable, g$label))
  au <- d$assistance_audit
  htmltools::tagList(
    page_intro("Assistance", "The 20 intervention variables: when they were asked, what households answered and how the recoding holds up.",
               "box-seam", shiny::uiOutput(ns("chip"))),
    bslib::layout_column_wrap(
      width = "200px", fill = FALSE, heights_equal = "row",
      kpi("Intervention variables", nrow(iv), "Self-reported, none in the 2018 baseline", "box-seam", "navy"),
      kpi("Answers kept after recoding", sprintf("%d of %d", sum(au$pct_same == 100), nrow(au)), "Variable and round pairs with the same Yes as the original", "check2-circle", "green"),
      kpi("Report table cells to update", nrow(d$assistance_documented), "Table 1 of the Issues report, against the data", "file-earmark-text", "brown")
    ),
    callout(type = "info", htmltools::strong("Before reading these shares. "),
            "They come from self-reports of households, in samples that may target participants. They are not coverage rates. ",
            "Combined items of the early rounds were split in 2021 Annual, so few series run through all rounds."),
    bslib::card(full_screen = TRUE, bslib::card_header("Households answering Yes, by intervention and round"),
                plotly::plotlyOutput(ns("matrix"), height = "610px"),
                bslib::card_footer(class = "table-note", "Share of households who answered. Blank: not asked in that round. Food for assets is 0 by design: recoded to cash for assets on WFP Chad's advice. The frame marks the reference round.")),
    bslib::layout_columns(
      col_widths = c(4, 8), class = "filters",
      shiny::selectInput(ns("variable"), "Intervention", choices, selected = "CashTransfert"),
      htmltools::div(class = "note", "This choice drives the two charts below.")
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(full_screen = TRUE, bslib::card_header(shiny::textOutput(ns("trend_title"), inline = TRUE)), plotly::plotlyOutput(ns("trend"), height = "370px")),
      bslib::card(full_screen = TRUE, bslib::card_header(shiny::textOutput(ns("region_title"), inline = TRUE)), plotly::plotlyOutput(ns("region"), height = "370px"),
                  bslib::card_footer(class = "table-note", "Cells under 30 answering households are suppressed."))
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(full_screen = TRUE, bslib::card_header("Harmonised answers against the original answers: green is 100% the same"),
                  plotly::plotlyOutput(ns("audit"), height = "420px"),
                  bslib::card_footer(class = "table-note", "Share of households with the same Yes in both, using the original columns kept in the merged file. Cash and food for assets are left out: they are recoded on purpose.")),
      bslib::card(full_screen = TRUE, bslib::card_header("Differences with Table 1 of the Issues report"),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("documented"))))
    )
  )
}

assistance_server <- function(id, d, ref) {
  shiny::moduleServer(id, function(input, output, session) {
    r <- d$rounds; iv <- d$interventions
    lv <- as.character(r$label)
    lab <- function(rid) as.character(r$label[match(rid, r$round_id)])
    output$chip <- round_chip(d, ref)
    var_label <- shiny::reactive(iv$label[iv$variable == input$variable])

    output$matrix <- plotly::renderPlotly({
      a <- d$assistance
      rows <- iv$label
      g <- function(col) tapply(a[[col]], list(factor(iv$label[match(a$variable, iv$variable)], levels = rows), factor(lab(a$round_id), levels = lv)), function(v) v[1])
      z <- g("yes_pct"); n <- g("answered")
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s<br>%s households answered", rep(rows, length(lv)), rep(lv, each = length(rows)),
                            ifelse(is.na(z), "not asked", paste(fmt_pct(z, 1), "Yes")), fmt_int(n)), nrow = length(rows))
      cell <- matrix(ifelse(is.na(z), "", formatC(z, format = "f", digits = 0)), nrow = length(rows))
      k <- match(lab(ref()), lv)
      round_heatmap(rows, lv, unname(z), hov, cell, list(c(0, "#F3F9FC"), c(.5, "#89D1F4"), c(1, "#004670")), 0, 100, suffix = "%",
                    shapes = list(list(type = "rect", yref = "paper", xref = "x", y0 = 0, y1 = 1, x0 = k - 1.5, x1 = k - 0.5, line = list(color = COL$navy, width = 2))))
    })

    output$trend_title <- shiny::renderText(sprintf("%s: answers by round", var_label()))
    output$trend <- plotly::renderPlotly({
      a <- d$assistance[d$assistance$variable == input$variable & d$assistance$answered > 0, ]
      shiny::validate(shiny::need(nrow(a) > 0, "Not asked."))
      x <- factor(lab(a$round_id), levels = lv)
      pcts <- function(v) 100 * v / a$answered
      plotly::plot_ly() |>
        plotly::add_bars(x = x, y = pcts(a$yes), name = "Yes", marker = list(color = COL$blue), hovertemplate = "%{x}, Yes: %{y:.1f}%<extra></extra>") |>
        plotly::add_bars(x = x, y = pcts(a$no), name = "No", marker = list(color = "#DADBDC"), hovertemplate = "%{x}, No: %{y:.1f}%<extra></extra>") |>
        plotly::add_bars(x = x, y = pcts(a$dont_know), name = "Don't know", marker = list(color = "#F8A07E"), hovertemplate = "%{x}, Don't know: %{y:.1f}%<extra></extra>") |>
        plotly_style(barmode = "stack", xaxis = list(tickangle = -35, categoryorder = "array", categoryarray = lv), yaxis = list(range = c(0, 100), ticksuffix = "%"))
    })

    output$region_title <- shiny::renderText(sprintf("%s: Yes by region", var_label()))
    output$region <- plotly::renderPlotly({
      a <- d$assistance_region[d$assistance_region$variable == input$variable, ]
      shiny::validate(shiny::need(nrow(a) > 0, "Not asked."))
      rows <- sort(unique(a$region))
      cols <- lv[lv %in% lab(a$round_id)]
      g <- function(col) tapply(a[[col]], list(factor(a$region, levels = rows), factor(lab(a$round_id), levels = cols)), function(v) v[1])
      z <- g("yes_pct"); n <- g("answered")
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s<br>%s households answered", rep(rows, length(cols)), rep(cols, each = length(rows)),
                            ifelse(is.na(z), "suppressed or not surveyed", paste(fmt_pct(z, 1), "Yes")), ifelse(is.na(n), "0", fmt_int(n))), nrow = length(rows))
      cell <- matrix(ifelse(is.na(z), "", formatC(z, format = "f", digits = 0)), nrow = length(rows))
      round_heatmap(rows, cols, unname(z), hov, cell, list(c(0, "#F3F9FC"), c(.5, "#89D1F4"), c(1, "#004670")), 0, 100, suffix = "%")
    })

    output$audit <- plotly::renderPlotly({
      a <- d$assistance_audit
      rows <- iv$label[iv$variable %in% a$variable]
      cols <- lv[lv %in% lab(a$round_id)]
      z <- tapply(a$pct_same, list(factor(iv$label[match(a$variable, iv$variable)], levels = rows), factor(lab(a$round_id), levels = cols)), function(v) v[1])
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s same", rep(rows, length(cols)), rep(cols, each = length(rows)), fmt_pct(z, 1)), nrow = length(rows))
      # Only exceptions get a number: the cells are too small for 91 times "100".
      cell <- matrix(ifelse(is.na(z) | z == 100, "", formatC(z, format = "f", digits = 0)), nrow = length(rows))
      round_heatmap(rows, cols, unname(z), hov, cell, list(c(0, "#E3002B"), c(.9, "#ECE1B1"), c(1, "#74C48A")), 0, 100, suffix = "%", colorbar = FALSE)
    })

    output$documented <- reactable::renderReactable({
      t <- d$assistance_documented
      t <- data.frame(Intervention = iv$label[match(t$variable, iv$variable)], Round = lab(t$round_id), Difference = t$status)
      reactable::reactable(t, compact = TRUE, pagination = FALSE, striped = TRUE, class = "dark-table", sortable = FALSE,
                           columns = list(Intervention = reactable::colDef(minWidth = 190, class = "cell-label"), Round = reactable::colDef(minWidth = 90), Difference = reactable::colDef(minWidth = 170)))
    })
  })
}
