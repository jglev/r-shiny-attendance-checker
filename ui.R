library(shiny)
library(shinyjs)
library(googlesheets)

source('configuration_settings.R')

dojo_logo <- img(
  # Grab the dojo logo straight from its website (I found this using
  # Google Image Search)
  src = logo_location,
  # Center the image, using CSS, following
  # https://stackoverflow.com/a/34663186/1940466:
  style = "display: block; margin-left: auto; margin-right: auto;",
  width = 100
)

shinyUI(
  fluidPage(
    useShinyjs(),  # This is for hiding the loading message, following
      # https://github.com/daattali/advanced-shiny/tree/master/loading-screen
    
    titlePanel("Dojo Attendance"),
    sidebarLayout(
      sidebarPanel(
        dojo_logo,
        h4(
          "Loading data",
          img(
            src = "public_domain_loading_animation.gif"
          ),
          id = "loading-message"
        ),
        uiOutput("person_select_list"),
        verbatimTextOutput("last_updated_time"),
        hr(),
        h4("A few friendly reminders:"),
        tags$ol(
          tags$li("The accumulation of the ", tags$b("minimum number of practice hours "), "required ", tags$b("does not mean you will or should be tested. "), "If a student demonstrates a strong commitment to practice and a good understanding of the responsibilities associated with their next level, the teacher may consider them for advancement."),
          tags$li(tags$b("Proper etiquette "), "dictates that one ", tags$b("not inquire about testing and promotions; "), "a student should train diligently and wait patiently to be informed of the possibility of promotion.")
        ),
        hr(),
        h4('Information about this page:'),
        information_about_this_page  # This is set in the 
          # configuration settings
      ),
      mainPanel(
        column(
          h2("Overall Attendance"),
          DT::dataTableOutput("total_attendance_table"),
          hr(),
          h3("Individual Logins"),
          DT::dataTableOutput("individual_logins_table"),
          h2("Month-by-Month Attendance"),
          h3("Logins by Month"),
          DT::dataTableOutput("monthly_data_table"),
            # NOTE WELL that dataTableOutput needs to have 
            # 'DT::' before it to work on shinyapps.io (it
            # will work locally both with and without it).
          hr(),
          h3("Plot of Attendance"),
          plotOutput("monthly_data_plot"),
          width = 12
        )
      )
    )
  )
)
