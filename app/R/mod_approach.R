# Approach: why the merge is hard, how it is done, and how the indicators are defined.

approach_ui <- function(id, d) {
  ns <- shiny::NS(id)
  r <- d$rounds; m <- d$manifest
  step <- function(n, icon, title, text) {
    htmltools::div(class = "step", htmltools::div(class = "step-num", n), htmltools::div(class = "step-icon", bsicons::bs_icon(icon, size = "1.5em")),
                   htmltools::h5(title), htmltools::p(class = "small", text))
  }
  defs <- data.frame(
    Indicator = c("Food Consumption Score (FCS)", "Reduced Coping Strategies Index (rCSI)", "Livelihood coping (LCS)", "Dietary diversity (HDDS)", "Asset Benefit Indicator (ABI)", "Resilience Capacity Score (RCS)", "Cadre Harmonisé phase"),
    Definition = c("Days eaten in the last 7 days, weighted: cereals x2, pulses x3, dairy x4, protein x4, vegetables x1, fruit x1, fat x0.5, sugar x0.5. Poor up to 28, borderline up to 42.",
                   "Days of each strategy in the last 7 days, weighted: less preferred food x1, borrowing x2, fewer meals x1, smaller portions x1, adults eating less x3. On this dashboard, 19 or more is shown as phase 3+.",
                   "Highest level among 10 strategies answered Yes or already exhausted: stress (4), crisis (3), emergency (3).",
                   "Food groups out of 12 eaten in the last 24 hours. 4 or fewer is shown as IPC phase 3+.",
                   "Yes answers out of 7 questions on the benefits of assets created or rehabilitated. Don't know counts as 0.",
                   "Mean of 9 statements on a 5-point scale, rescaled to 0-100. Low below 33, high from 66.",
                   "Current-period phase of the household's department in the Cadre Harmonisé analysis of the same year and cycle."),
    Rounds = c("All", "All", "All", "From 2022 PDM", "All but the baseline", "2020 Annual and from 2021 Annual", "All; 35 households without"),
    stringsAsFactors = FALSE)
  htmltools::tagList(
    page_intro("Approach", "Why these surveys need work before they can be pooled, and how the pipeline does it.", "signpost-split"),
    bslib::card(bslib::card_header("The pipeline in five steps"),
                htmltools::div(class = "steps",
                               step(1, "table", "Map", sprintf("A workbook maps %d harmonised variables to their source in each of the 10 files, which name the same questions differently. A second one maps the %d variables of the modules added in 2026.", m$mapped_variables, m$mapped_variables_extension)),
                               step(2, "arrow-left-right", "Recode", "One Rmd per module renames the columns and recodes answers to one scale, round by round."),
                               step(3, "sign-merge-right", "Clean and merge", sprintf("A do-file removes duplicates, corrects place names, then merges 9 modules 1:1 on ID into %s households. Do-files 16 and 17 add 8 more modules in 2026.", fmt_int(m$households))),
                               step(4, "calculator", "Compute", "Scores and groups are computed once on the pooled file, so all rounds share the same formulas."),
                               step(5, "link-45deg", "Link", "Cadre Harmonisé phases are joined by department and period, and the original assistance answers are added.")
                )),
    bslib::layout_columns(
      col_widths = c(6, 6),
      bslib::card(bslib::card_header("Why it is hard"),
                  htmltools::tags$ul(class = "small mb-0",
                                     htmltools::tags$li(sprintf("Source files have between %d and %d columns, with different names for the same question in most rounds.", min(r$raw_cols), max(r$raw_cols))),
                                     htmltools::tags$li("Answer codes change: for coping strategies, 1 means Yes in some rounds and No need in others."),
                                     htmltools::tags$li("Some files have codes without labels, or labels that do not match the codes."),
                                     htmltools::tags$li("Modules enter over time: dietary diversity from 2022, resilience questions from the 2020 annual survey."),
                                     htmltools::tags$li("Assistance questions change from combined items to separate items in 2021."),
                                     htmltools::tags$li("Departments are missing in one round, and village names vary."))),
      bslib::card(bslib::card_header("How to read this dashboard"),
                  htmltools::tags$ul(class = "small mb-0",
                                     htmltools::tags$li(htmltools::strong("Two series. "), "PDMs take place in the lean season, annual surveys and the baseline after the harvest. Each round is compared within its series only."),
                                     htmltools::tags$li(htmltools::strong("Unweighted. "), "The merged file has no weights. Figures describe the households surveyed, not a population."),
                                     htmltools::tags$li(htmltools::strong("As merged, by default. "), "Figures come from the merged file. Cells with a known defect are hatched or marked † and left out of comparisons."),
                                     htmltools::tags$li(htmltools::strong("Indicative corrections, as an option. "), "They show what a fix would change, rebuilt from the raw files. Your files are not changed."),
                                     htmltools::tags$li(htmltools::strong("No significance tests. "), "A change in a chart is not evidence of a real change.")))
    ),
    bslib::card(bslib::card_header("Indicator definitions"),
                bslib::card_body(padding = 0, reactable::reactable(defs, compact = TRUE, pagination = FALSE, sortable = FALSE, class = "dark-table", wrap = TRUE,
                                                                   columns = list(Indicator = reactable::colDef(minWidth = 190, class = "cell-label"), Definition = reactable::colDef(minWidth = 520), Rounds = reactable::colDef(minWidth = 160))))),
    bslib::card(full_screen = TRUE, bslib::card_header("Source file size, against what the pipeline keeps"), plotly::plotlyOutput(ns("hh_plot"), height = "300px"))
  )
}

approach_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    output$hh_plot <- plotly::renderPlotly({
      r <- d$rounds; lab <- factor(r$label, levels = r$label)
      plotly::plot_ly() |>
        plotly::add_bars(x = lab, y = r$raw_cols, name = "Columns in the raw file", marker = list(color = "#DADBDC"), hovertemplate = "%{x}: %{y} raw columns<extra></extra>") |>
        plotly::add_bars(x = lab, y = r$mapped_vars, name = "Mapped in the workbook", marker = list(color = COL$blue), hovertemplate = "%{x}: %{y} mapped<extra></extra>") |>
        plotly_style(barmode = "group", xaxis = list(tickangle = -30, categoryorder = "array", categoryarray = r$label))
    })
  })
}
