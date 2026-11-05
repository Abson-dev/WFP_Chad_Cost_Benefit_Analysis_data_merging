# Screenshots of every page, in a real browser. From the app/ folder, with the app already running:
#   Rscript tests/take_screenshots.R http://127.0.0.1:7788 out_folder [round]
# For README images, run the app with WFP_CBA_DEMO=1, so that no real estimate is published.

args <- commandArgs(trailingOnly = TRUE)
url <- args[1]; out <- args[2]; round_id <- if (length(args) > 2) args[3] else "R10"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
library(chromote)
b <- ChromoteSession$new(width = 1440, height = 1000)
b$Page$navigate(url); b$Page$loadEventFired(wait_ = TRUE)

wait_idle <- function(s = 2.5) {
  Sys.sleep(s)
  for (i in 1:40) {
    busy <- b$Runtime$evaluate("document.documentElement.classList.contains('shiny-busy') || document.querySelectorAll('.recalculating').length > 0")$result$value
    if (!isTRUE(busy)) break
    Sys.sleep(.5)
  }
  Sys.sleep(1)
}
# Real mouse clicks, as a user would make them: opens the menu first for pages inside one.
mouse_click <- function(js_element) {
  xy <- b$Runtime$evaluate(sprintf("(function(){var r=(%s).getBoundingClientRect(); return JSON.stringify([r.left+r.width/2, r.top+r.height/2]);})()", js_element))$result$value
  xy <- jsonlite::fromJSON(xy)
  for (type in c("mouseMoved", "mousePressed", "mouseReleased")) {
    b$Input$dispatchMouseEvent(type = type, x = xy[1], y = xy[2], button = if (type == "mouseMoved") "none" else "left", clickCount = if (type == "mouseMoved") 0 else 1)
  }
}
go <- function(tab) {
  item <- sprintf("[...document.querySelectorAll('a.nav-link,a.dropdown-item')].find(e=>e.textContent.trim()==='%s')", tab)
  in_menu <- b$Runtime$evaluate(sprintf("%s.classList.contains('dropdown-item')", item))$result$value
  if (isTRUE(in_menu)) {
    mouse_click(sprintf("%s.closest('.dropdown').querySelector('.dropdown-toggle')", item))
    Sys.sleep(.4)
  }
  mouse_click(item)
  wait_idle()
}
open_menus <- function() b$Runtime$evaluate("document.querySelectorAll('.navbar .dropdown-menu.show').length")$result$value
shot <- function(file, full = TRUE) {
  h <- if (full) b$Runtime$evaluate("Math.max(document.querySelector('.bslib-sidebar-layout > .main') ? document.querySelector('.bslib-sidebar-layout > .main').scrollHeight : 0, document.body.scrollHeight)")$result$value else 1000
  b$Emulation$setDeviceMetricsOverride(width = 1440, height = min(as.integer(h) + 80, 4200), deviceScaleFactor = 1, mobile = FALSE)
  Sys.sleep(1.2)
  b$screenshot(file.path(out, file), selector = "html")
  b$Emulation$setDeviceMetricsOverride(width = 1440, height = 1000, deviceScaleFactor = 1, mobile = FALSE)
}
errors <- function() {
  b$Runtime$evaluate("[...document.querySelectorAll('.shiny-output-error:not(.shiny-output-error-validation)')].map(e=>(e.id||e.parentElement.id)+': '+e.textContent).join(' | ')")$result$value
}
set_round <- function(r) b$Runtime$evaluate(sprintf("Shiny.setInputValue('ref_round','%s')", r))

wait_idle(5)
invisible(b$Runtime$evaluate(sprintf("document.getElementById('ref_round').selectize.setValue('%s')", round_id)))
wait_idle()
if (length(args) > 3 && args[4] == "corrected") {
  invisible(b$Runtime$evaluate("document.querySelector('input[name=estimate][value=c]').click()"))
  wait_idle()
}
pages <- c(Overview = "01-overview", Merge = "02-merge", Validation = "03-validation", `Data issues` = "04-data-issues", Trends = "05-trends", Regions = "06-regions",
           Assistance = "07-assistance", Approach = "08-approach", Process = "09-process", Crosswalk = "10-crosswalk", Rounds = "11-rounds", Data = "12-data", About = "13-about", Variables = "14-variables", Costs = "15-costs")
for (p in names(pages)) {
  go(p)
  shot(paste0(pages[[p]], ".png"))
  cat(sprintf("%-14s menus left open: %s  errors: %s\n", p, open_menus(), errors()))
}
b$close()
