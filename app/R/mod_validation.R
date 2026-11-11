# Validation: every check computed by prepare_app_data.R, and what the defects do to the indicators.

SENSITIVITY <- c("Poor + borderline FCS" = "fcs_pb", "Mean rCSI" = "rcsi_mean", "Crisis + emergency coping" = "lcs_ce",
                 "Emergency coping" = "lcs_em", "No coping" = "lcs_none", "Mean asset benefit" = "abi_mean", "Mean household size" = "hh_size")

validation_ui <- function(id, d) {
  ns <- shiny::NS(id)
  ck <- d$checks; n <- function(s) sum(ck$status == s)
  htmltools::tagList(
    page_intro("Validation", "Do the merged data match their sources, and are they plausible? Each result is recomputed from the raw, module and merged files whenever the data are refreshed.", "patch-check"),
    bslib::layout_column_wrap(
      width = "170px", fill = FALSE, heights_equal = "row",
      kpi("Checks passed", n("pass"), sprintf("of %d: rows, merge, formulas", nrow(ck)), "check2-circle", "green"),
      kpi("To review", n("warn"), "Documentation and plausibility", "exclamation-circle", "brown"),
      kpi("Failed", n("fail"), "Change results: see the list below", "x-octagon", "red"),
      kpi("Row and merge checks", sprintf("%d of %d", sum(ck$status == "pass" & ck$group %in% c("Rows", "Merge")), sum(ck$group %in% c("Rows", "Merge"))),
          sprintf("Passed, for %s households", fmt_int(d$manifest$households)), "list-check", "navy"),
      kpi("Formula checks", sprintf("%d of %d", sum(ck$status == "pass" & ck$group == "Formulas"), sum(ck$group == "Formulas")),
          "Passed: FCS, rCSI, LCS, RCS, ABI", "calculator", "blue")
    ),
    callout(type = "warning", htmltools::strong("What this means. "),
            "The merge itself is sound: no household is lost, and the score formulas are right. The defects come earlier, from the mapping and recoding of some rounds. ",
            "Nothing has been changed in your files: the option in the left panel shows what the indicators would become."),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(full_screen = TRUE,
                  bslib::card_header(class = "d-flex justify-content-between align-items-center flex-wrap gap-2", "What the defects do to the indicators",
                                     shiny::selectInput(ns("sens"), NULL, SENSITIVITY, selected = "lcs_ce", width = "230px")),
                  plotly::plotlyOutput(ns("sens_plot"), height = "360px"),
                  bslib::card_footer(class = "table-note", "Red cross: merged value with a known defect. Grey: merged value without one. Corrected values are rebuilt from the raw files, and are indicative: they need review before any use.")),
      bslib::card(full_screen = TRUE, bslib::card_header("rCSI against the analysts' rCSI in the raw files"),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("rcsi"))),
                  bslib::card_footer(class = "table-note", "Same value: households whose rCSI equals the analysts'. Dash: no rCSI in that raw file."))
    ),
    bslib::card(full_screen = TRUE,
                bslib::card_header(class = "d-flex justify-content-between align-items-center flex-wrap gap-2", "All checks",
                                   shiny::radioButtons(ns("status"), NULL, c("All" = "", "Failed" = "fail", "To review" = "warn", "Passed" = "pass"), inline = TRUE)),
                reactable::reactableOutput(ns("checks"))),
    bslib::card(full_screen = TRUE,
                  bslib::card_header(class = "d-flex justify-content-between align-items-center flex-wrap gap-2", "Share of households adopting each coping strategy",
                                     shiny::radioButtons(ns("lcs_view"), NULL, c("As merged" = "merged_yes", "Corrected" = "corrected_yes"), inline = TRUE)),
                  plotly::plotlyOutput(ns("lcs"), height = "400px"),
                  bslib::card_footer(class = "table-note", "Answered Yes or already exhausted. Since do-file 23 (merged file v9), the merged and corrected views agree, except where the 2019 Annual codes have no labels.")),
    bslib::card(full_screen = TRUE, bslib::card_header("Values unchanged between the raw and merged files"),
                plotly::plotlyOutput(ns("agree"), height = "340px"),
                bslib::card_footer(class = "table-note", "Share of non-missing values equal in both files. Below 100% is expected where a module is recoded, so this is a map of where recoding happens, not a list of errors."))
  )
}

validation_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    r <- d$rounds

    output$sens_plot <- plotly::renderPlotly({
      id <- input$sens
      x <- d$ind_round
      a <- x[[paste0(id, "_m")]]; b <- x[[paste0(id, "_c")]]
      lab <- factor(x$label, levels = r$label)
      changed <- !is.na(a) & !is.na(b) & abs(a - b) > 1e-9
      flagged <- x$round_id %in% flagged_rounds(d, id, "m")
      p <- plotly::plot_ly()
      # Once a defect is fixed, the two values agree and there is nothing to join.
      if (any(changed)) p <- plotly::add_segments(p, x = lab[changed], xend = lab[changed], y = a[changed], yend = b[changed], line = list(color = "#B1B3B6", width = 2), showlegend = FALSE, hoverinfo = "skip")
      p |>
        plotly::add_markers(x = lab, y = b, name = "With indicative corrections", marker = list(size = 11, color = COL$blue),
                            text = fmt_ind(b, id), hovertemplate = "%{x}, corrected: %{text}<extra></extra>") |>
        plotly::add_markers(x = lab, y = a, name = "As merged", marker = list(size = 11, color = ifelse(flagged, COL$red, "#939598"), symbol = ifelse(flagged, "x", "circle")),
                            text = fmt_ind(a, id), hovertemplate = "%{x}, merged: %{text}<extra></extra>") |>
        plotly_style(xaxis = list(tickangle = -30, categoryorder = "array", categoryarray = r$label),
                     yaxis = list(rangemode = "tozero", ticksuffix = if (is_pct(id)) "%" else ""))
    })

    output$rcsi <- reactable::renderReactable({
      x <- d$rcsi
      t <- data.frame(Round = r$label[match(x$round_id, r$round_id)], Merged = x$merged, Analysts = x$analysts, Same = x$merged_same, Corrected = x$corrected, `Same after` = x$corrected_same, check.names = FALSE)
      num <- function(digits, suffix = "") reactable::colDef(align = "right", minWidth = 78, format = reactable::colFormat(digits = digits, suffix = suffix))
      reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, striped = TRUE, class = "dark-table", defaultColDef = reactable::colDef(na = "–"),
                           rowClass = function(i) if (!is.na(t$Same[i]) && t$Same[i] < 99) "row-flag",
                           columns = list(Round = reactable::colDef(class = "cell-label", minWidth = 100), Merged = num(2), Analysts = num(2), Same = num(0, "%"), Corrected = num(2), `Same after` = num(0, "%")))
    })

    output$checks <- reactable::renderReactable({
      t <- d$checks
      if (nzchar(input$status %||% "")) t <- t[t$status == input$status, ]
      reactable::reactable(t[, c("status", "group", "check", "observed", "expected", "detail")], compact = TRUE, searchable = TRUE, striped = TRUE, defaultPageSize = 12, groupBy = NULL,
                           columns = list(status = reactable::colDef(name = "Result", minWidth = 76, cell = function(v) status_pill(v)),
                                          group = reactable::colDef(name = "Area", minWidth = 108),
                                          check = reactable::colDef(name = "Check", minWidth = 235, class = "cell-label"),
                                          observed = reactable::colDef(name = "Found", minWidth = 145),
                                          expected = reactable::colDef(name = "Expected", minWidth = 85),
                                          detail = reactable::colDef(name = "Detail", minWidth = 420, style = list(fontSize = ".76rem"))))
    })

    output$lcs <- plotly::renderPlotly({
      x <- d$lcs_items
      item_lab <- c(LhCSIStress1 = "Stress: sell household goods", LhCSIStress2 = "Stress: spend savings or animals", LhCSIStress3 = "Stress: send members away", LhCSIStress4 = "Stress: buy on credit",
                    LhCSICrisis1 = "Crisis: sell productive assets", LhCSICrisis2 = "Crisis: cut health or education", LhCSICrisis3 = "Crisis: withdraw children from school",
                    LhCSIEmergency1 = "Emergency: sell house or land", LhCSIEmergency2 = "Emergency: beg", LhCSIEmergency3 = "Emergency: last female animal or illegal income")
      rows <- unname(item_lab)
      v <- input$lcs_view %||% "merged_yes"
      z <- tapply(x[[v]], list(factor(item_lab[x$item], levels = rows), factor(r$label[match(x$round_id, r$round_id)], levels = r$label)), function(a) a[1])
      mapped <- tapply(x$mapped, list(factor(item_lab[x$item], levels = rows), factor(r$label[match(x$round_id, r$round_id)], levels = r$label)), function(a) a[1])
      z[!mapped] <- NA
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s", rep(rows, ncol(z)), rep(colnames(z), each = nrow(z)), ifelse(is.na(z), "no source in that round", fmt_pct(z, 1))), nrow = nrow(z))
      cell <- matrix(ifelse(is.na(z), "", formatC(z, format = "f", digits = 0)), nrow = nrow(z))
      round_heatmap(rows, colnames(z), unname(z), hov, cell, list(c(0, "#F9F4DF"), c(1/3, "#F8A07E"), c(2/3, "#F0512D"), c(1, "#9A331B")), 0, 80, suffix = "%")
    })

    output$agree <- plotly::renderPlotly({
      x <- d$agree_family
      rows <- c("Food consumption (FCS)", "Reduced coping (rCSI)", "Livelihood coping (LCS)", "Household", "Assistance", "Resilience (SERS)", "Asset benefit (ABI)")
      rows <- intersect(rows, x$family)
      z <- tapply(x$pct_same, list(factor(x$family, levels = rows), factor(r$label[match(x$round_id, r$round_id)], levels = r$label)), function(a) a[1])
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s unchanged", rep(rows, ncol(z)), rep(colnames(z), each = nrow(z)), fmt_pct(z, 1)), nrow = nrow(z))
      cell <- matrix(ifelse(is.na(z), "", formatC(z, format = "f", digits = 0)), nrow = nrow(z))
      round_heatmap(rows, colnames(z), unname(z), hov, cell, list(c(0, "#FEDFCE"), c(.9, "#ECE1B1"), c(1, "#74C48A")), 0, 100, suffix = "%")
    })
  })
}
