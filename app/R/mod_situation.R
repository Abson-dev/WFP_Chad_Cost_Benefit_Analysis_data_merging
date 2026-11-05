# Overview: the reference round in one page, and what to check before using its figures.

situation_ui <- function(id, d) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    page_intro("Overview", "The households surveyed in the reference round, compared with the previous round of the same series.",
               "speedometer2", shiny::uiOutput(ns("chip"))),
    shiny::uiOutput(ns("kpis")),
    bslib::layout_columns(
      col_widths = c(5, 7),
      bslib::card(height = 520, bslib::card_header(bsicons::bs_icon("bell"), " Points of attention"),
                  bslib::card_body(shiny::uiOutput(ns("attention")))),
      bslib::card(height = 520, full_screen = TRUE, bslib::card_header("Indicators, latest rounds of the same series"),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("table"))),
                  bslib::card_footer(class = "table-note",
                                     "† Known defect in the merged file: left out of comparisons (see Data issues). Change in percentage points (pts) or score points against the previous usable round of the series, with no significance test. All figures are unweighted."))
    ),
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      bslib::card(bslib::card_header("Poor + borderline food consumption"), plotly::plotlyOutput(ns("g_fcs"), height = "230px")),
      bslib::card(bslib::card_header("Mean rCSI"), plotly::plotlyOutput(ns("g_rcsi"), height = "230px")),
      bslib::card(bslib::card_header("Crisis + emergency coping"), plotly::plotlyOutput(ns("g_lcs"), height = "230px"))
    )
  )
}

# What a reader should know before using the figures of a round. Levels: serious, watch, info, ok.
attention_points <- function(d, rid, est = "m") {
  out <- list()
  add <- function(level, title, detail) out[[length(out) + 1]] <<- list(level = level, title = title, detail = detail)
  r <- d$rounds[d$rounds$round_id == rid, ]
  nat <- d$ind_round
  cur <- nat[nat$round_id == rid, ]

  # Known defects in this round.
  fl <- d$flags[d$flags$round_id == rid, , drop = FALSE]
  names_group <- c(fcs = "Food consumption score", rcsi = "rCSI", lcs = "Livelihood coping", abi = "Asset benefit score", hhsize = "Household size")
  for (i in seq_len(nrow(fl))) {
    unresolved <- !fl$fixed[i]
    if (est == "c" && !unresolved) {
      add("watch", sprintf("%s: indicative correction shown", names_group[[fl$indicator_group[i]]]),
          paste0("The merged file holds another value. ", fl$reason[i]))
    } else if (unresolved) {
      add("watch", sprintf("%s: uncertain", names_group[[fl$indicator_group[i]]]), fl$reason[i])
    } else {
      add("serious", sprintf("%s: known defect", names_group[[fl$indicator_group[i]]]), paste(fl$reason[i], "Do not use until fixed."))
    }
  }

  # Comparability with the base round of the series.
  ear <- nat[nat$series == cur$series & nat$round < cur$round, , drop = FALSE]
  if (!nrow(ear)) {
    add("watch", "First round of its series", "No earlier round of this season, so no change can be shown.")
  } else {
    base <- ear[which.max(ear$round), ]
    reg <- d$ind_region
    a <- reg$region[reg$round_id == rid]; b <- reg$region[reg$round_id == base$round_id]
    gone <- setdiff(b, a); new <- setdiff(a, b)
    if (length(gone) || length(new)) {
      add("watch", sprintf("Different regions than %s", base$label),
          paste0(c(if (length(new)) paste("New:", paste(new, collapse = ", ")), if (length(gone)) paste("Absent:", paste(gone, collapse = ", "))), collapse = ". "))
    }
  }

  modules <- c("fcs_pb", "rcsi_mean", "lcs_ce", "hdds_mean", "abi_mean", "rcs_mean")
  absent <- modules[is.na(vapply(modules, function(id) ind_value(cur, id, est)$v, 0))]
  if (length(absent)) add("info", "Not collected in this round", paste(ind_info(absent)$short, collapse = ", "))
  if (r$dates_outside + r$dates_missing > 0) {
    add("info", "Interview dates to check", sprintf("%d outside the fieldwork, %d missing. Phases are not affected.", r$dates_outside, r$dates_missing))
  }

  reg_r <- d$ind_region[d$ind_region$round_id == rid, ]
  fcs_ok <- !(rid %in% flagged_rounds(d, "fcs_pb", est))
  v <- ind_value(reg_r, "fcs_pb", est)$v
  if (fcs_ok && any(!is.na(v))) {
    o <- order(v, decreasing = TRUE, na.last = NA)[seq_len(min(3, sum(!is.na(v))))]
    add("info", "Highest poor + borderline food consumption", paste(sprintf("%s %s", reg_r$region[o], fmt_pct(v[o], 0)), collapse = " · "))
  }
  n_small <- sum(reg_r$households < d$manifest$min_cell)
  if (n_small) add("info", "Regions without an estimate", sprintf("%d region(s) with fewer than %d households in this round.", n_small, d$manifest$min_cell))
  if (!any(vapply(out, function(p) p$level %in% c("serious", "watch"), TRUE))) {
    add("ok", "No specific caution for this round", "No known defect in its indicators, and comparable regions with the previous round of its series.")
  }
  rank <- c(serious = 1, watch = 2, ok = 3, info = 4)
  out[order(rank[vapply(out, `[[`, "", "level")])]
}

attention_ui <- function(points) {
  icons <- c(serious = "exclamation-triangle-fill", watch = "exclamation-circle-fill", info = "info-circle-fill", ok = "check-circle-fill")
  htmltools::div(class = "alert-stack", lapply(points, function(p) {
    htmltools::div(class = paste("attention", p$level), bsicons::bs_icon(icons[[p$level]]),
                   htmltools::div(htmltools::strong(p$title), htmltools::div(class = "detail", p$detail)))
  }))
}

situation_server <- function(id, d, ref, est) {
  shiny::moduleServer(id, function(input, output, session) {
    nat <- d$ind_round
    output$chip <- round_chip(d, ref)

    output$kpis <- shiny::renderUI({
      rid <- ref(); e <- est()
      r <- d$rounds[d$rounds$round_id == rid, ]
      card <- function(id, title, icon, tone) {
        cmp <- ind_compare(nat, id, rid, e, d)
        kpi(title, fmt_ind(cmp$value, id),
            if (is.na(cmp$value)) "Not collected in this round" else change_tag(cmp, id), icon, if (cmp$flagged) "flag" else tone)
      }
      bslib::layout_column_wrap(
        width = "160px", fill = FALSE, heights_equal = "row",
        kpi("Households", fmt_int(r$final_rows), sprintf("%d regions · unweighted", r$regions), "people", "slate"),
        card("fcs_pb", "Poor + borderline FCS", "basket", "orange"),
        card("rcsi_mean", "Mean rCSI", "shield-exclamation", "red"),
        card("lcs_ce", "Crisis + emergency coping", "life-preserver", "brown"),
        card("abi_mean", "Mean asset benefit", "tree", "green"),
        card("rcs_mean", "Mean resilience capacity", "arrow-repeat", "blue")
      )
    })

    output$attention <- shiny::renderUI(attention_ui(attention_points(d, ref(), est())))

    output$table <- reactable::renderReactable({
      rid <- ref()
      ser <- nat$series[nat$round_id == rid]; rnd <- nat$round[nat$round_id == rid]
      same <- nat$round_id[nat$series == ser & nat$round <= rnd]
      ind_reactable(nat, IND_MAIN, utils::tail(same, 4), rid, est(), d)
    })

    output$g_fcs <- plotly::renderPlotly(series_bars(nat, "fcs_pb", ref(), est(), d, "#FBC4A8", "#F0512D"))
    output$g_rcsi <- plotly::renderPlotly(series_bars(nat, "rcsi_mean", ref(), est(), d, "#F9B9B7", "#E3002B"))
    output$g_lcs <- plotly::renderPlotly(series_bars(nat, "lcs_ce", ref(), est(), d, "#ECB897", "#AA5628"))
  })
}
