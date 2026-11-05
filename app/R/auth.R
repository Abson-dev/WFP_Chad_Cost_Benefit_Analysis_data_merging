# Login. Required on any server; not when someone runs the app on their own computer
# (run_app.bat sets WFP_CBA_LOCAL=1, or an interactive R session such as RStudio's Run App).
# A server without an accounts database or secret refuses to start rather than show the data.

auth_required <- function() !identical(Sys.getenv("WFP_CBA_LOCAL"), "1") && !interactive()

accounts_path <- function() {
  other <- Sys.getenv("WFP_CBA_ACCOUNTS_DB")
  if (nzchar(other)) other else "accounts.sqlite"
}

accounts_secret <- function() {
  # Hosting services do not always load the .Renviron shipped with the app.
  if (!nzchar(Sys.getenv("WFP_CBA_ACCOUNTS_SECRET")) && file.exists(".Renviron")) readRenviron(".Renviron")
  Sys.getenv("WFP_CBA_ACCOUNTS_SECRET")
}

check_auth <- function() {
  if (!auth_required()) return(invisible(TRUE))
  if (!file.exists(accounts_path())) stop("No accounts database: refusing to start. See manage_accounts.R.", call. = FALSE)
  if (!nzchar(accounts_secret())) stop("No WFP_CBA_ACCOUNTS_SECRET: refusing to start.", call. = FALSE)
  invisible(TRUE)
}

protect_ui <- function(ui) {
  if (!auth_required()) return(ui)
  shinymanager::secure_app(
    ui, language = "en", enable_admin = FALSE,
    head_auth = shiny::tags$link(rel = "stylesheet", href = "styles.css"),
    tags_top = shiny::tagList(shiny::h1(class = "login-title", "WFP Chad · Data merging"),
                              shiny::p(class = "login-sub", "Resilience CBA surveys, 2018–2023")),
    tags_bottom = shiny::p(class = "login-foot", "Restricted access: preliminary figures, not official WFP results.")
  )
}

protect_server <- function() {
  if (!auth_required()) return(invisible(NULL))
  shinymanager::secure_server(
    check_credentials = shinymanager::check_credentials(accounts_path(), passphrase = accounts_secret()),
    timeout = 30
  )
}
