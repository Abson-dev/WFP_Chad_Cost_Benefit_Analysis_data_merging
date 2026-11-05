# Publish the app, behind the login. From the app/ folder:
#   Rscript publish.R             lists what would be sent; sends nothing
#   Rscript publish.R --publish   sends it to shinyapps.io
#   Rscript publish.R --publish --target=connect   sends it to Posit Connect Cloud instead
#
# Allow-list: only the files listed here leave this computer. It refuses to run without login
# accounts, and if a file looks like household data. The URL can be public: the login protects the data.

args <- commandArgs(trailingOnly = TRUE)
if (!file.exists("app.R")) stop("Run this script from the app/ folder.", call. = FALSE)
APP_NAME <- "wfp-chad-data-merging"

required <- c("app.R", ".Renviron", "accounts.sqlite", "data/manifest.json", "data/indicators_by_round.csv")
absent <- required[!file.exists(required)]
if (length(absent)) {
  stop("Missing: ", paste(absent, collapse = ", "), ". Run prepare_app_data.R and manage_accounts.R first.", call. = FALSE)
}
env <- readLines(".Renviron", warn = FALSE)
if (!any(grepl("^WFP_CBA_ACCOUNTS_SECRET=.+", env))) stop("No WFP_CBA_ACCOUNTS_SECRET in .Renviron.", call. = FALSE)
if (any(grepl("WFP_CBA_LOCAL|WFP_CBA_DEMO", env))) stop(".Renviron would disable the login or force a mode.", call. = FALSE)

files <- c(required[1:3], file.path("R", list.files("R", pattern = "\\.R$")),
           file.path("config", c("issues.csv", "interventions.csv", "modules.csv")),
           file.path("www", list.files("www", recursive = TRUE)), file.path("data", list.files("data", recursive = TRUE)))

forbidden <- grepl("accounts_passwords|\\.sav$|\\.dta$|^demo_data/", files)
if (any(forbidden)) stop("Forbidden file in the upload: ", paste(files[forbidden], collapse = ", "), call. = FALSE)
csvs <- grep("\\.csv$", files, value = TRUE)
household <- csvs[vapply(csvs, function(f) any(c("ID", "hh_id", "uuid", "village", "Longitude", "Latitude") %in% gsub("\"", "", strsplit(readLines(f, n = 1, warn = FALSE), ",")[[1]])), TRUE)]
if (length(household)) stop("Household identifiers in: ", paste(household, collapse = ", "), call. = FALSE)

cat(sprintf("Application: %s\nFiles that would be sent (%d):\n", APP_NAME, length(files)))
cat(paste0("  ", files), sep = "\n")
if (!"--publish" %in% args) {
  cat("\nNothing sent. Add --publish to send.\n")
  quit(save = "no")
}

to_connect <- "--target=connect" %in% args
server <- if (to_connect) "posit.cloud" else "shinyapps.io"
accounts <- rsconnect::accounts()
target <- accounts[grepl(server, accounts$server, fixed = TRUE), , drop = FALSE]
if (!nrow(target)) {
  stop("No ", server, " account on this computer. Link it once: ",
       if (to_connect) "rsconnect::connectCloudUser() in an interactive R session."
       else "rsconnect::setAccountInfo(name, token, secret), from the Tokens page of shinyapps.io.", call. = FALSE)
}
rsconnect::deployApp(
  appDir = ".", appFiles = files, appName = APP_NAME, appTitle = "WFP Chad data merging",
  account = target$name[1], server = target$server[1], forceUpdate = TRUE, launch.browser = FALSE, lint = FALSE
)
