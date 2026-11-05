# Regions: profile of one region, ranking of all regions, region x round map.

regions_ui <- function(id, d) {
  ns <- shiny::NS(id)
  regions <- sort(unique(d$ind_region$region))
  htmltools::tagList(
    page_intro("Regions", "Profile of one region against all surveyed households, and the regions side by side.",
               "geo-alt", shiny::uiOutput(ns("chip"))),
    bslib::layout_columns(
      col_widths = c(4, 8), class = "filters",
      shiny::selectInput(ns("region"), "Region", regions, selected = if ("Lac" %in% regions) "Lac" else regions[1]),
      shiny::selectInput(ns("metric"), "Indicator for the ranking and the map", IND_CHOICES, selected = "fcs_pb")
    ),
    shiny::uiOutput(ns("kpis")),
    bslib::layout_columns(
      col_widths = c(8, 4),
      bslib::card(height = 500, full_screen = TRUE, bslib::card_header(shiny::textOutput(ns("table_title"), inline = TRUE)),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("table"))),
                  bslib::card_footer(class = "table-note", "† Known defect in the merged file. –: not collected, or fewer than 30 households. Change against the previous usable round of the series.")),
      bslib::card(height = 500, full_screen = TRUE, bslib::card_header(shiny::textOutput(ns("rank_title"), inline = TRUE)),
                  plotly::plotlyOutput(ns("rank"), height = "100%"))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header(shiny::textOutput(ns("heat_title"), inline = TRUE)),
                plotly::plotlyOutput(ns("heat"), height = "430px"),
                bslib::card_footer(class = "table-note", "Blank: not surveyed. † in the cell: known defect. Cells under 30 households are suppressed. The frame marks the reference round.")),
    bslib::card(full_screen = TRUE, bslib::card_header("Selected regions against all surveyed households"),
                shinyWidgets::pickerInput(ns("compare"), NULL, choices = regions, selected = intersect(c("Lac", "Kanem", "Batha"), regions), multiple = TRUE,
                                          options = shinyWidgets::pickerOptions(maxOptions = 6, liveSearch = TRUE, noneSelectedText = "Select up to 6 regions")),
                plotly::plotlyOutput(ns("trend"), height = "340px")),
    htmltools::p(class = "small text-muted", "Unweighted figures for the households surveyed in WFP programme areas: not representative of the regions.")
  )
}

regions_server <- function(id, d, ref, est) {
  shiny::moduleServer(id, function(input, output, session) {
    reg <- d$ind_region
    nat <- d$ind_round
    r <- d$rounds
    output$chip <- round_chip(d, ref)
    area <- shiny::reactive(reg[reg$region == input$region, ])

    output$kpis <- shiny::renderUI({
      x <- area(); rid <- ref(); e <- est()
      card <- function(id, title, icon, tone) {
        cmp <- ind_compare(x, id, rid, e, d)
        n <- ind_value(nat[nat$round_id == rid, ], id, e)$v
        kpi(title, fmt_ind(cmp$value, id),
            if (is.na(cmp$value)) "Not available in this round" else
              htmltools::tagList(change_tag(cmp, id), htmltools::br(), sprintf("All households: %s", fmt_ind(n, id))),
            icon, if (cmp$flagged) "flag" else tone)
      }
      hh <- x$households[x$round_id == rid]
      bslib::layout_column_wrap(
        width = "190px", fill = FALSE, heights_equal = "row",
        kpi("Households surveyed", if (length(hh)) fmt_int(hh) else "–",
            if (length(hh)) sprintf("%s, %s", input$region, r$label[r$round_id == rid]) else "Not surveyed in this round", "people", "slate"),
        card("fcs_pb", "Poor + borderline FCS", "basket", "orange"),
        card("rcsi_mean", "Mean rCSI", "shield-exclamation", "red"),
        card("lcs_ce", "Crisis + emergency coping", "life-preserver", "brown"),
        card("rcs_mean", "Mean resilience capacity", "arrow-repeat", "blue")
      )
    })

    output$table_title <- shiny::renderText(sprintf("%s, latest six rounds", input$region))
    output$table <- reactable::renderReactable({
      x <- area(); rid <- ref()
      shiny::validate(shiny::need(rid %in% x$round_id, "This region was not surveyed in the reference round."))
      rnd <- r$round[r$round_id == rid]
      keep <- utils::tail(x$round_id[order(x$round)][x$round[order(x$round)] <= rnd], 6)
      ind_reactable(x, IND_MAIN, keep, rid, est(), d)
    })

    output$rank_title <- shiny::renderText(sprintf("%s, %s", ind_info(input$metric)$short, r$label[r$round_id == ref()]))
    output$rank <- plotly::renderPlotly({
      id <- input$metric; rid <- ref(); e <- est()
      x <- reg[reg$round_id == rid, ]
      x$v <- ind_value(x, id, e)$v
      x <- x[!is.na(x$v), ]
      shiny::validate(shiny::need(nrow(x) > 0, "Not available in this round."))
      x <- x[order(x$v), ]
      n <- ind_value(nat[nat$round_id == rid, ], id, e)$v
      flagged <- rid %in% flagged_rounds(d, id, e)
      plotly::plot_ly(x, y = factor(x$region, levels = x$region), x = ~v, type = "bar", orientation = "h",
                      marker = list(color = ifelse(x$region == input$region, COL$navy, "#89D1F4"),
                                    pattern = list(shape = if (flagged) "/" else "", fillmode = "overlay", fgcolor = "rgba(255,255,255,0.75)", size = 6, solidity = 0.3)),
                      text = fmt_ind(x$v, id), textposition = "outside", cliponaxis = FALSE,
                      hovertemplate = "%{y}: %{text}<extra></extra>") |>
        plotly_style(legend = FALSE, margin = list(t = 26, r = 44, b = 10, l = 10),
                     xaxis = list(title = "", showticklabels = FALSE, showgrid = FALSE),
                     yaxis = list(title = "", tickfont = list(size = 11)),
                     shapes = list(list(type = "line", yref = "paper", y0 = 0, y1 = 1, x0 = n, x1 = n, line = list(color = COL$ink, width = 1, dash = "dot"))),
                     annotations = list(list(x = n, y = 1, yref = "paper", yanchor = "bottom", showarrow = FALSE,
                                             text = sprintf("All %s", fmt_ind(n, id)), font = list(size = 11, color = COL$ink))))
    })

    output$heat_title <- shiny::renderText(sprintf("%s by region and round", metric_label(input$metric)))
    output$heat <- plotly::renderPlotly({
      id <- input$metric; e <- est()
      x <- reg
      s <- ind_value(x, id, e, d)
      x$v <- s$v; x$fl <- s$flagged
      lv <- as.character(r$label)
      regions <- sort(unique(x$region))
      grid <- function(col) tapply(x[[col]], list(factor(x$region, levels = regions), factor(as.character(x$label), levels = lv)), function(v) v[1])
      z <- grid("v"); hh <- grid("households"); fl <- grid("fl")
      shiny::validate(shiny::need(any(!is.na(z)), "Not available."))
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s<br>%s households%s", rep(regions, length(lv)), rep(lv, each = length(regions)),
                            ifelse(is.na(z), "suppressed, not collected or not surveyed", fmt_ind(z, id)),
                            ifelse(is.na(hh), "0", fmt_int(hh)), ifelse(fl %in% TRUE, "<br><i>known defect</i>", "")),
                    nrow = length(regions))
      cell <- matrix(ifelse(is.na(z), "", paste0(formatC(z, format = "f", digits = if (is_pct(id)) 0 else 1), ifelse(fl %in% TRUE, " †", ""))), nrow = length(regions))
      k <- match(as.character(r$label[r$round_id == ref()]), lv)
      round_heatmap(regions, lv, unname(z), hov, cell, heat_scale(id), suffix = if (is_pct(id)) "%" else "",
                    shapes = list(list(type = "rect", yref = "paper", xref = "x", y0 = 0, y1 = 1, x0 = k - 1.5, x1 = k - 0.5, line = list(color = COL$navy, width = 2))))
    })

    output$trend <- plotly::renderPlotly({
      id <- input$metric; e <- est()
      lv <- as.character(r$label)
      skip <- flagged_rounds(d, id, e)
      val <- function(x) { v <- ind_value(x, id, e)$v; v[x$round_id %in% skip] <- NA; v }
      p <- plotly::plot_ly() |>
        plotly::add_trace(x = as.character(nat$label), y = val(nat), type = "scatter", mode = "lines+markers", name = "All households",
                          line = list(color = COL$navy, width = 3, dash = "dot"), marker = list(size = 7, color = COL$navy))
      pal <- c("#007DBC", "#F0512D", "#950158", "#03924A", "#AA5628", "#008EB2")
      for (k in seq_along(input$compare)) {
        xr <- reg[reg$region == input$compare[k], ]
        xr <- xr[order(xr$round), ]
        if (!nrow(xr)) next
        p <- plotly::add_trace(p, x = as.character(xr$label), y = val(xr), type = "scatter", mode = "lines+markers", name = input$compare[k],
                               line = list(color = pal[k], width = 2), marker = list(size = 7, color = pal[k]), connectgaps = FALSE)
      }
      p |> plotly_style(xaxis = list(title = "", tickangle = -35, categoryorder = "array", categoryarray = lv),
                        yaxis = list(title = "", ticksuffix = if (is_pct(id)) "%" else ""))
    })
  })
}
