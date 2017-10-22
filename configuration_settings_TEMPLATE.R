timezone <- 'America/New_York'

# This file should be located in a subdirectory of the main app's directory called 'www'
logo_location <- 'path/to/logo'

# Note WELL: If you are using Google Sheets: Per https://github.com/jennybc/googlesheets/issues/272#issuecomment-242977476, a sheet needs to be "Published to the web via the File menu... Merely being Public on the web, via the share button in upper right corner, is not enough to permit API access." You then ALSO need to click the "Share" button, click "Get a shareable link," and select "anyone with the link can view." Then paste that sharing link below, and set 'load_from_google_sheets' below to TRUE.
spreadsheet_location <- 'https://docs.google.com/spreadsheets/d/a1b2c3d4e5/'

load_from_google_sheets <- TRUE  # If this is FALSE, the spreadsheet_location
# will be assumed to be the location of a CSV.

only_count_one_signin_per_day_per_person <- TRUE

# By default, create an ordered list (ol) that contains several
# list items (li). This will be displayed at the bottom of the app's
# sidebar.
information_about_this_page <- tagList(
  tags$ol(
    tags$li("This app is open-source software. It is written in ", tags$a("R", href = "https://www.r-project.org", title = "The R language homepage"), "."),
    tags$li("You can contact the developers about bugs or contributing at ", tags$a("https://www.github.com/publicus/r-shiny-attendance-checker", href = "https://www.github.com/publicus/r-shiny-attendance-checker", title = "The project's GitHub page"), ".")
  )
)

# As many strings as you like for activating "administrator mode", which
# allows selecting more than one person at a time. For the key 'example1',
# the app URL to activate administrator mode would be
# https://yourappurl.com?admin_key=example1
# To generate a random key string, you can use the following:
# stringi::stri_rand_strings(n = 1, length = 20, pattern="[A-Za-z0-9]")
valid_administrator_keys <- c(
  'example1',
  'example2'
)
