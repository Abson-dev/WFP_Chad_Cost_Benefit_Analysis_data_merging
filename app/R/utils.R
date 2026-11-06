# Theme, palettes, the indicator catalogue and small UI helpers shared by all pages.

# Colours: WFP Visual Brand Guide v6.0 (October 2025), pages 26-29. Keep in step with www/styles.css.
COL <- list(
  navy = "#002F5A", blue = "#007DBC", blue_dark = "#004670", sand = "#F9F4DF", ink = "#231F20", muted = "#636466",
  grid = "#E6E9EE", na = "#E9ECEF", orange = "#F0512D", red = "#E3002B", brown = "#AA5628", green = "#03924A", green_dark = "#035537"
)
SERIES_COL <- c("Post-harvest" = COL$blue, "Lean season" = COL$orange)
FCS_COL <- c(Poor = "#E3002B", Borderline = "#F8A07E", Acceptable = "#03924A")
LCS_COL <- c("No coping" = "#D5ECDD", Stress = "#FAE61E", Crisis = "#E67800", Emergency = "#AB1A1A")
STATUS_COL <- c(pass = "#035537", warn = "#83610A", fail = "#7F1724")
STATUS_LABEL <- c(pass = "Passed", warn = "Review", fail = "Failed")
COVERAGE_SCALE <- list(c(0, "#E3002B"), c(0.5, "#ECE1B1"), c(0.95, "#74C48A"), c(1, "#03924A"))

app_theme <- function() {
  bslib::bs_theme(
    version = 5,
    bg = "#FFFFFF", fg = COL$ink, primary = COL$blue, secondary = COL$navy,
    success = "#03924A", warning = "#F0512D", danger = "#E3002B", info = "#008EB2",
    base_font = bslib::font_collection("Open Sans", "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"),
    heading_font = bslib::font_collection("Open Sans", "Segoe UI", "Roboto", "Arial", "sans-serif"),
    "navbar-bg" = COL$navy, "border-radius" = "0.6rem", "card-border-color" = COL$grid
  )
}

fmt_int <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
fmt_pct <- function(x, d = 1) ifelse(is.na(x), "–", paste0(formatC(x, format = "f", digits = d), "%"))
fmt_dates <- function(a, b) sprintf("%s to %s", format(as.Date(a), "%d %b %Y"), format(as.Date(b), "%d %b %Y"))

# Consistent plotly look; call last in each chart. Settings in ... override the defaults
# (axis, legend and margin lists are merged, not replaced).
plotly_style <- function(p, legend = TRUE, ...) {
  base <- list(
    font = list(family = "Open Sans, Segoe UI, Arial, sans-serif", size = 12, color = COL$ink),
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
    xaxis = list(gridcolor = COL$grid, zeroline = FALSE, title = list(text = ""), automargin = TRUE),
    yaxis = list(gridcolor = COL$grid, zeroline = FALSE, title = list(text = ""), automargin = TRUE),
    legend = list(orientation = "h", y = 1.14, x = 0, yanchor = "bottom"),
    showlegend = legend, hoverlabel = list(font = list(family = "Open Sans, Segoe UI, Arial")),
    margin = list(t = if (legend) 60 else 30, r = 20, b = 30, l = 50)
  )
  extra <- list(...)
  for (k in names(extra)) {
    base[[k]] <- if (is.list(base[[k]]) && is.list(extra[[k]])) utils::modifyList(base[[k]], extra[[k]]) else extra[[k]]
  }
  for (ax in c("xaxis", "yaxis")) {
    if (is.character(base[[ax]]$title)) base[[ax]]$title <- list(text = base[[ax]]$title)
  }
  do.call(plotly::layout, c(list(p), base)) |>
    plotly::config(displaylogo = FALSE, modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d"),
                   toImageButtonOptions = list(format = "png", scale = 2))
}

# Page header: icon, title, one-line purpose and, on the pages that follow it, the reference round.
page_intro <- function(title, text, icon = "info-circle", right = NULL) {
  htmltools::div(
    class = "page-head",
    htmltools::div(class = "page-icon", bsicons::bs_icon(icon)),
    htmltools::div(class = "page-text", htmltools::h2(title), htmltools::p(text)),
    right
  )
}

brand <- function() {
  htmltools::div(class = "brand",
                 htmltools::span(class = "brand-title", "WFP Chad · Data merging"),
                 htmltools::span(class = "brand-sub", "Resilience CBA surveys, 2018–2023"))
}

# tone: navy, blue, orange, red, brown, green, slate.
kpi <- function(title, value, detail, icon, tone = "slate") {
  bslib::value_box(title, value, htmltools::div(class = "kpi-detail", detail), class = paste0("kpi tone-", tone),
                   showcase = bsicons::bs_icon(icon), showcase_layout = bslib::showcase_left_center(width = 0.22))
}

pill <- function(text, colour, text_colour = "#fff") {
  htmltools::span(class = "pill", style = sprintf("background:%s;color:%s", colour, text_colour), text)
}

status_pill <- function(s) pill(unname(STATUS_LABEL[s]), unname(STATUS_COL[s]))

callout <- function(..., type = c("info", "warning", "success")) {
  type <- match.arg(type)
  icon <- c(info = "info-circle", warning = "exclamation-triangle", success = "check-circle")[[type]]
  htmltools::div(class = paste("callout", paste0("callout-", type)),
                 bsicons::bs_icon(icon, size = "1.2em"), htmltools::div(...))
}

legend_row <- function(col, txt) {
  htmltools::div(class = "legend-row", htmltools::span(class = "swatch", style = sprintf("background:%s", col)), txt)
}

round_chip <- function(d, ref) {
  shiny::renderUI({
    r <- d$rounds[d$rounds$round_id == ref(), ]
    htmltools::div(class = "round-chip", bsicons::bs_icon("calendar3"), htmltools::strong(r$label),
                   htmltools::span(fmt_dates(r$date_p01, r$date_p99)))
  })
}

# ---- Indicator catalogue ------------------------------------------------------------------------
# Columns <id>_m (as merged) and <id>_c (with indicative corrections) come from prepare_app_data.R.
# group: which flags apply to the indicator.

IND <- data.frame(
  id = c("fcs_pb", "fcs_poor", "fcs_mean", "rcsi_mean", "rcsi_p3", "lcs_ce", "lcs_em", "lcs_none", "hdds_mean", "hdds_low",
         "abi_mean", "rcs_mean", "rcs_low", "rcs_high", "ch_p3", "female_head", "hh_size"),
  label = c("Poor + borderline food consumption (28/42)", "Poor food consumption (28/42)", "Mean Food Consumption Score",
            "Mean reduced Coping Strategies Index", "rCSI of 19 or more (Cadre Harmonisé phase 3+)",
            "Crisis + emergency livelihood coping", "Emergency livelihood coping", "No livelihood coping",
            "Mean Household Dietary Diversity Score", "HDDS of 4 food groups or fewer (IPC phase 3+)",
            "Mean Asset Benefit Indicator (0 to 7)", "Mean Resilience Capacity Score (0 to 100)", "Low resilience capacity (below 33)", "High resilience capacity (66 or more)",
            "Households in a Cadre Harmonisé phase 3+ department", "Female-headed households", "Mean household size"),
  short = c("Poor + borderline FCS", "Poor FCS", "Mean FCS", "Mean rCSI", "rCSI 19+", "Crisis + emergency LCS", "Emergency LCS", "No LCS",
            "Mean HDDS", "HDDS 4 or fewer", "Mean ABI", "Mean RCS", "Low RCS", "High RCS", "CH phase 3+ area", "Female-headed", "Household size"),
  domain = c("FCS", "FCS", "FCS", "rCSI", "rCSI", "LCS", "LCS", "LCS", "HDDS", "HDDS", "ABI", "RCS", "RCS", "RCS", "Cadre Harmonisé", "Household", "Household"),
  unit = c("%", "%", "score", "score", "%", "%", "%", "%", "score", "%", "score", "score", "%", "%", "%", "%", "members"),
  # Which end of the scale is the worse one, for the colour scale of the regional maps.
  worse = c("high", "high", "low", "high", "high", "high", "high", "low", "low", "high", "low", "low", "high", "low", "high", "none", "none"),
  group = c("fcs", "fcs", "fcs", "rcsi", "rcsi", "lcs", "lcs", "lcs", NA, NA, "abi", NA, NA, NA, NA, NA, "hhsize"),
  stringsAsFactors = FALSE
)
# Modules added in November 2026 (Rmds 16 to 23). Asked in fewer rounds: empty rounds show as gaps.
IND <- rbind(IND, data.frame(
  id = c("shk_any12m", "shk_any6m", "shk_drought", "shk_price", "lvs_any", "lvs_tlu", "ast_radio", "ast_phone", "liv_nsrc", "liv_farm",
         "agr_practice", "agr_owner", "agr_6m", "exp_share", "exp_share75", "dis_any", "edu_primary", "edu_girls", "mig_work"),
  label = c("At least one of 17 shocks in the last 12 months", "A shock in the last 6 months", "Drought or irregular rain in the last 12 months",
            "Food price rise in the last 12 months", "Households owning livestock", "Mean livestock holding (TLU)", "Households owning a radio",
            "Households owning a mobile phone", "Mean number of income sources", "Main income from food or cash crops",
            "Households farming in the last season", "Farming mostly their own land", "Own production covers 6 months or more",
            "Mean food expenditure share", "Food expenditure share of 75% or more", "A member with a lot of difficulty in a functional domain",
            "Children attending primary school", "Girls attending primary school", "Members migrated for work in the last 12 months"),
  short = c("Any shock (12 m)", "Shock (6 m)", "Drought (12 m)", "Food price rise (12 m)", "Own livestock", "Mean TLU", "Own a radio", "Own a phone",
            "Income sources", "Income from crops", "Farming", "Own land farmed", "Own food 6+ months", "Food share", "Food share 75%+",
            "Disability", "Children at primary", "Girls at primary", "Work migration"),
  domain = c("Shocks", "Shocks", "Shocks", "Shocks", "Assets and livestock", "Assets and livestock", "Assets and livestock", "Assets and livestock",
             "Livelihoods", "Livelihoods", "Agriculture", "Agriculture", "Agriculture", "Expenditure", "Expenditure", "Disability", "Education", "Education", "Migration"),
  unit = c("%", "%", "%", "%", "%", "TLU", "%", "%", "sources", "%", "%", "%", "%", "%", "%", "%", "%", "%", "%"),
  worse = c("high", "high", "high", "high", "low", "low", "low", "low", "low", "none", "none", "none", "low", "high", "high", "none", "low", "low", "none"),
  group = NA_character_, stringsAsFactors = FALSE))
IND <- rbind(IND, data.frame(
  id = c("prt_any", "aap_informed", "aap_complaint", "aap_women", "dbt_contracted", "dbt_current"),
  label = c("A safety, access or other problem linked to the assistance", "Informed about selection, entitlement and distribution cycle",
            "Filed a complaint about the assistance", "Women decide, alone or jointly, how the assistance is used",
            "Contracted a debt in the reference period", "Currently in debt"),
  short = c("Protection problem", "Informed (AAP)", "Complaint filed", "Women decide on assistance", "Contracted debt", "In debt"),
  domain = c("Protection and accountability", "Protection and accountability", "Protection and accountability", "Protection and accountability", "Debt", "Debt"),
  unit = "%", worse = c("high", "low", "none", "low", "high", "high"), group = NA_character_, stringsAsFactors = FALSE))
IND <- rbind(IND, data.frame(
  id = c("coh_hosts_good", "coh_tension", "coh_nobody", "adp_apply_any", "adp_trained", "adp_compost"),
  label = c("Relations with the host population rated polite or friendly", "Assets helped reduce tensions over natural resources",
            "Could help nobody in the community", "Applies at least one of four adaptation techniques",
            "Received training in agriculture", "Uses compost pits"),
  short = c("Good relations with hosts", "Tensions reduced", "Could help nobody", "Applies adaptation", "Trained in agriculture", "Compost pits"),
  domain = c("Social cohesion", "Social cohesion", "Social cohesion", "Climate adaptation", "Climate adaptation", "Climate adaptation"),
  unit = "%", worse = c("low", "low", "high", "low", "low", "low"), group = NA_character_, stringsAsFactors = FALSE))
IND_CHOICES <- lapply(split(IND, factor(IND$domain, levels = unique(IND$domain))), function(g) stats::setNames(g$id, g$label))
# In the tables of the Overview and Regions pages.
IND_MAIN <- c("fcs_pb", "fcs_poor", "fcs_mean", "rcsi_mean", "rcsi_p3", "lcs_ce", "hdds_mean", "abi_mean", "rcs_mean", "female_head", "hh_size")

ind_info <- function(id) IND[match(id, IND$id), ]
is_pct <- function(id) ind_info(id)$unit == "%"
metric_label <- function(id) ind_info(id)$label

# Rounds whose cell is flagged for this indicator under the chosen figures.
flagged_rounds <- function(d, id, est = "m") {
  g <- ind_info(id)$group
  if (is.na(g)) return(character(0))
  f <- d$flags[d$flags$indicator_group == g, , drop = FALSE]
  if (identical(est, "c")) f <- f[!f$fixed, , drop = FALSE]
  f$round_id
}

ind_value <- function(x, id, est = "m", d = NULL) {
  v <- x[[paste0(id, "_", est)]]
  fl <- if (is.null(d)) rep(FALSE, length(v)) else x$round_id %in% flagged_rounds(d, id, est)
  list(v = v, flagged = fl)
}

fmt_ind <- function(v, id) {
  ifelse(is.na(v), "–", if (is_pct(id)) fmt_pct(v) else formatC(v, format = "f", digits = if (ind_info(id)$unit == "members") 1 else 1))
}

# Change since the latest earlier round of the same series with a usable value. Flagged cells are
# neither compared nor used as a base, so that a defect is not read as a change.
ind_compare <- function(x, id, rid, est = "m", d = NULL) {
  cur <- x[x$round_id == rid, , drop = FALSE]
  a <- ind_value(cur, id, est, d)
  out <- list(value = if (nrow(cur)) a$v else NA_real_, flagged = nrow(cur) > 0 && a$flagged,
              base_round = NA_character_, base_id = NA_character_, diff = NA_real_)
  if (!nrow(cur) || is.na(out$value) || out$flagged) return(out)
  ear <- x[x$series == cur$series & x$round < cur$round, , drop = FALSE]
  ear <- ear[order(ear$round, decreasing = TRUE), , drop = FALSE]
  b <- ind_value(ear, id, est, d)
  ear <- ear[!is.na(b$v) & !b$flagged, , drop = FALSE]
  if (!nrow(ear)) return(out)
  base <- ear[1, , drop = FALSE]
  col <- paste0(id, "_", est)
  out$base_round <- as.character(base$label)
  out$base_id <- base$round_id
  out$diff <- cur[[col]] - base[[col]]
  out
}

# Rises are not painted as good or bad: the comparison has no significance test and no weights.
change_tag <- function(cmp, id, html = FALSE) {
  if (isTRUE(cmp$flagged)) return(if (html) "<span class='flag-text'>flagged</span>" else "Known defect: not compared")
  if (is.na(cmp$diff)) return(if (html) "<span class='muted'>–</span>" else "No earlier usable round in this series")
  up <- cmp$diff >= 0
  unit <- if (is_pct(id)) "pts" else ""
  arrow <- sprintf("%s%s%s", if (up) "▲ +" else "▼ −", formatC(abs(cmp$diff), format = "f", digits = 1),
                   if (nzchar(unit)) paste0(" ", unit) else "")
  if (html) return(sprintf("<span class='%s'>%s</span>", if (up) "rise" else "fall", arrow))
  htmltools::tagList(htmltools::span(class = if (up) "rise" else "fall", arrow), sprintf(" vs %s", cmp$base_round))
}

# Table of indicators by round, with the reference round highlighted and the same-series change.
ind_reactable <- function(x, ids, round_ids, rid, est, d) {
  show <- x[x$round_id %in% round_ids, , drop = FALSE]
  show <- show[order(show$round), , drop = FALSE]
  labs <- as.character(show$label)
  tab <- data.frame(Indicator = ind_info(ids)$short, check.names = FALSE, stringsAsFactors = FALSE)
  for (k in seq_along(labs)) {
    tab[[labs[k]]] <- vapply(ids, function(id) {
      r <- ind_value(show[k, , drop = FALSE], id, est, d)
      txt <- fmt_ind(r$v, id)
      if (r$flagged && !is.na(r$v)) sprintf("<span class='flag-text'>%s †</span>", txt) else txt
    }, "")
  }
  tab$Change <- vapply(ids, function(id) change_tag(ind_compare(x, id, rid, est, d), id, html = TRUE), "")
  current <- as.character(show$label[show$round_id == rid])
  cols <- list(
    Indicator = reactable::colDef(minWidth = 165, class = "cell-label"),
    Change = reactable::colDef(name = "Change in series", html = TRUE, align = "right", minWidth = 100)
  )
  for (l in labs) {
    cur <- identical(l, current)
    cols[[l]] <- reactable::colDef(align = "right", minWidth = 72, html = TRUE, class = if (cur) "cell-current", headerClass = if (cur) "head-current")
  }
  reactable::reactable(tab, columns = cols, compact = TRUE, pagination = FALSE, striped = TRUE, sortable = FALSE,
                       highlight = TRUE, class = "dark-table")
}

# Same-series bars up to the reference round, darker for the reference; hatched if flagged.
series_bars <- function(x, id, rid, est, d, colour, dark) {
  ser <- x$series[x$round_id == rid]
  rnd <- x$round[x$round_id == rid]
  x <- x[x$series == ser & x$round <= rnd, , drop = FALSE]
  x <- x[order(x$round), , drop = FALSE]
  r <- ind_value(x, id, est, d)
  shiny::validate(shiny::need(any(!is.na(r$v)), "Not collected in the rounds of this series."))
  lab <- as.character(x$label)
  plotly::plot_ly(x = factor(lab, levels = lab), y = r$v, type = "bar",
                  marker = list(color = ifelse(x$round_id == rid, dark, colour),
                                pattern = list(shape = ifelse(r$flagged, "/", ""), fillmode = "overlay",
                                               fgcolor = "rgba(255,255,255,0.75)", size = 6, solidity = 0.3)),
                  text = fmt_ind(r$v, id), textposition = "outside", cliponaxis = FALSE,
                  hovertemplate = paste0("%{x}: %{text}", ifelse(r$flagged, " (known defect)", ""), "<extra></extra>")) |>
    plotly_style(legend = FALSE, bargap = 0.3, margin = list(t = 24, r = 8, b = 30, l = 8),
                 xaxis = list(title = "", tickangle = -30),
                 yaxis = list(title = "", showticklabels = FALSE, showgrid = FALSE,
                              range = c(0, 1.2 * max(c(r$v, 1), na.rm = TRUE))))
}

# Regional heatmap colour scale, by which end of the indicator is the worse one.
heat_scale <- function(id) {
  switch(ind_info(id)$worse,
         low = list(c(0, "#E3002B"), c(0.5, "#F9F4DF"), c(1, "#007DBC")),
         high = list(c(0, "#F9F4DF"), c(1/3, "#F8A07E"), c(2/3, "#F0512D"), c(1, "#9A331B")),
         list(c(0, "#B9E5FB"), c(0.5, "#007DBC"), c(1, "#004670")))
}

# Heatmap of a value on rows x rounds, with the number written in each cell.
round_heatmap <- function(rows, round_labels, z, hover, cell, colorscale, zmin = NULL, zmax = NULL, suffix = "", colorbar = TRUE, ...) {
  args <- list(x = round_labels, y = rows, z = z, type = "heatmap", colorscale = colorscale, xgap = 2, ygap = 2,
               text = cell, customdata = hover, hovertemplate = "%{customdata}<extra></extra>",
               texttemplate = "%{text}", textfont = list(size = 10), showscale = colorbar,
               colorbar = list(thickness = 12, ticksuffix = suffix))
  if (!is.null(zmin)) args$zmin <- zmin
  if (!is.null(zmax)) args$zmax <- zmax
  do.call(plotly::plot_ly, args) |>
    plotly_style(legend = FALSE, plot_bgcolor = "#F1F3F5",
                 xaxis = list(title = "", side = "top", tickangle = -35, showgrid = FALSE, type = "category"),
                 yaxis = list(title = "", showgrid = FALSE, autorange = "reversed", type = "category"),
                 margin = list(l = 10, r = 10, t = 70, b = 10), ...)
}
