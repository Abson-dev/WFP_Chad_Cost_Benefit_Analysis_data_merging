# Trends: one indicator across years, lean season with lean season, post-harvest with post-harvest.

trends_ui <- function(id, d) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    page_intro("Trends", "One indicator over time. The two seasons differ systematically, so each round is compared with the previous one of its series.",
               "graph-up", shiny::uiOutput(ns("chip"))),
    bslib::layout_columns(
      col_widths = c(7, 5), class = "filters",
      shiny::selectInput(ns("indicator"), "Indicator", IND_CHOICES, selected = "fcs_pb"),
      shiny::selectInput(ns("geo"), "Area", c("All surveyed households" = "", sort(unique(d$ind_region$region))))
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(full_screen = TRUE, bslib::card_header(shiny::textOutput(ns("title"), inline = TRUE)),
                  plotly::plotlyOutput(ns("season"), height = "380px"),
                  bslib::card_footer(class = "table-note", "Hollow marker: known defect in the merged file, not joined by the line. No marker: not collected, or fewer than 30 households. Ring: reference round. Unweighted.")),
      bslib::card(full_screen = TRUE, bslib::card_header("Same indicator, round by round"),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("table"))))
    ),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(full_screen = TRUE, bslib::card_header("Food Consumption Score groups (28/42)"), plotly::plotlyOutput(ns("fcs"), height = "340px")),
      bslib::card(full_screen = TRUE, bslib::card_header("Maximum livelihood coping category"), plotly::plotlyOutput(ns("lcs"), height = "340px"))
    ),
    htmltools::p(class = "small text-muted", "Hatched bars: known defect in the merged file. Figures describe the households surveyed in WFP programme areas, not the population; there are no sampling weights.")
  )
}

trends_server <- function(id, d, ref, est) {
  shiny::moduleServer(id, function(input, output, session) {
    r <- d$rounds
    output$chip <- round_chip(d, ref)
    area <- shiny::reactive({
      x <- if (!nzchar(input$geo)) d$ind_round else d$ind_region[d$ind_region$region == input$geo, ]
      x[order(x$round), ]
    })
    area_name <- shiny::reactive(if (nzchar(input$geo)) input$geo else "all surveyed households")
    output$title <- shiny::renderText(sprintf("%s, %s", metric_label(input$indicator), area_name()))

    output$season <- plotly::renderPlotly({
      x <- area(); id <- input$indicator; rid <- ref(); e <- est()
      val <- ind_value(x, id, e, d)
      shiny::validate(shiny::need(any(!is.na(val$v)), "Not available for this area."))
      p <- plotly::plot_ly()
      for (s in names(SERIES_COL)) {
        k <- x$series == s
        if (!any(k)) next
        ref_row <- x$round_id[k] == rid
        # Flagged cells stay visible, but the line does not join them, so that a defect does not read as a trend.
        y_line <- ifelse(val$flagged[k], NA, val$v[k])
        p <- plotly::add_trace(p, x = x$year[k], y = y_line, type = "scatter", mode = "lines", name = s, connectgaps = TRUE,
                               line = list(color = SERIES_COL[[s]], width = 2.5), hoverinfo = "skip")
        p <- plotly::add_trace(p, x = x$year[k], y = val$v[k], type = "scatter", mode = "markers", showlegend = FALSE,
                               marker = list(size = ifelse(ref_row, 14, 10), color = ifelse(val$flagged[k], "#FFFFFF", SERIES_COL[[s]]),
                                             line = list(color = ifelse(ref_row, COL$navy, SERIES_COL[[s]]), width = ifelse(ref_row, 3, 2))),
                               text = sprintf("%s: %s%s", x$label[k], fmt_ind(val$v[k], id), ifelse(val$flagged[k], " (known defect)", "")), hoverinfo = "text")
      }
      p |> plotly_style(xaxis = list(title = "", dtick = 1, tickformat = "d"),
                        yaxis = list(title = "", ticksuffix = if (is_pct(id)) "%" else "", rangemode = "tozero"))
    })

    output$table <- reactable::renderReactable({
      x <- area(); id <- input$indicator; e <- est()
      x <- x[order(x$round, decreasing = TRUE), ]
      val <- ind_value(x, id, e, d)
      t <- data.frame(
        Round = as.character(x$label),
        Value = ifelse(val$flagged & !is.na(val$v), sprintf("<span class='flag-text'>%s †</span>", fmt_ind(val$v, id)), fmt_ind(val$v, id)),
        Change = vapply(x$round_id, function(k) change_tag(ind_compare(x, id, k, e, d), id, html = TRUE), "", USE.NAMES = FALSE),
        Households = fmt_int(x$households), id = x$round_id, stringsAsFactors = FALSE
      )
      rid <- ref()
      reactable::reactable(
        t, compact = TRUE, striped = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table",
        rowClass = function(i) if (t$id[i] == rid) "row-current",
        columns = list(
          id = reactable::colDef(show = FALSE),
          Round = reactable::colDef(class = "cell-label", minWidth = 100),
          Value = reactable::colDef(align = "right", html = TRUE),
          Change = reactable::colDef(name = "Change in series", html = TRUE, align = "right", minWidth = 115),
          Households = reactable::colDef(align = "right")
        )
      )
    })

    stacked <- function(x, parts, cols, dark_text, group) {
      x <- x[order(x$round), ]
      lab <- factor(as.character(x$label), levels = as.character(x$label))
      fl <- x$round_id %in% (if (est() == "m") d$flags$round_id[d$flags$indicator_group == group] else d$flags$round_id[d$flags$indicator_group == group & !d$flags$fixed])
      p <- plotly::plot_ly()
      for (k in names(parts)) {
        v <- x[[paste0(parts[[k]], "_", est())]]
        p <- plotly::add_bars(p, x = lab, y = v, name = k, marker = list(
          color = cols[[k]], line = list(color = "#ffffff", width = 0.5),
          pattern = list(shape = ifelse(fl, "/", ""), fillmode = "overlay", fgcolor = "rgba(255,255,255,0.6)", size = 7, solidity = 0.3)),
          text = ifelse(is.na(v) | v < 6, "", sprintf("%.0f", v)), textposition = "inside", textangle = 0,
          insidetextfont = list(color = if (k %in% dark_text) COL$ink else "#fff", size = 11),
          hovertemplate = paste0("%{x} · ", k, ": %{y:.1f}%", ifelse(fl, " (known defect)", ""), "<extra></extra>"))
      }
      p |> plotly_style(barmode = "stack", xaxis = list(title = "", tickangle = -35), yaxis = list(title = "", range = c(0, 100), ticksuffix = "%"))
    }
    output$fcs <- plotly::renderPlotly({
      stacked(area(), list(Poor = "fcs_poor", Borderline = "fcs_border", Acceptable = "fcs_accept"), as.list(FCS_COL), c("Borderline"), "fcs")
    })
    output$lcs <- plotly::renderPlotly({
      stacked(area(), list(`No coping` = "lcs_none", Stress = "lcs_stress", Crisis = "lcs_crisis", Emergency = "lcs_em"), as.list(LCS_COL), c("No coping", "Stress"), "lcs")
    })
  })
}
