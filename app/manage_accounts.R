# Create or replace the login accounts of the published app. From the app/ folder:
#   Rscript manage_accounts.R first.name other.name
#
# Replaces the WHOLE database: list every account to keep. Each account gets a new random
# password, written to accounts_passwords.csv and never displayed. Send each password
# individually through a safe channel, then delete that file. None of this is versioned.

accounts <- commandArgs(trailingOnly = TRUE)
if (!length(accounts)) stop("Give at least one account name.", call. = FALSE)
if (anyDuplicated(accounts)) stop("Duplicate account names.", call. = FALSE)
if (any(!grepl("^[A-Za-z0-9._-]{3,}$", accounts))) stop("Names: at least 3 letters, digits, dots or hyphens.", call. = FALSE)
if (!file.exists("app.R")) stop("Run this script from the app/ folder.", call. = FALSE)

random_text <- function(n) {
  alphabet <- c(letters, LETTERS, 0:9)
  # Bytes outside the range are rejected, for a uniform draw over the alphabet.
  bytes <- as.integer(openssl::rand_bytes(n * 4L))
  bytes <- bytes[bytes < 248L]
  paste(alphabet[bytes[seq_len(n)] %% 62L + 1L], collapse = "")
}

if (file.exists(".Renviron")) readRenviron(".Renviron")
secret <- Sys.getenv("WFP_CBA_ACCOUNTS_SECRET")
if (!nzchar(secret)) {
  secret <- random_text(48L)
  cat(sprintf("WFP_CBA_ACCOUNTS_SECRET=%s\n", secret), file = ".Renviron", append = TRUE)
}

passwords <- vapply(accounts, function(.) random_text(20L), character(1))
if (file.exists("accounts.sqlite")) file.remove("accounts.sqlite")
shinymanager::create_db(
  credentials_data = data.frame(user = accounts, password = unname(passwords), admin = FALSE, stringsAsFactors = FALSE),
  sqlite_path = "accounts.sqlite", passphrase = secret
)
utils::write.csv(data.frame(account = accounts, password = unname(passwords)), "accounts_passwords.csv", row.names = FALSE)
message(length(accounts), " account(s) created. Passwords: accounts_passwords.csv (delete it after sending them).")
