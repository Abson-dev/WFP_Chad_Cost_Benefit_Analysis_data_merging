# Merge: how 10 raw files became one dataset. Rows, modules, columns and linked data.

merge_ui <- function(id, d) {
  ns <- shiny::NS(id)
  r <- d$rounds; m <- d$manifest
  htmltools::tagList(
    page_intro("Merge", "How 10 raw survey files became one dataset: every household and column accounted for. The results come from replaying the merge on your files.",
               "sign-merge-right"),
    bslib::layout_column_wrap(
      width = "170px", fill = FALSE, heights_equal = "row",
      kpi("Raw rows", fmt_int(sum(r$raw_rows)), "In the 10 SPSS files", "files", "slate"),
      kpi("Rows removed", fmt_int(sum(r$duplicates_removed) + sum(r$empty_removed)),
          sprintf("%d duplicates, %d refused interview", sum(r$duplicates_removed), sum(r$empty_removed)), "dash-circle", "orange"),
      kpi("Households merged", fmt_int(m$households), "Unique on ID, across 10 rounds", "people", "navy"),
      kpi("Modules merged", nrow(d$merge_steps), "1:1 on ID, none left unmatched", "sign-merge-right", "blue"),
      kpi("Columns", fmt_int(m$columns), sprintf("%d of %d workbook variables kept", m$mapped_in_final, m$mapped_variables + m$mapped_variables_extension), "layout-three-columns", "brown")
    ),
    bslib::layout_columns(
      col_widths = c(4, 8),
      bslib::card(full_screen = TRUE, bslib::card_header("Households by round"), plotly::plotlyOutput(ns("rows"), height = "340px")),
      bslib::card(full_screen = TRUE, bslib::card_header("From raw file to merged file"),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("flow"))),
                  bslib::card_footer(class = "table-note", "Mapped: variables read from the raw file through the workbook. Approach compares them with the file's columns."))
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(full_screen = TRUE, bslib::card_header("Merge steps, in the do-file's order"),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("steps"))),
                  bslib::card_footer(class = "table-note", "Master only: households with no record in that module, because it was not asked in their round. Using only is the warning sign, and it is 0 everywhere.")),
      bslib::card(bslib::card_header("Place names"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("places"))))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header("Which module reaches which round: households"), plotly::plotlyOutput(ns("modules"), height = "520px"),
                bslib::card_footer(class = "table-note", "Steps 9 to 25 are the modules added in November 2026 by do-files 16 to 20; step 26 is the cost module, added by do-file 21. A module counts a household when its file has a row for it, even if the round did not ask its questions: see the completeness by group below.")),
    bslib::card(full_screen = TRUE, bslib::card_header("Columns of the merged file: average completeness by group and round"),
                plotly::plotlyOutput(ns("families"), height = "600px"),
                bslib::card_footer(class = "table-note", "Assistance columns are low by design: each original-answer column belongs to one round only. Geography is lowered by the GPS columns, available mainly in 2018.")),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(bslib::card_header("Cadre Harmonisé link: households by phase of their department"), plotly::plotlyOutput(ns("ch"), height = "320px"),
                  bslib::card_footer(class = "table-note", "Current-period phase of the department, joined on year, cycle and department code. 2018 uses the 2017 analysis.")),
      bslib::card(bslib::card_header("Built but not merged"),
                  htmltools::p(class = "small", "MAD (children) and MDDW (women) hold one row per person. In four rounds the household file combines several survey forms that each number households from 1, and the repeat files lost the form, so a child or woman can match several households. They are left out of the merge and the release. Rows in the raw repeat files and in the module files:"),
                  reactable::reactableOutput(ns("nutrition")))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header("All columns of the merged file"), reactable::reactableOutput(ns("columns")))
  )
}

merge_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    r <- d$rounds

    output$rows <- plotly::renderPlotly({
      p <- plotly::plot_ly()
      for (s in names(SERIES_COL)) {
        k <- r$series == s
        p <- plotly::add_bars(p, x = factor(r$label[k], levels = r$label), y = r$final_rows[k], name = s, marker = list(color = SERIES_COL[[s]]),
                              text = fmt_int(r$final_rows[k]), textposition = "outside", cliponaxis = FALSE,
                              hovertemplate = "%{x}: %{y:,} households<extra></extra>")
      }
      p |> plotly_style(barmode = "overlay", xaxis = list(tickangle = -35, categoryorder = "array", categoryarray = r$label),
                        yaxis = list(title = "", showticklabels = FALSE, showgrid = FALSE, range = c(0, 1.15 * max(r$final_rows))))
    })

    output$flow <- reactable::renderReactable({
      t <- data.frame(Round = r$label, `Raw file` = r$raw_file, `Mapped` = r$mapped_vars, `Raw rows` = r$raw_rows,
                      Duplicates = r$duplicates_removed, Refused = r$empty_removed, Merged = r$final_rows, check.names = FALSE)
      total <- function(v) format(sum(v), big.mark = ",")
      reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, striped = TRUE, class = "dark-table", defaultColDef = reactable::colDef(align = "right", minWidth = 70, format = reactable::colFormat(separators = TRUE)),
                           columns = list(Round = reactable::colDef(align = "left", minWidth = 105, class = "cell-label", footer = "Total"),
                                          `Raw file` = reactable::colDef(align = "left", minWidth = 230, style = list(fontSize = ".74rem")),
                                          `Raw rows` = reactable::colDef(footer = total(r$raw_rows)), Duplicates = reactable::colDef(minWidth = 88, footer = total(r$duplicates_removed)),
                                          Refused = reactable::colDef(footer = total(r$empty_removed)), Merged = reactable::colDef(footer = total(r$final_rows))),
                           defaultSorted = NULL, theme = reactable::reactableTheme(footerStyle = list(fontWeight = 700)))
    })

    output$steps <- reactable::renderReactable({
      s <- d$merge_steps[order(d$merge_steps$merge_order), ]
      t <- data.frame(Step = s$merge_order, Module = s$label, Rows = s$using_rows, Matched = s$matched, `Master only` = s$master_only, `Using only` = s$using_only,
                      Columns = s$columns_added, description = s$description, check.names = FALSE)
      reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, striped = TRUE, class = "dark-table",
                           defaultColDef = reactable::colDef(align = "right", minWidth = 65, format = reactable::colFormat(separators = TRUE)),
                           columns = list(Step = reactable::colDef(minWidth = 42, align = "center"),
                                          Module = reactable::colDef(align = "left", minWidth = 175, class = "cell-label"),
                                          Matched = reactable::colDef(minWidth = 76), Columns = reactable::colDef(minWidth = 76),
                                          description = reactable::colDef(show = FALSE)),
                           details = function(i) htmltools::div(class = "row-detail", t$description[i]))
    })

    output$modules <- plotly::renderPlotly({
      m <- d$module_round; lab <- d$modules$label[match(m$module, d$modules$module)]
      rows <- d$modules$label[order(d$modules$merge_order)]
      z <- tapply(m$pct, list(factor(lab, levels = rows), factor(r$label[match(m$round_id, r$round_id)], levels = r$label)), function(v) v[1])
      n <- tapply(m$households, list(factor(lab, levels = rows), factor(r$label[match(m$round_id, r$round_id)], levels = r$label)), function(v) v[1])
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s households", rep(rows, ncol(z)), rep(colnames(z), each = nrow(z)), fmt_int(n)), nrow = nrow(z))
      cell <- matrix(ifelse(n == 0, "", fmt_int(n)), nrow = nrow(z))
      round_heatmap(rows, colnames(z), unname(z), hov, cell, list(c(0, "#F1F3F5"), c(0.001, "#D5ECDD"), c(1, "#74C48A")), 0, 100, colorbar = FALSE)
    })

    output$families <- plotly::renderPlotly({
      f <- d$family_coverage
      fam <- d$merged_columns$family; counts <- table(fam)
      rows <- c("Identification", "Geography", "Cadre Harmonisé", "Household", "Food consumption (FCS)", "Reduced coping (rCSI)", "Livelihood coping (LCS)",
                "Dietary diversity (HDDS)", "Asset benefit (ABI)", "Resilience (SERS / RCS)", "Assistance: harmonised", "Assistance: original answers",
                "Shocks", "Assets and livestock", "Livelihoods", "Agriculture", "Expenditure", "Disability", "Education", "Migration",
                "Protection and accountability", "Debt", "Social cohesion", "Climate adaptation", "Shock impact and recovery", "Programme effects", "Markets", "Food shortage (2018-2021)")
      rows <- intersect(rows, names(counts))
      lv <- r$label[match(d$round_ids, r$round_id)]
      z <- tapply(f$pct, list(factor(f$family, levels = rows), factor(r$label[match(f$round_id, r$round_id)], levels = lv)), function(v) v[1])
      rl <- sprintf("%s (%d)", rows, counts[rows])
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s average completeness", rep(rl, ncol(z)), rep(colnames(z), each = nrow(z)), fmt_pct(z, 0)), nrow = nrow(z))
      cell <- matrix(ifelse(is.na(z) | z == 0, "", formatC(z, format = "f", digits = 0)), nrow = nrow(z))
      round_heatmap(rl, colnames(z), unname(z), hov, cell, list(c(0, "#F1F3F5"), c(0.001, "#FEDFCE"), c(0.5, "#ECE1B1"), c(1, "#74C48A")), 0, 100, suffix = "%")
    })

    output$ch <- plotly::renderPlotly({
      x <- d$ch_phase
      tot <- tapply(x$households, x$round_id, sum)
      x$pct <- 100 * x$households / as.numeric(tot[x$round_id])
      cols <- c("1" = "#CDFACD", "2" = "#FAE61E", "3" = "#E67800")
      p <- plotly::plot_ly()
      for (ph in sort(unique(x$phase))) {
        s <- x[x$phase == ph, ]
        p <- plotly::add_bars(p, x = factor(r$label[match(s$round_id, r$round_id)], levels = r$label), y = s$pct, name = paste("Phase", ph),
                              marker = list(color = cols[[as.character(ph)]], line = list(color = "#fff", width = .5)),
                              customdata = fmt_int(s$households), hovertemplate = paste0("%{x} · Phase ", ph, ": %{y:.1f}% (%{customdata} households)<extra></extra>"))
      }
      p |> plotly_style(barmode = "stack", xaxis = list(tickangle = -35, categoryorder = "array", categoryarray = r$label), yaxis = list(range = c(0, 100), ticksuffix = "%"))
    })

    output$places <- reactable::renderReactable({
      reactable::reactable(d$places, compact = TRUE, pagination = FALSE, sortable = FALSE, striped = TRUE, class = "dark-table",
                           columns = list(measure = reactable::colDef(name = "Measure", minWidth = 280), value = reactable::colDef(name = "Count", align = "right", format = reactable::colFormat(separators = TRUE))))
    })

    output$nutrition <- reactable::renderReactable({
      n <- d$nutrition
      n$Round <- as.character(r$label[match(n$round_id, r$round_id)])
      w <- tidyr::pivot_wider(n[, c("Round", "module", "raw_rows", "module_rows")], names_from = module, values_from = c(raw_rows, module_rows))
      right <- function(name) reactable::colDef(align = "right", name = name, minWidth = 62, format = reactable::colFormat(separators = TRUE))
      reactable::reactable(as.data.frame(w), compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table",
                           columns = list(Round = reactable::colDef(class = "cell-label", minWidth = 100), raw_rows_MAD = right("MAD raw"), module_rows_MAD = right("MAD module"),
                                          raw_rows_MDDW = right("MDDW raw"), module_rows_MDDW = right("MDDW module")))
    })

    output$columns <- reactable::renderReactable({
      t <- d$merged_columns
      reactable::reactable(t[, c("family", "variable", "label", "rounds_with_data")], searchable = TRUE, filterable = FALSE, compact = TRUE, striped = TRUE, defaultPageSize = 10,
                           columns = list(family = reactable::colDef(name = "Group", minWidth = 140),
                                          variable = reactable::colDef(name = "Column", minWidth = 150, style = list(fontFamily = "Consolas, monospace", fontSize = ".78rem")),
                                          label = reactable::colDef(name = "Label", minWidth = 300, style = list(fontSize = ".78rem")),
                                          rounds_with_data = reactable::colDef(name = "Rounds with data", align = "center", minWidth = 80)))
    })
  })
}
