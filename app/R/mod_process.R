# Process: the pipeline as a diagram, with each step and each module.

PIPELINE_NODES <- function(d) {
  r <- d$rounds; m <- d$modules; st <- d$merge_steps
  mods <- m[order(m$merge_order), ]
  node <- function(label, group, level, detail) data.frame(label = label, group = group, level = level, detail = detail, stringsAsFactors = FALSE)
  rbind(
    node("10 SPSS files\n(raw .sav)", "input", 1, sprintf("%s rows and between %d and %d columns per file, from the 2018 baseline to the 2023 annual survey. Read only, never changed.", fmt_int(sum(r$raw_rows)), min(r$raw_cols), max(r$raw_cols))),
    node("Harmonisation\nworkbook", "doc", 1, sprintf("Chad_Harmonization.xlsx maps %d harmonised variables to their source column in each round, or leaves the cell empty when a round has none.", d$manifest$mapped_variables)),
    node("Extension\nworkbook", "doc", 1, sprintf("Chad_Harmonization_extension.xlsx, added in November 2026, maps the %d variables of the 17 newer modules in the same layout.", d$manifest$mapped_variables_extension)),
    node("MAD and MDDW\nrepeat files", "input", 1, "One row per child (MAD) or woman (MDDW), for the 2021 annual survey to the 2023 annual survey."),
    node("Rmds 01 to 11", "step", 2, "One R Markdown file per module. Each reads all rounds through the workbook, renames columns, recodes answers to one scale and stacks the rounds. Also the source of the bookdown report."),
    node("Rmds 16 to 32", "step", 2, "The same steps for shocks, assets and livestock, livelihoods, agriculture, expenditure, disability, education, migration, protection and accountability, debt, social cohesion, climate adaptation, shock impact and recovery, programme effects, markets, more accountability questions and additions to earlier modules, through the extension workbook."),
    do.call(rbind, lapply(seq_len(nrow(mods)), function(i) node(mods$label[i], if (mods$stage[i] == 2026) "module_new" else "module", 3,
                                                                 sprintf("%s From %s, %s rows.", mods$description[i], mods$rmd[i], fmt_int(st$using_rows[match(mods$module[i], st$module)]))))),
    node("MAD · MDDW", "offmerge", 3, "Module files built by Rmds 09 and 10, with one row per person. Left out: in four rounds their link to households is ambiguous."),
    node("Do-file 12:\nclean", "step", 4, sprintf("Removes %d duplicate rows and %d refused interview from each module, then harmonises villages, departments and regions and attaches OCHA codes.", sum(r$duplicates_removed), sum(r$empty_removed))),
    node("Do-file 12:\nmerge 1:1 on ID", "merge", 5, sprintf("Merges the first 9 modules on ID, starting from the administrative file. Result: %s households. No household exists only in a later module.", fmt_int(d$manifest$households))),
    node("Do-file 12:\nscores", "step", 6, "Recomputes FCS and its groups, rCSI, maximum coping category, RCS and its groups on the pooled file. ABI comes from Rmd 07."),
    node("Cadre Harmonisé\nanalyses", "input", 6, "CH analyses for Chad, 2017 to 2023. Only the current period is kept. Joined on year, cycle and department."),
    node("Do-file 13:\nassistance", "step", 7, "Adds the original assistance answers for each round, sets all interventions to yes / no / don't know, recodes food for assets to cash and reorders the columns."),
    node("Do-files 14 to 21:\nfixes and new modules", "merge", 8, "14 and 15 fix rCSIBorrow and the 2020 PDM FCS in new files. 16 to 20 add the 17 newer modules 1:1 on ID, keeping the first of each duplicated ID and leaving every earlier column unchanged. 21 adds the costs per household, built by the scripts of costs/."),
    node("Merged dataset\n(.dta)", "output", 9, sprintf("%s, %s households and %d columns.", d$manifest$merged_file, fmt_int(d$manifest$households), d$manifest$columns)),
    node("This dashboard's\nchecks", "check", 10, "prepare_app_data.R replays the merge, compares raw and merged values, recomputes the scores and writes aggregates only.")
  ) -> n
  n$id <- seq_len(nrow(n))
  n
}

process_ui <- function(id, d) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    page_intro("Merging process", "From raw survey files to the merged dataset. Click a step in the diagram for details.", "diagram-3"),
    bslib::card(full_screen = TRUE, bslib::card_header("Pipeline"), visNetwork::visNetworkOutput(ns("flow"), height = "520px")),
    bslib::card(bslib::card_header("Step details"), shiny::uiOutput(ns("node_detail"))),
    bslib::card(bslib::card_header("Modules"), shiny::uiOutput(ns("domains")))
  )
}

process_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    nodes <- PIPELINE_NODES(d)

    output$flow <- visNetwork::renderVisNetwork({
      vn <- nodes
      vn$title <- vn$detail; vn$shape <- "box"
      vn$font.color <- ifelse(vn$group %in% c("input", "step", "merge"), "#ffffff", COL$ink)
      vn$font.size <- 24; vn$margin <- 12
      id_of <- function(lab) nodes$id[nodes$label == lab]
      mods <- nodes$id[nodes$group == "module"]; mods_new <- nodes$id[nodes$group == "module_new"]; off <- nodes$id[nodes$group == "offmerge"]
      clean <- id_of("Do-file 12:\nclean"); mrg <- id_of("Do-file 12:\nmerge 1:1 on ID"); sc <- id_of("Do-file 12:\nscores")
      ch <- id_of("Cadre Harmonisé\nanalyses"); d13 <- id_of("Do-file 13:\nassistance"); fin <- id_of("Merged dataset\n(.dta)"); chk <- id_of("This dashboard's\nchecks")
      d17 <- id_of("Do-files 14 to 21:\nfixes and new modules")
      rmd <- id_of("Rmds 01 to 11"); rmd2 <- id_of("Rmds 16 to 32"); raw <- id_of("10 SPSS files\n(raw .sav)"); wb <- id_of("Harmonisation\nworkbook")
      wb2 <- id_of("Extension\nworkbook"); rep <- id_of("MAD and MDDW\nrepeat files")
      edges <- data.frame(from = c(raw, wb, rep, raw, wb2, rep(rmd, length(mods)), rmd, rep(rmd2, length(mods_new)), mods, mods_new, clean, mrg, sc, ch, d13, d17, fin),
                          to = c(rmd, rmd, rmd, rmd2, rmd2, mods, off, mods_new, rep(clean, length(mods)), rep(d17, length(mods_new)), mrg, sc, d13, d13, d17, fin, chk))
      edges$dashes <- edges$to == chk | edges$to == off
      visNetwork::visNetwork(vn, edges) |>
        visNetwork::visGroups(groupname = "input", color = list(background = COL$navy, border = COL$navy)) |>
        visNetwork::visGroups(groupname = "step", color = list(background = COL$blue, border = COL$blue)) |>
        visNetwork::visGroups(groupname = "merge", color = list(background = "#035537", border = "#035537")) |>
        visNetwork::visGroups(groupname = "doc", color = list(background = "#F4D7C4", border = "#AA5628")) |>
        visNetwork::visGroups(groupname = "module", color = list(background = "#D5ECDD", border = "#03924A")) |>
        visNetwork::visGroups(groupname = "module_new", color = list(background = "#DCE9F5", border = "#0A6EB4")) |>
        visNetwork::visGroups(groupname = "offmerge", color = list(background = "#F1F3F5", border = "#939598")) |>
        visNetwork::visGroups(groupname = "output", color = list(background = "#F9F4DF", border = "#002F5A")) |>
        visNetwork::visGroups(groupname = "check", color = list(background = "#FFF7E0", border = "#D9A20F")) |>
        visNetwork::visEdges(arrows = "to", color = list(color = "#939598", highlight = COL$blue),
                             smooth = list(type = "cubicBezier", forceDirection = "horizontal")) |>
        visNetwork::visHierarchicalLayout(direction = "LR", levelSeparation = 215, nodeSpacing = 58) |>
        visNetwork::visOptions(highlightNearest = list(enabled = TRUE, degree = 1)) |>
        visNetwork::visInteraction(dragNodes = FALSE, zoomView = FALSE, navigationButtons = FALSE) |>
        visNetwork::visEvents(select = sprintf(
          "function(p){ Shiny.setInputValue('%s', p.nodes.length ? p.nodes[0] : null, {priority: 'event'}); }",
          session$ns("node")))
    })

    output$node_detail <- shiny::renderUI({
      i <- input$node
      k <- which(nodes$label == "Do-file 12:\nmerge 1:1 on ID")
      if (is.null(i)) {
        return(htmltools::div(htmltools::div(class = "text-muted", bsicons::bs_icon("hand-index"), " Select a step in the diagram."),
                              htmltools::hr(), htmltools::h6("The merge"), htmltools::p(class = "small", nodes$detail[k])))
      }
      n <- nodes[nodes$id == i, ]
      htmltools::div(htmltools::h5(gsub("\n", " ", n$label)), htmltools::p(class = "small", n$detail))
    })

    output$domains <- shiny::renderUI({
      m <- d$modules[order(d$modules$merge_order), ]
      card <- function(title, rmd, txt, ok, new = FALSE) {
        htmltools::div(class = paste("domain-card", if (ok) "done" else "planned"),
                       htmltools::div(class = "d-flex justify-content-between gap-1 align-items-start",
                                      htmltools::strong(title),
                                      if (!ok) pill("not merged", "#636466") else if (new) pill("added 2026", "#0A6EB4") else pill("merged", "#035537")),
                       htmltools::div(class = "small mt-1", txt),
                       htmltools::div(class = "issue-where mt-1", rmd))
      }
      htmltools::div(class = "domain-grid",
                     lapply(seq_len(nrow(m)), function(i) card(m$label[i], m$rmd[i], m$description[i], TRUE, m$stage[i] == 2026)),
                     card("Child diet (MAD)", "09_WFP_Chad_MAD_data.Rmd", "Feeding of children aged 6 to 23 months. One row per child. Left out: the link to households is ambiguous in four rounds.", FALSE),
                     card("Women's diet (MDDW)", "10_WFP_Chad_MDDW_data.Rmd", "Dietary diversity of women aged 15 to 49. One row per woman. Left out for the same reason.", FALSE))
    })
  })
}
