# WFP Chad resilience CBA 2018-2023: dashboard of the data merging process.
# Run from this folder:  shiny::runApp()   (after Rscript prepare_app_data.R)
# Files in R/ are loaded automatically by Shiny.

library(shiny)
library(bslib)

check_auth()
d <- load_app_data()
# Deep links: ?page=costs or #page=costs opens that page (the data assistant links to them).
PAGE_SLUGS <- c(overview = "Overview", merge = "Merge", validation = "Validation", issues = "Data issues", variables = "Variables",
                trends = "Trends", regions = "Regions", assistance = "Assistance", costs = "Costs", approach = "Approach",
                process = "Process", crosswalk = "Crosswalk", original = "Original vs merged", rounds = "Rounds", data = "Data", about = "About")
ASSISTANT_URL <- Sys.getenv("WFP_ASSISTANT_URL")
round_choices <- rev(setNames(d$rounds$round_id, d$rounds$choice))

ui <- protect_ui(page_navbar(
  id = "page",
  title = brand(),
  window_title = "WFP Chad · Data merging",
  theme = app_theme(),
  navbar_options = navbar_options(theme = "light"),
  fillable = FALSE,
  header = tagList(
    tags$link(rel = "stylesheet", href = "styles.css"),
    useBusyIndicators(),
    # The hash survives the login screen: pass it to the server once the app is shown.
    tags$script(HTML("$(document).on('shiny:connected', function() { var h = window.location.hash.replace(/^#/, ''); if (h) Shiny.setInputValue('url_hash_page', h); });"))
  ),
  sidebar = sidebar(
    class = "global-sidebar", width = 260, gap = "0.5rem",
    # On narrow screens the controls stay reachable above the content.
    open = list(desktop = "open", mobile = "always-above"),
    if (demo_mode()) div(class = "demo-banner", "SYNTHETIC DATA: no estimate on this page is real"),
    selectInput("ref_round", "Reference round", round_choices, selected = round_choices[1]),
    radioButtons("estimate", "Figures",
                 c("As merged" = "m", "With indicative corrections" = "c"), selected = "m"),
    uiOutput("estimate_note"),
    hr(),
    uiOutput("round_info"),
    hr(),
    uiOutput("provenance")
  ),
  nav_panel("Overview", icon = bsicons::bs_icon("speedometer2"), situation_ui("situation", d)),
  nav_panel("Merge", icon = bsicons::bs_icon("sign-merge-right"), merge_ui("merge", d)),
  nav_panel("Validation", icon = bsicons::bs_icon("patch-check"), validation_ui("validation", d)),
  nav_panel("Data issues", icon = bsicons::bs_icon("exclamation-triangle"), issues_ui("issues", d)),
  nav_panel("Variables", icon = bsicons::bs_icon("list-columns-reverse"), variables_ui("variables", d)),
  nav_menu(
    "Results", icon = bsicons::bs_icon("bar-chart-line"),
    nav_panel("Trends", icon = bsicons::bs_icon("graph-up"), trends_ui("trends", d)),
    nav_panel("Regions", icon = bsicons::bs_icon("geo-alt"), regions_ui("regions", d)),
    nav_panel("Assistance", icon = bsicons::bs_icon("box-seam"), assistance_ui("assistance", d)),
    nav_panel("Costs", icon = bsicons::bs_icon("cash-stack"), costs_ui("costs", d))
  ),
  nav_menu(
    "Method", icon = bsicons::bs_icon("diagram-3"),
    nav_panel("Approach", icon = bsicons::bs_icon("signpost-split"), approach_ui("approach", d)),
    nav_panel("Process", icon = bsicons::bs_icon("diagram-3"), process_ui("process", d)),
    nav_panel("Crosswalk", icon = bsicons::bs_icon("table"), crosswalk_ui("crosswalk", d)),
    nav_panel("Original vs merged", icon = bsicons::bs_icon("arrow-left-right"), original_ui("original", d)),
    nav_panel("Rounds", icon = bsicons::bs_icon("calendar3"), rounds_ui("rounds", d))
  ),
  nav_panel("Data", icon = bsicons::bs_icon("download"), data_ui("data", d)),
  nav_panel("About", icon = bsicons::bs_icon("info-circle"), about_ui("about", d)),
  if (nzchar(ASSISTANT_URL)) nav_item(tags$a(href = ASSISTANT_URL, target = "_blank", rel = "noopener", bsicons::bs_icon("chat-dots"), " Ask the assistant")),
  footer = tags$footer(
    class = "app-footer",
    "WFP Chad resilience CBA, 2018–2023 · aggregate data only · unweighted, preliminary, not official WFP results · ",
    tags$a(href = "https://bookdown.org/aboubacarhema94/WFP_Chad_Cost_Benefit_Analysis_data_merging/", target = "_blank", "Harmonisation report")
  )
))

server <- function(input, output, session) {
  protect_server()
  # Open the page named in the link, once the navigation exists.
  page_from <- function(s) { s <- sub(".*page=([A-Za-z_]+).*", "\\1", s); if (tolower(s) %in% names(PAGE_SLUGS)) PAGE_SLUGS[[tolower(s)]] else NULL }
  # The navigation appears after the login: then read the address (?page=) or the hash sent at connection (#page=).
  observeEvent(input$page, {
    target <- page_from(session$clientData$url_search)
    if (is.null(target) && !is.null(isolate(input$url_hash_page))) target <- page_from(isolate(input$url_hash_page))
    if (!is.null(target) && !identical(input$page, target)) nav_select("page", target)
  }, once = TRUE)
  observeEvent(input$url_hash_page, {
    target <- page_from(input$url_hash_page)
    if (!is.null(target)) nav_select("page", target)
  })
  ref <- reactive(if (is.null(input$ref_round)) unname(round_choices[1]) else input$ref_round)
  est <- reactive(if (is.null(input$estimate)) "m" else input$estimate)

  output$estimate_note <- renderUI({
    div(class = "note", if (est() == "c")
      "Flagged cells are replaced by a value rebuilt from the raw files. Indicative only: the merged file itself is unchanged."
      else "The merged file as it stands. Cells with a known defect are hatched and left out of comparisons.",
      br(), br(), "These controls drive Overview, Trends and Regions. The round also marks Assistance.")
  })
  output$round_info <- renderUI({
    r <- d$rounds[d$rounds$round_id == ref(), ]
    div(class = "note",
        strong("Survey: "), r$survey, " · ", tolower(r$series), br(),
        strong("Fieldwork: "), fmt_dates(r$date_p01, r$date_p99), br(),
        strong("Households: "), fmt_int(r$final_rows), br(),
        strong("Regions: "), r$regions, " · ", strong("Departments: "), r$departments)
  })
  output$provenance <- renderUI({
    i <- d$manifest$inputs
    k <- match(ref(), i$round_id)
    div(class = "note",
        strong("Source: "), i$file[k], br(),
        strong("SHA-256: "), paste0(substr(i$sha256[k], 1, 12), "…"), br(),
        strong("Data refreshed: "), substr(d$manifest$run_utc, 1, 10))
  })

  situation_server("situation", d, ref, est)
  merge_server("merge", d)
  validation_server("validation", d)
  issues_server("issues", d)
  variables_server("variables", d)
  trends_server("trends", d, ref, est)
  regions_server("regions", d, ref, est)
  assistance_server("assistance", d, ref)
  costs_server("costs", d)
  approach_server("approach", d)
  process_server("process", d)
  crosswalk_server("crosswalk", d)
  original_server("original", d)
  rounds_server("rounds", d)
  data_server("data", d)
  about_server("about", d)
}

shinyApp(ui, server)
