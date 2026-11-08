# Costs: WFP's resilience cost data, reconciled, grouped by activity and linked to the surveys.

CATEGORY_COL <- c(
  "Land recovery: dikes, half-moons, anti-erosion" = "#AA5628", "Water: wells, ponds, dams, irrigation" = "#007DBC", "Trees, nurseries and dune fixation" = "#03924A",
  "Market gardening and crops" = "#74C48A", "Household hygiene and improved stoves" = "#950158", "Compost and soil fertility" = "#ECB897", "Roads, buildings and maintenance" = "#636466",
  "Training and capacity building" = "#FAB219", "School support" = "#89D1F4", "Cereal banks and storage" = "#F0512D", "Livestock and fish" = "#002F5A", "Other or unclear" = "#DADBDC",
  "Partner lump sum (COVID-19), not allocated" = "#B1B3B6"
)
LUMP_CATEGORY <- "Partner lump sum (COVID-19), not allocated"
fmt_xaf <- function(v) ifelse(is.na(v), "–", format(round(v), big.mark = ",", scientific = FALSE, trim = TRUE))
fmt_m <- function(v, d = 1) ifelse(is.na(v), "–", paste0(formatC(v / 1e6, format = "f", digits = d, big.mark = ","), " M"))

costs_ui <- function(id, d) {
  ns <- shiny::NS(id)
  r <- d$cost_recon; all <- r[r$period == "All", ]; lump <- r$reconciled_total_xaf[r$period == "2020 Apr-Dec"]
  l <- d$cost_link; linked <- sum(l$cost_xaf[l$status == "Cost and survey"], na.rm = TRUE)
  hh <- sum(l$households_surveyed, na.rm = TRUE); hh_linked <- sum(l$households_surveyed[l$status == "Cost and survey"], na.rm = TRUE)
  htmltools::tagList(
    page_intro("Costs", "WFP's resilience costs for 2019 to 2023: reconciled with the workbook, grouped by type of activity and linked to the surveys by department and year.", "cash-stack"),
    bslib::layout_column_wrap(
      width = "200px", fill = FALSE, heights_equal = "row",
      kpi("Total costs", paste0(formatC(all$reconciled_total_xaf / 1e9, format = "f", digits = 2), " bn XAF"), sprintf("%s XAF, 2019 to 2023", fmt_xaf(all$reconciled_total_xaf)), "cash-stack", "navy"),
      kpi("Left out of the workbook's total", paste0(fmt_m(all$difference_xaf), " XAF"), "Farchana, 2019: to confirm with WFP", "exclamation-triangle", "brown"),
      kpi("Lump sums, Apr-Dec 2020", paste0(fmt_m(lump, 0), " XAF"), sprintf("%s of all costs, not allocated to activities", fmt_pct(100 * lump / all$reconciled_total_xaf, 0)), "boxes", "slate"),
      kpi("Costs linked to surveyed areas", fmt_pct(100 * linked / all$reconciled_total_xaf, 1), "Same cost area and year", "link-45deg", "green"),
      kpi("Surveyed households with a cost", fmt_pct(100 * hh_linked / hh, 1), sprintf("%s of %s, 2019 to 2023", fmt_int(hh_linked), fmt_int(hh)), "people", "blue")
    ),
    callout(type = "info", htmltools::strong("How to read these costs. "),
            "The top of the page shows WFP's revised workbook: costs in XAF by partner and activity. April to December 2020 holds lump sums per partner, because of COVID-19, so they are never split across activities. ",
            "The section Cost per household shows the 44 cost variables of the merged file (do-file 21), built from IFPRI's community and household templates: see costs/README.md."),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(full_screen = TRUE, bslib::card_header("Costs by period and type of activity, million XAF"), plotly::plotlyOutput(ns("by_period"), height = "430px"),
                  bslib::card_footer(class = "table-note", "Grey: lump sums, kept apart. Categories come from keyword rules on the activity text (costs/activity_categories.csv) and need review.")),
      bslib::card(full_screen = TRUE, bslib::card_header("Reconciliation with the workbook, XAF"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("recon"))),
                  bslib::card_footer(class = "table-note", "Reconciled: sum of the cost lines, without subtotals. In 2019, the workbook's TOTAL GENERAL formula leaves out Farchana. Lines with an amount: in Apr-Dec 2020, only one per partner."))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header("Costs and surveyed households, by cost area and year"), plotly::plotlyOutput(ns("link"), height = "620px"),
                bslib::card_footer(class = "table-note", "Top: million XAF. Below: households surveyed. Blue: both. Amber: cost, but no survey that year. Grey: survey, but no cost that year. The survey year is the one in the merged file: the 2020 annual survey took place in January and February 2021.")),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(full_screen = TRUE, bslib::card_header("Activity categories by period, million XAF"), plotly::plotlyOutput(ns("cat_heat"), height = "430px")),
      bslib::card(full_screen = TRUE, bslib::card_header("By assistance type, million XAF"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("types"))),
                  bslib::card_footer(class = "table-note", "Cereal banks from community warehouses, training from capacity-building lines, the rest under other assets. WFP's single cost column cannot separate transfers from capacity costs."))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header("Department crosswalk: cost sheets to surveys"), reactable::reactableOutput(ns("crosswalk")),
                bslib::card_footer(class = "table-note", "Combined: one amount for two surveyed departments, not split. Assumed: to confirm with WFP. Surveyed departments missing from this list have no cost data: see the grey rows above.")),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(full_screen = TRUE, bslib::card_header("Assistance packages, USD per person per month"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("composition"))),
                  bslib::card_footer(class = "table-note", "From WFP's composition file: ration per person per day, and the package's value in USD. Not converted to XAF, as no exchange rate was provided.")),
      bslib::card(full_screen = TRUE, bslib::card_header("Costs by partner and year, million XAF"), reactable::reactableOutput(ns("partners")))
    ),
    household_costs_ui(ns, d)
  )
}

# ---- Cost per household: the cost variables of the merged file, as aggregates ------------------------------
household_costs_ui <- function(ns, d) {
  r <- d$cost_hh_round; led <- d$cost_ledger
  reach <- sum(led$transfer_xaf[grepl("^1", led$destination)] + led$capacity_xaf[grepl("^1", led$destination)]) / sum(led$transfer_xaf + led$capacity_xaf)
  htmltools::tagList(
    htmltools::h4(class = "mt-4", "Cost per household (merged file, do-file 21)"),
    bslib::layout_column_wrap(
      width = "200px", fill = FALSE, heights_equal = "row",
      kpi("Mean cost per household", paste0(fmt_xaf(sum(r$total_mean * r$with_total) / sum(r$with_total)), " XAF"), "Community plus household-level, 2019 to 2023", "cash-coin", "navy"),
      kpi("Households with a cost", fmt_pct(100 * sum(r$with_total) / sum(r$households), 1), sprintf("%s of %s surveyed from 2019", fmt_int(sum(r$with_total)), fmt_int(sum(r$households))), "people", "green"),
      kpi("Community cost unknown", fmt_int(sum(r$source_unknown)), "No cost or no beneficiary count for the area and year", "question-circle", "brown"),
      kpi("Template costs reaching households", fmt_pct(100 * reach, 1), "Surveyed village, same year; the rest is in the context variables", "diagram-3", "blue")
    ),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(full_screen = TRUE, bslib::card_header("Mean cost per household by round, XAF"), plotly::plotlyOutput(ns("hh_round"), height = "400px"),
                  bslib::card_footer(class = "table-note", "Over households with a cost. Transfer: cash for assets, participants only. Capacity: every household of a village with community costs. In 2020, lump sums spread over few declared beneficiaries raise the transfer cost.")),
      bslib::card(full_screen = TRUE, bslib::card_header("Source of the community cost, households"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("hh_source"))),
                  bslib::card_footer(class = "table-note", "Village: the village's costs per WFP beneficiary household. Area: the cost area's average. Unknown: left missing. Repeated: capacity cost that may repeat the transfer cost, to confirm with WFP."))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header("Mean cost per recipient household, by intervention and round, thousand XAF"), plotly::plotlyOutput(ns("hh_items"), height = "560px"),
                bslib::card_footer(class = "table-note", "Empty: not asked in that round, or fewer than 30 recipients. Combined: questions that join two interventions (2019 to 2021 PDM), costed by the rules in costs/household_unit_costs.csv.")),
    bslib::card(full_screen = TRUE, bslib::card_header("Community cost by asset type, mean per household, XAF"), plotly::plotlyOutput(ns("hh_assets"), height = "480px"),
                bslib::card_footer(class = "table-note", "Asset types from the keyword rules on the activity text. A cost covering several activities is shared equally between them. Grey: the 2020 lump sums, not allocated to an activity.")),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(full_screen = TRUE, bslib::card_header("Mean cost per household by region and round, thousand XAF"), plotly::plotlyOutput(ns("hh_region"), height = "430px"),
                  bslib::card_footer(class = "table-note", "Cells with fewer than 30 households with a cost are hidden.")),
      bslib::card(full_screen = TRUE, bslib::card_header("Where the community template's costs go, million XAF"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("ledger"))),
                  bslib::card_footer(class = "table-note", "Every franc of the template has one destination; the total equals the template. Other years: in the cumulated village variables. Not surveyed or no village: in the cost area variables."))
    ),
    bslib::card(full_screen = TRUE, bslib::card_header("Community template against WFP's revised workbook, XAF"), bslib::card_body(padding = 0, reactable::reactableOutput(ns("vs_revised"))),
                bslib::card_footer(class = "table-note", "The template is the reference for household costs (decision of 8 November 2026). Its transfer costs equal the revised workbook in 2020 January-March and 2021 only; the revised amount stays in cost_area_revised_xaf."))
  )
}

household_costs_server <- function(input, output, d) {
  lab <- function(rid) factor(d$rounds$label[match(rid, d$round_ids)], levels = d$round_levels)
  output$hh_round <- plotly::renderPlotly({
    r <- d$cost_hh_round; x <- lab(r$round_id)
    parts <- list(c("transfer_mean", "Transfer (cash for assets)", "#007DBC"), c("capacity_mean", "Capacity (community assets)", "#03924A"), c("interv_mean", "Household-level interventions", "#FAB219"))
    p <- plotly::plot_ly()
    for (k in parts) p <- plotly::add_bars(p, x = x, y = r[[k[1]]], name = k[2], marker = list(color = k[3]), hovertemplate = paste0("%{x}<br>", k[2], ": %{y:,.0f} XAF<extra></extra>"))
    p |> plotly_style(barmode = "stack", yaxis = list(tickformat = ",.0f"), margin = list(t = 40, r = 10)) |>
      plotly::layout(legend = list(orientation = "h", x = 0, y = 1.12, yanchor = "bottom"), xaxis = list(tickangle = -30))
  })
  output$hh_source <- reactable::renderReactable({
    r <- d$cost_hh_round
    t <- data.frame(Round = as.character(lab(r$round_id)), Households = r$households, Village = r$source_village, Area = r$source_area, `No cost` = r$source_none,
                    Unknown = r$source_unknown, Repeated = r$repeat_flag, check.names = FALSE)
    reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table",
                         defaultColDef = reactable::colDef(align = "right", minWidth = 62, format = reactable::colFormat(separators = TRUE)),
                         columns = list(Round = reactable::colDef(align = "left", class = "cell-label", minWidth = 110)))
  })
  output$hh_items <- plotly::renderPlotly({
    x <- d$cost_hh_items
    short <- c(cost_comm_transfer_xaf = "Cash for assets: community transfer", cost_comm_capacity_xaf = "Community assets: capacity",
               cost_lean_food_xaf = "Lean season: food", cost_lean_cash_xaf = "Lean season: cash", cost_lean_combined_xaf = "Lean season: food or cash",
               cost_blanket_children_xaf = "Blanket feeding: children", cost_blanket_women_xaf = "Blanket feeding: women", cost_blanket_combined_xaf = "Blanket feeding: children or women",
               cost_mam_children_xaf = "MAM treatment: children", cost_mam_women_xaf = "MAM treatment: women", cost_mam_combined_xaf = "Malnutrition treatment (combined)",
               cost_farn_xaf = "FARN", cost_school_meals_xaf = "School meals", cost_school_combined_xaf = "School meals or bursaries", cost_bursary_xaf = "Bursaries for girls")
    x$label <- ifelse(x$variable %in% names(short), short[x$variable], x$label)
    tot <- tapply(x$total_xaf, x$label, sum); rows <- names(sort(tot, decreasing = TRUE)); cols <- d$round_levels[d$round_ids %in% x$round_id]
    x$round <- as.character(lab(x$round_id))
    z <- tapply(x$mean_if_recipient, list(factor(x$label, levels = rows), factor(x$round, levels = cols)), function(v) v[1])
    n <- tapply(x$recipients, list(factor(x$label, levels = rows), factor(x$round, levels = cols)), function(v) v[1])
    hov <- matrix(sprintf("<b>%s · %s</b><br>%s XAF per recipient<br>%s recipients", rep(rows, length(cols)), rep(cols, each = length(rows)), fmt_xaf(z), ifelse(is.na(n), "not asked", fmt_int(n))), nrow = length(rows))
    cell <- matrix(ifelse(is.na(z), "", formatC(z / 1000, format = "f", digits = 0, big.mark = ",")), nrow = length(rows))
    round_heatmap(rows, cols, unname(z), hov, cell, list(c(0, "#F3F9FC"), c(.5, "#89D1F4"), c(1, "#004670")), colorbar = FALSE)
  })
  output$hh_assets <- plotly::renderPlotly({
    x <- d$cost_hh_assets
    tot <- tapply(x$mean_xaf * x$households, x$asset, sum); cats <- c(setdiff(names(sort(tot, decreasing = TRUE)), LUMP_CATEGORY), intersect(LUMP_CATEGORY, names(tot)))
    p <- plotly::plot_ly()
    for (k in cats) {
      s <- x[x$asset == k, ]
      p <- plotly::add_bars(p, x = lab(s$round_id), y = s$mean_xaf, name = k, marker = list(color = unname(CATEGORY_COL[k]), line = list(color = "#fff", width = .5)),
                            hovertemplate = paste0("%{x}<br>", k, ": %{y:,.0f} XAF<extra></extra>"))
    }
    p |> plotly_style(barmode = "stack", yaxis = list(tickformat = ",.0f"), margin = list(t = 20, r = 10)) |>
      plotly::layout(legend = list(orientation = "v", x = 1.02, y = 1, yanchor = "top", font = list(size = 11)), xaxis = list(tickangle = -30))
  })
  output$hh_region <- plotly::renderPlotly({
    x <- d$cost_hh_region[d$cost_hh_region$region != "" & !is.na(d$cost_hh_region$region), ]
    rows <- sort(unique(x$region)); cols <- d$round_levels[d$round_ids %in% x$round_id]; x$round <- as.character(lab(x$round_id))
    z <- tapply(x$total_mean / 1000, list(factor(x$region, levels = rows), factor(x$round, levels = cols)), function(v) v[1])
    n <- tapply(x$households, list(factor(x$region, levels = rows), factor(x$round, levels = cols)), function(v) v[1])
    hov <- matrix(sprintf("<b>%s · %s</b><br>%s thousand XAF<br>%s households", rep(rows, length(cols)), rep(cols, each = length(rows)), ifelse(is.na(z), "hidden or none", formatC(z, format = "f", digits = 0, big.mark = ",")), ifelse(is.na(n), "0", fmt_int(n))), nrow = length(rows))
    cell <- matrix(ifelse(is.na(z), "", formatC(z, format = "f", digits = 0, big.mark = ",")), nrow = length(rows))
    round_heatmap(rows, cols, unname(z), hov, cell, list(c(0, "#FFF8E6"), c(.5, "#FAB219"), c(1, "#AA5628")), colorbar = FALSE)
  })
  output$ledger <- reactable::renderReactable({
    x <- d$cost_ledger
    a <- stats::aggregate(cbind(transfer_xaf, capacity_xaf) ~ destination, x, sum)
    t <- data.frame(Destination = sub("^[0-9] ", "", a$destination), Transfer = round(a$transfer_xaf / 1e6, 1), Capacity = round(a$capacity_xaf / 1e6, 1))
    t <- rbind(t, data.frame(Destination = "Total, equal to the template", Transfer = sum(t$Transfer), Capacity = sum(t$Capacity)))
    reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table", rowClass = function(i) if (i == nrow(t)) "row-current",
                         defaultColDef = reactable::colDef(align = "right", minWidth = 80, format = reactable::colFormat(separators = TRUE, digits = 1)),
                         columns = list(Destination = reactable::colDef(align = "left", class = "cell-label", minWidth = 230)))
  })
  output$vs_revised <- reactable::renderReactable({
    x <- d$cost_vs_revised
    t <- data.frame(Period = x$period, Transfer = fmt_xaf(x$transfer_xaf), Capacity = fmt_xaf(x$capacity_xaf), Revised = fmt_xaf(x$revised_cash_xaf),
                    Difference = ifelse(abs(x$transfer_minus_revised_xaf) < 1, "0", fmt_xaf(x$transfer_minus_revised_xaf)), stringsAsFactors = FALSE)
    reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table", rowClass = function(i) if (t$Difference[i] != "0") "row-flag",
                         defaultColDef = reactable::colDef(align = "right", minWidth = 110),
                         columns = list(Period = reactable::colDef(align = "left", class = "cell-label", minWidth = 105), Revised = reactable::colDef(name = "Revised workbook"),
                                        Difference = reactable::colDef(name = "Transfer minus revised")))
  })
}

costs_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    periods <- d$cost_recon$period[d$cost_recon$period != "All"]

    output$by_period <- plotly::renderPlotly({
      x <- d$cost_category
      tot <- tapply(x$cash_xaf, x$amount_category, sum)
      cats <- c(setdiff(names(sort(tot, decreasing = TRUE)), LUMP_CATEGORY), LUMP_CATEGORY)
      p <- plotly::plot_ly()
      for (k in cats) {
        s <- x[x$amount_category == k, ]
        p <- plotly::add_bars(p, x = factor(s$period, levels = periods), y = s$cash_xaf / 1e6, name = k, marker = list(color = unname(CATEGORY_COL[k]), line = list(color = "#fff", width = .5)),
                              hovertemplate = paste0("%{x}<br>", k, ": %{y:,.1f} M XAF<extra></extra>"))
      }
      p |> plotly_style(barmode = "stack", xaxis = list(categoryorder = "array", categoryarray = periods), yaxis = list(ticksuffix = " M"), margin = list(t = 20, r = 10)) |>
        plotly::layout(legend = list(orientation = "v", x = 1.02, y = 1, yanchor = "top", font = list(size = 11)))
    })

    output$recon <- reactable::renderReactable({
      x <- d$cost_recon
      t <- data.frame(Period = x$period, Stated = fmt_xaf(x$stated_total_xaf), Reconciled = fmt_xaf(x$reconciled_total_xaf), Difference = ifelse(x$difference_xaf == 0, "0", fmt_xaf(x$difference_xaf)), Lines = x$lines_with_amount, stringsAsFactors = FALSE)
      reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table",
                           rowClass = function(i) if (t$Difference[i] != "0" && t$Period[i] != "All") "row-flag" else if (t$Period[i] == "All") "row-current",
                           defaultColDef = reactable::colDef(align = "right", minWidth = 108),
                           columns = list(Period = reactable::colDef(align = "left", class = "cell-label", minWidth = 105), Difference = reactable::colDef(minWidth = 95), Lines = reactable::colDef(name = "Lines with an amount", minWidth = 70)))
    })

    output$link <- plotly::renderPlotly({
      x <- d$cost_link
      x <- x[order(x$region, x$cost_area), ]
      rows <- unique(paste0(x$region, " · ", x$cost_area)); yrs <- as.character(sort(unique(x$year)))
      x$row <- paste0(x$region, " · ", x$cost_area)
      g <- function(col) tapply(x[[col]], list(factor(x$row, levels = rows), factor(as.character(x$year), levels = yrs)), function(v) v[1])
      cost <- g("cost_xaf"); hh <- g("households_surveyed"); st <- g("status"); lt <- g("link_type")
      z <- matrix(ifelse(st == "Cost and survey", 3, ifelse(st == "Cost only", 2, ifelse(st == "Survey only", 1, NA))), nrow = length(rows))
      cell <- matrix(ifelse(is.na(st), "", paste0(ifelse(is.na(cost), "–", formatC(cost / 1e6, format = "f", digits = 0, big.mark = ",")), "<br>", ifelse(is.na(hh), "–", fmt_int(hh)))), nrow = length(rows))
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s<br>%s XAF<br>%s households surveyed<br>Crosswalk: %s", rep(rows, length(yrs)), rep(yrs, each = length(rows)), ifelse(is.na(st), "No cost and no survey", st), fmt_xaf(cost), ifelse(is.na(hh), "0", fmt_int(hh)), ifelse(is.na(lt), "–", lt)), nrow = length(rows))
      round_heatmap(rows, yrs, z, hov, cell, list(c(0, "#E9ECEF"), c(.34, "#E9ECEF"), c(.34, "#FFF0C2"), c(.67, "#FFF0C2"), c(.67, "#B9E5FB"), c(1, "#B9E5FB")), 1, 3, colorbar = FALSE)
    })

    output$cat_heat <- plotly::renderPlotly({
      x <- d$cost_category[d$cost_category$amount_category != LUMP_CATEGORY, ]
      tot <- tapply(x$cash_xaf, x$amount_category, sum)
      rows <- names(sort(tot, decreasing = TRUE)); cols <- setdiff(periods, "2020 Apr-Dec")
      z <- tapply(x$cash_xaf / 1e6, list(factor(x$amount_category, levels = rows), factor(x$period, levels = cols)), sum)
      hov <- matrix(sprintf("<b>%s · %s</b><br>%s M XAF", rep(rows, length(cols)), rep(cols, each = length(rows)), ifelse(is.na(z), "0", formatC(z, format = "f", digits = 1, big.mark = ","))), nrow = length(rows))
      cell <- matrix(ifelse(is.na(z), "", formatC(z, format = "f", digits = 0, big.mark = ",")), nrow = length(rows))
      round_heatmap(rows, cols, unname(z), hov, cell, list(c(0, "#F3F9FC"), c(.5, "#89D1F4"), c(1, "#004670")), colorbar = FALSE)
    })

    output$types <- reactable::renderReactable({
      x <- d$cost_category; x$year <- substr(x$period, 1, 4)
      a <- stats::aggregate(cash_xaf ~ assistance_type + year, x, sum)
      w <- stats::reshape(a, idvar = "assistance_type", timevar = "year", direction = "wide"); names(w) <- sub("cash_xaf\\.", "", names(w))
      lab <- c(BanqueCerealiere = "Cereal banks", FormationRenfCapacite = "Training", `Other assets` = "Other assets", `Not allocated` = "Lump sums, not allocated")
      w <- w[match(names(lab), w$assistance_type), ]
      yrs <- sort(setdiff(names(w), "assistance_type"))
      t <- data.frame(Type = unname(lab), stringsAsFactors = FALSE); for (y in yrs) t[[y]] <- round(w[[y]] / 1e6, 1)
      reactable::reactable(t, compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table", defaultColDef = reactable::colDef(align = "right", minWidth = 58, na = "–", format = reactable::colFormat(separators = TRUE, digits = 1)),
                           columns = list(Type = reactable::colDef(align = "left", class = "cell-label", minWidth = 130)))
    })

    output$crosswalk <- reactable::renderReactable({
      x <- d$cost_crosswalk
      t <- data.frame(`In the cost sheets` = x$cost_department, Region = x$region, `In the surveys` = ifelse(is.na(x$survey_department), "–", paste0(x$survey_department, " (", x$adm2_ocha, ")")), Link = x$link_type, Note = ifelse(is.na(x$note), "", x$note), check.names = FALSE, stringsAsFactors = FALSE)
      col <- c("Same name" = "#035537", Renamed = "#004670", Combined = "#AA5628", Assumed = "#83610A", `No survey department` = "#636466")
      reactable::reactable(t, compact = TRUE, pagination = FALSE, striped = TRUE,
                           columns = list(`In the cost sheets` = reactable::colDef(minWidth = 170, class = "cell-label"), Region = reactable::colDef(minWidth = 100), `In the surveys` = reactable::colDef(minWidth = 170),
                                          Link = reactable::colDef(minWidth = 150, cell = function(v) pill(v, col[[v]])), Note = reactable::colDef(minWidth = 440, style = list(fontSize = ".76rem"))))
    })

    output$composition <- reactable::renderReactable({
      x <- d$composition
      t <- do.call(rbind, lapply(split(x, paste(x$programme, x$target), drop = TRUE), function(g) data.frame(
        Programme = g$programme[1], Target = g$target[1], Ration = paste(sprintf("%s %s g", g$commodity, g$grams_per_person_day), collapse = ", "), USD = g$value_usd_per_person_month[1], stringsAsFactors = FALSE)))
      reactable::reactable(t[order(t$Programme), ], compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table", rownames = FALSE,
                           columns = list(Programme = reactable::colDef(class = "cell-label", minWidth = 95), Target = reactable::colDef(minWidth = 110), Ration = reactable::colDef(name = "Ration per person per day", minWidth = 190, style = list(fontSize = ".76rem")),
                                          USD = reactable::colDef(name = "USD per person per month", align = "right", minWidth = 80, format = reactable::colFormat(digits = 2))))
    })

    output$partners <- reactable::renderReactable({
      x <- d$cost_partner
      a <- stats::aggregate(cash_xaf ~ partner + year, x, sum)
      w <- stats::reshape(a, idvar = "partner", timevar = "year", direction = "wide"); names(w) <- sub("cash_xaf\\.", "", names(w))
      yrs <- sort(setdiff(names(w), "partner"))
      t <- data.frame(Partner = w$partner, stringsAsFactors = FALSE); for (y in yrs) t[[y]] <- round(w[[y]] / 1e6, 1)
      t$Total <- rowSums(t[yrs], na.rm = TRUE)
      reactable::reactable(t[order(-t$Total), ], compact = TRUE, striped = TRUE, defaultPageSize = 12, searchable = TRUE, defaultColDef = reactable::colDef(align = "right", minWidth = 70, na = "–", format = reactable::colFormat(separators = TRUE, digits = 1)),
                           columns = list(Partner = reactable::colDef(align = "left", class = "cell-label", minWidth = 125), Total = reactable::colDef(style = list(fontWeight = 700))))
    })

    household_costs_server(input, output, d)
  })
}
