# Original vs merged: the statistics of each variable in WFP's raw files and in the merged file, round by round, how
# each raw code became a merged code, and the food consumption and coping scores recomputed from the raw items.

OVM_COL <- c("Identical" = "#03924A", "Same values, different number of answers" = "#C9A227",
             "Values differ: recoded on purpose, or a defect" = "#C0392B", "Built in the merge (no raw column)" = "#5B7DA8",
             "Not in the merged file" = "#9AA5B1", "Text: answers counted only" = "#C7CED6", "Date: answers counted only" = "#C7CED6",
             "No household answered in both" = "#636466")
OVM_SHORT <- c("Identical" = "Identical", "Same values, different number of answers" = "Same values, other answers",
               "Values differ: recoded on purpose, or a defect" = "Values differ", "Built in the merge (no raw column)" = "Built in the merge",
               "Not in the merged file" = "Not merged", "Text: answers counted only" = "Text", "Date: answers counted only" = "Date",
               "No household answered in both" = "No overlap")

original_ui <- function(id, d) {
  ns <- shiny::NS(id)
  v <- d$ovm_variables; n <- function(s) sum(v$status == s)
  ind <- d$ovm_indicators
  ok_ind <- sum(ind$note == "Same.")
  htmltools::tagList(
    page_intro("Original vs merged",
               "Each variable of the two harmonisation workbooks, compared round by round between WFP's raw files and the merged file, on the same households: answers, mean, median, range, the share of households with the same value, and how each raw code became a merged code.",
               "arrow-left-right"),
    bslib::layout_column_wrap(
      width = "170px", fill = FALSE, heights_equal = "row",
      kpi("Variable-rounds compared", fmt_int(nrow(v)), sprintf("%d variables in 10 rounds", length(unique(v$variable))), "grid-3x3", "navy"),
      kpi("Identical", fmt_int(n("Identical")), "Same value for every household", "check2-circle", "green"),
      kpi("Same values, other answers", fmt_int(n("Same values, different number of answers")), "Some answers left out or added", "dash-circle", "brown"),
      kpi("Values differ", fmt_int(n("Values differ: recoded on purpose, or a defect")), "Mostly codes put on one scale", "arrow-repeat", "red"),
      kpi("Scores from the raw items", sprintf("%d of %d", ok_ind, nrow(ind)), "FCS and rCSI equal; the rest explained", "calculator", "blue")
    ),
    callout(type = "info", htmltools::strong("How to read it. "),
            "A variable whose values differ is not an error in itself: most are recoded on purpose, so that a code means the same thing in every round. ",
            "The Categories tab of a variable shows the recoding; the Data issues page says when a difference is a defect. Means of coded variables compare codes, not quantities."),
    bslib::layout_columns(
      col_widths = c(7, 5),
      bslib::card(full_screen = TRUE, bslib::card_header("Status of the variables by round"),
                  plotly::plotlyOutput(ns("status_plot"), height = "330px")),
      bslib::card(full_screen = TRUE, bslib::card_header("Scores recomputed from the raw items"),
                  bslib::card_body(padding = 0, reactable::reactableOutput(ns("indicators"))),
                  bslib::card_footer(class = "table-note", "FCS and rCSI computed from the raw items through the workbook's mapping, against the merged file."))
    ),
    bslib::layout_sidebar(
      fillable = FALSE,
      sidebar = bslib::sidebar(
        width = 280, open = "desktop",
        shiny::selectInput(ns("round"), "Round", c("All rounds" = "", stats::setNames(d$rounds$round_id, d$rounds$choice))),
        shinyWidgets::pickerInput(ns("status"), "Status", choices = unname(OVM_STATUS_ORDER(v)), selected = unname(OVM_STATUS_ORDER(v)), multiple = TRUE,
                                  options = shinyWidgets::pickerOptions(actionsBox = TRUE, selectedTextFormat = "count > 2", countSelectedText = "{0} statuses")),
        shiny::selectInput(ns("workbook"), "Workbook", c("Both" = "", unique(v$workbook))),
        shiny::selectizeInput(ns("variable"), "Find a variable", choices = c("Type to search…" = "", sort(unique(v$variable)))),
        htmltools::hr(),
        shiny::downloadButton(ns("dl_xlsx"), "Comparison workbook (.xlsx)", class = "btn-sm btn-outline-primary w-100 mb-2"),
        shiny::downloadButton(ns("dl_csv"), "Filtered variables (.csv)", class = "btn-sm btn-outline-secondary w-100")
      ),
      bslib::card(full_screen = TRUE, bslib::card_header("Variables, original against merged"),
                  reactable::reactableOutput(ns("variables")),
                  bslib::card_footer(class = "table-note", "Raw: the raw file's values for the households of the merged file. Click a row for the variable's profile.")),
      shiny::uiOutput(ns("profile"))
    )
  )
}

OVM_STATUS_ORDER <- function(v) intersect(names(OVM_COL), unique(v$status))

original_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    r <- d$rounds
    rlab <- function(rid) as.character(r$label[match(rid, r$round_id)])
    selected <- shiny::reactiveVal(if ("HHHSex" %in% d$ovm_variables$variable) "HHHSex" else d$ovm_variables$variable[1])

    vars_f <- shiny::reactive({
      x <- d$ovm_variables
      if (nzchar(input$round %||% "")) x <- x[x$round_id == input$round, ]
      if (nzchar(input$workbook %||% "")) x <- x[x$workbook == input$workbook, ]
      x[x$status %in% input$status, ]
    })
    shiny::observeEvent(input$variable, if (nzchar(input$variable)) selected(input$variable), ignoreInit = TRUE)

    output$status_plot <- plotly::renderPlotly({
      x <- d$ovm_variables
      p <- plotly::plot_ly()
      for (s in OVM_STATUS_ORDER(x)) {
        k <- table(factor(x$round_id[x$status == s], r$round_id))
        p <- plotly::add_bars(p, x = rlab(names(k)), y = as.integer(k), name = OVM_SHORT[[s]], marker = list(color = OVM_COL[[s]]),
                              hovertemplate = paste0("%{x}<br>", OVM_SHORT[[s]], ": %{y}<extra></extra>"))
      }
      plotly_style(p, barmode = "stack", xaxis = list(type = "category", categoryorder = "array", categoryarray = as.character(r$label), tickangle = -30),
                   yaxis = list(title = "Variables"))
    })

    output$indicators <- reactable::renderReactable({
      x <- d$ovm_indicators
      x <- data.frame(Round = rlab(x$round_id), Indicator = x$indicator, Raw = x$raw_value, Merged = x$merged_value, Difference = x$difference, Note = x$note)
      reactable::reactable(x, compact = TRUE, pagination = FALSE, height = 330, striped = TRUE, defaultColDef = reactable::colDef(na = "—"),
                           rowStyle = function(i) if (!x$Note[i] %in% "Same.") list(background = "#FFF7E0"),
                           columns = list(Round = reactable::colDef(minWidth = 95), Indicator = reactable::colDef(minWidth = 160),
                                          Raw = reactable::colDef(minWidth = 65, format = reactable::colFormat(digits = 1)),
                                          Merged = reactable::colDef(minWidth = 70, format = reactable::colFormat(digits = 1)),
                                          Difference = reactable::colDef(minWidth = 80, format = reactable::colFormat(digits = 2)),
                                          Note = reactable::colDef(minWidth = 260, style = list(fontSize = ".8em"))))
    })

    status_cell <- function(s) pill(OVM_SHORT[[s]], OVM_COL[[s]], if (OVM_COL[[s]] %in% c("#C7CED6", "#C9A227")) "#1F2933" else "#fff")
    output$variables <- reactable::renderReactable({
      x <- vars_f()
      shiny::validate(shiny::need(nrow(x) > 0, "No variable matches the filters."))
      x <- data.frame(Round = rlab(x$round_id), Variable = x$variable, Group = x$family, `Raw column` = x$raw_column,
                      `Raw answers` = x$raw_answered, `Merged answers` = x$merged_answered, `Raw mean` = x$raw_mean, `Merged mean` = x$merged_mean,
                      `% same` = x$pct_same, Status = x$status, check.names = FALSE)
      reactable::reactable(
        x, searchable = TRUE, compact = TRUE, striped = TRUE, highlight = TRUE, defaultPageSize = 15, selection = "single", onClick = "select",
        rowStyle = list(cursor = "pointer"), defaultColDef = reactable::colDef(na = "—"),
        theme = reactable::reactableTheme(headerStyle = list(background = COL$navy, color = "#fff")),
        columns = list(.selection = reactable::colDef(show = FALSE),
                       Round = reactable::colDef(minWidth = 100), Variable = reactable::colDef(minWidth = 150, style = list(fontFamily = "Consolas, monospace", fontSize = ".82em", fontWeight = 600)),
                       Group = reactable::colDef(minWidth = 140), `Raw column` = reactable::colDef(minWidth = 150, style = list(fontFamily = "Consolas, monospace", fontSize = ".78em")),
                       `Raw answers` = reactable::colDef(minWidth = 80, format = reactable::colFormat(separators = TRUE)),
                       `Merged answers` = reactable::colDef(minWidth = 85, format = reactable::colFormat(separators = TRUE)),
                       `Raw mean` = reactable::colDef(minWidth = 75, format = reactable::colFormat(digits = 2)),
                       `Merged mean` = reactable::colDef(minWidth = 80, format = reactable::colFormat(digits = 2)),
                       `% same` = reactable::colDef(minWidth = 70, format = reactable::colFormat(digits = 1)),
                       Status = reactable::colDef(minWidth = 170, cell = status_cell)))
    })
    shiny::observe({
      i <- reactable::getReactableState("variables", "selected")
      shiny::req(i)
      selected(vars_f()$variable[i])
    })

    output$profile <- shiny::renderUI({
      v <- selected(); shiny::req(v)
      rows <- d$ovm_variables[d$ovm_variables$variable == v, ]
      cat_rounds <- unique(d$ovm_categories$round_id[d$ovm_categories$variable == v])
      bslib::card(
        class = "concept-card", full_screen = TRUE,
        bslib::card_header(class = "d-flex flex-wrap gap-2 align-items-center", htmltools::code(v), pill(rows$family[1], COL$navy), pill(rows$workbook[1], "#5B7DA8")),
        bslib::navset_underline(
          bslib::nav_panel("Statistics by round", reactable::reactableOutput(ns("profile_rounds"))),
          bslib::nav_panel("Categories",
                           if (length(cat_rounds)) htmltools::tagList(
                             shiny::selectInput(ns("cat_round"), NULL, stats::setNames(cat_rounds, rlab(cat_rounds)), width = "220px"),
                             reactable::reactableOutput(ns("profile_cats")),
                             htmltools::p(class = "table-note", "Households per pair of codes; blank under 5 households. Kept: the merged code equals the raw code."))
                           else htmltools::p(class = "table-note mt-2", "No categories: the variable is not coded with value labels, or it has more than 40 values."))
        )
      )
    })
    output$profile_rounds <- reactable::renderReactable({
      x <- d$ovm_variables[d$ovm_variables$variable == selected(), ]
      x <- data.frame(Round = rlab(x$round_id), `Raw column` = x$raw_column, `Raw answers` = x$raw_answered, `Merged answers` = x$merged_answered,
                      `Raw mean` = x$raw_mean, `Merged mean` = x$merged_mean, `Raw median` = x$raw_median, `Merged median` = x$merged_median,
                      `Raw range` = ifelse(is.na(x$raw_min), NA, paste(x$raw_min, "to", x$raw_max)),
                      `Merged range` = ifelse(is.na(x$merged_min), NA, paste(x$merged_min, "to", x$merged_max)),
                      `% same` = x$pct_same, Status = x$status, check.names = FALSE)
      reactable::reactable(x, compact = TRUE, pagination = FALSE, striped = TRUE, defaultColDef = reactable::colDef(na = "—", minWidth = 80),
                           columns = list(Round = reactable::colDef(minWidth = 100, style = list(fontWeight = 600)),
                                          `Raw column` = reactable::colDef(minWidth = 150, style = list(fontFamily = "Consolas, monospace", fontSize = ".78em")),
                                          `Raw mean` = reactable::colDef(format = reactable::colFormat(digits = 2)), `Merged mean` = reactable::colDef(format = reactable::colFormat(digits = 2)),
                                          Status = reactable::colDef(minWidth = 170, cell = status_cell)))
    })
    output$profile_cats <- reactable::renderReactable({
      shiny::req(input$cat_round)
      x <- d$ovm_categories[d$ovm_categories$variable == selected() & d$ovm_categories$round_id == input$cat_round, ]
      shiny::validate(shiny::need(nrow(x) > 0, "No categories in this round."))
      x <- data.frame(`Raw code` = x$raw_code, `Raw label` = x$raw_label, `Merged code` = x$merged_code, `Merged label` = x$merged_label,
                      Households = x$households, `% of the raw code` = x$pct_of_raw_code, Kept = ifelse(x$same_code, "Yes", "Recoded"), check.names = FALSE)
      reactable::reactable(x, compact = TRUE, pagination = FALSE, striped = TRUE, defaultColDef = reactable::colDef(na = "—"),
                           rowStyle = function(i) if (x$Kept[i] == "Recoded") list(background = "#FFF7E0"),
                           columns = list(`Raw label` = reactable::colDef(minWidth = 200), `Merged label` = reactable::colDef(minWidth = 200),
                                          Households = reactable::colDef(format = reactable::colFormat(separators = TRUE)),
                                          `% of the raw code` = reactable::colDef(format = reactable::colFormat(digits = 1))))
    })

    output$dl_xlsx <- shiny::downloadHandler(filename = function() "WFP_Chad_original_vs_merged.xlsx", content = function(file) original_workbook(d, file))
    output$dl_csv <- shiny::downloadHandler(filename = function() "WFP_Chad_original_vs_merged_variables.csv",
                                            content = function(file) readr::write_csv(vars_f(), file, na = ""))
  })
}
