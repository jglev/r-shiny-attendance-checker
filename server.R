library(shiny)
library(googlesheets)
library(DT)
library(lubridate)
library(ggplot2)

source("configuration_settings.R")  # Get our configuration settings

load_google_sheets_data <- function(
  sheet_location = google_sheet_location
){
  if (load_from_google_sheets == TRUE){
    google_sheet_data <- gs_read(
      gs_url(
        sheet_location,
        visibility = 'public'
      ),
      ws = 'Sign-In Form Responses'
    )
  } else {
    # Read from a CSV:
    google_sheet_data <- read.csv(
      sheet_location,
      stringsAsFactors = FALSE
    )
  }
  
  # Date examples, for future reference:
  # mdy('10/11/2017') >= mdy('10/10/2017')
  # mdy_hms('10/11/2017 10:38:36') <= mdy('10/10/2017')
  # format(mdy_hms('10/11/2017 10:38:36'), format = "%Y-%m-%d")
  
  # Use just a subset of the data:
  google_sheet_data <- google_sheet_data[
    ,  # Use all rows
    c("Timestamp", "Name")
  ]
  
  google_sheet_data$Date <- as.character(format(
    strptime(google_sheet_data$Timestamp, format = "%m/%d/%Y %H:%M:%S"),
    format = "%m/%d/%Y"
  ))
  
  google_sheet_data$Month <- as.character(format(
    mdy(google_sheet_data$Date),
    format = "%Y-%m"
  ))
  google_sheet_data$Day_of_Week <- as.character(format(
    mdy(google_sheet_data$Date),
    format = "%A"
  ))
  
  # Remove duplicates from the dataset, since only one check-in per day is
  # supposed to count:
  if (only_count_one_signin_per_day_per_person == TRUE) {
    google_sheet_data <- google_sheet_data[
      !duplicated(
        google_sheet_data[, c("Date", "Name")]
      )
      , # Use all columns
    ]
  }
  
  return(as.data.frame(google_sheet_data))
}

get_milliseconds_from_minutes <- function(minutes){
  return(
    minutes * 
      60 * # seconds
      1000 # milliseconds
  )
}

shinyServer(function(input, output, session) {
  time_in_minutes_to_refresh_data <- 60  # Every hour
  time_in_milliseconds_to_refresh_data <- get_milliseconds_from_minutes(
    time_in_minutes_to_refresh_data
  )
  
  # Useful for developing:
    # input$dateRange <- c('2017-06-01', '2017-10-20')
    # date_range_padded <- c(ymd_hms(paste(input$dateRange[1], '00:00:01'), tz = timezone), ymd_hms(paste(input$dateRange[2], '23:59:59'), tz = timezone))
  date_range_padded <- reactive({
    c(
      ymd_hms(paste(min(input$dateRange), '00:00:01'), tz = timezone),
      ymd_hms(paste(max(input$dateRange), '23:59:59'), tz = timezone)
    )
  })
  
  refresh_timer <- reactiveTimer(
    intervalMs = time_in_milliseconds_to_refresh_data,  # Time before the app
    # automatically triggers a data refresh, in milliseconds
    session = session
  )
  
  is_admin_enabled <- function(show_notification = FALSE){
    query_parameters <- getQueryString()
    
    if (
      !is.null(query_parameters[['admin_key']]) &&
      query_parameters[['admin_key']] %in% valid_administrator_keys
    ) {
      if (show_notification == TRUE) {
        showNotification('Administrator mode is enabled.')
      }
      
      return(TRUE)
    } else {
      return(FALSE)
    }
  }
  
  output$person_select_list <- renderUI({
    if (is_admin_enabled(show_notification = TRUE)) {  # Show a notification if
        # administrator mode is enabled
      allow_multiple_selection <- TRUE
      label_for_person_list <- "Name (multiple selection enabled):"
    } else {
      allow_multiple_selection <- FALSE
      label_for_person_list <- "Name:"
    }
    
    tagList(
      h6(paste(
        "Note: Your name will only appear below if you have checked in at least once."
      )),
      selectInput(
        "selected_person_names", label = label_for_person_list, 
        choices = list(
          person_names = "Loading data..."  # This will get updated by the server.
        ),
        multiple = allow_multiple_selection
      ),
      dateRangeInput(
        'dateRange',
        label = 'Date range (yyyy-mm-dd)',
        start = Sys.Date() - 7, end = Sys.Date()  # This will output in
        # yyyy-mm-dd format
      )
    )
  })
  
  dataset <- load_google_sheets_data()  # Declare this dataset initially
    # (we'll reload it later)
  
  observe({
    # Invalidate and re-execute this reactive expression every time the
    # timer fires.
    refresh_timer()
    
    # Do something each time this is invalidated.
    # The isolate() makes this observer _not_ get invalidated and re-executed
    # when input$n changes.
    dataset <- load_google_sheets_data()
  })
  
  output$last_updated_time <- renderText({
    paste(
      "Data last updated on ",
      format(Sys.time(), tz = timezone, usetz = TRUE),
      sep = "\n")
  })
  
  dataset_that_matches_input <- reactive({
    dataset[
      dataset$Name %in% input$selected_person_names &  # Match the person's name
        (
          # We are here padding the input dates with times
          # to make them match anything at all in the date
          # range, from the very beginning second to the
          # last second (without this, a bug existed
          # whereby a person wouldn't see sign-ins made on
          # the same day they were using this Shiny app).
          date_range_padded()[1] <= mdy_hms(
            dataset$Timestamp,
            tz = timezone
          ) &
          date_range_padded()[2] >= mdy_hms(
            dataset$Timestamp,
            tz = timezone
          )
        ),
      ,  # Use all columns
    ]
  })
  
  output$individual_logins_table <- renderDataTable({
    req(input$selected_person_names != "")  # Don't run what's below unless this condition is met.
    
    if (is_admin_enabled()) {
      columns_to_show_in_main_datatable <- c("Date", "Name", "Day_of_Week")
    } else {
      columns_to_show_in_main_datatable <- c("Date", "Day_of_Week") 
    }
    
    datatable(
      dataset_that_matches_input()[
        ,  # Use all rows
        columns_to_show_in_main_datatable
      ],
      rownames = FALSE,
      options = list(searching = is_admin_enabled())
    )
  })
  
  output$total_attendance_table <- renderDataTable({
    req(input$selected_person_names != "")  # Don't run what's below unless this condition is met.
    
    datatable(
      as.data.frame(
        table(
          dataset_that_matches_input()[, "Name"],
          dnn = "Name"
        ),
        responseName = "Total_Attendance"
      ),
      rownames = FALSE,
      options = list(
        searching = FALSE,
        bInfo = FALSE
      )
    )
  })
  
  all_months_in_range <- reactive({
    # We'll use min() and max() here instead of [1] and [2] so that this still
    # works with dates specified in the wrong order.
    # The processing we're doing here is a bit convoluted. To get a sequence
    # by month, we need to have full dates, which means not just having
    # yyyy-mm but yyyy-mm-dd. So we'll temporarily use '01' as the day (instead
    # of what the user provided, since, e.g., 11-06 to 12-01 is not a full month
    # and thus would not return anything. Then we'll shave those temporary days
    # back off and just keep the yyyy-mm format.
    months_in_range <- seq(
      ymd(paste0(format(min(date_range_padded()), '%Y-%m'), '-01')),
      ymd(paste0(format(max(date_range_padded()), '%Y-%m'), '-01')),
      by = "month"
    )
    
    months_in_range <- as.character(format(months_in_range, '%Y-%m'))
    
    months_in_range
  })
  
  monthly_data <- reactive({
    req(
      input$selected_person_names != ""
    )  # Don't run what's below unless this condition is met.
    
    dataset_to_use <- dataset_that_matches_input()
    
    if (nrow(dataset_to_use) > 0) {
      frequency_table <- as.data.frame(
        table(
          dataset_to_use[,c("Month", "Name")],
          dnn = c("Month", "Name")
        ),
        responseName = "Total_Attendance"
      )
      
      frequency_table$Month <- as.character(frequency_table$Month)
      
      # Fill in any gaps in months, following the advice at
      # https://bocoup.com/blog/padding-time-series-with-r
    }
    
    # This dataframe should match column names with frequency_table above,
    # so that we can merge them below.
    all_months_data_frame <- data.frame(
      "Month" = all_months_in_range()
    )
    
    table_to_return <- NULL # We'll fill this in as a dataframe below.
    
    # For each person, pad out the data for any months in our date range where
    # there is no data for that person.
    for (person_name in unique(input$selected_person_names)) {
      if (
        exists("frequency_table") &&
        nrow(frequency_table) > 0
      ) {
        merged_data_for_person <- merge(
          frequency_table[frequency_table$Name == person_name, ],
          all_months_data_frame,
          by = "Month",
          all = TRUE
        )
      } else {
        # If we don't have any real data from the frequency_table, return
        # just the month-by-month 0s data:
        merged_data_for_person <- data.frame(
          "Month" = all_months_data_frame,
          "Name" = NA,  # We'll set this below.
          "Total_Attendance" = NA  # We'll set this below.
        )
      }
      
      merged_data_for_person$Total_Attendance[
        which(is.na(merged_data_for_person$Total_Attendance))
      ] <- 0
      
      merged_data_for_person$Name <- person_name
      
      merged_data_for_person <- merged_data_for_person[
        order(merged_data_for_person$Month)
        ,  # Use all columns
      ]
      
      table_to_return <- rbind(table_to_return, merged_data_for_person)
    }
    
    table_to_return
  })
  
  output$monthly_data_table <- renderDataTable({
    req(input$selected_person_names != "")  # Don't run what's below unless this condition is met.
    
    if (is_admin_enabled()) {
      columns_to_show_in_monthly_datatable <- c("Month", "Name", "Total_Attendance")
    } else {
      columns_to_show_in_monthly_datatable <- c("Month", "Total_Attendance") 
    }
    
    # Use an if statement here to make sure that the second date is after the
    # first one. If it's not, and we try to use 
    # '[, columns_to_show_in_monthly_datatable]', we'll get an error that we're
    # trying to reference columns that don't exist (since there is no data
    # available for an impossible date range). Even if that impossible condition
    # exists, though, we'll still return the output of monthly_data(), so that
    # we get a consistent 'No data available in table' message from the
    # datatable() function.
    if (nrow(monthly_data()) > 0) {
      if (
        nrow(monthly_data()) > 0
      ) {
        monthly_data_to_return <- monthly_data()[, columns_to_show_in_monthly_datatable]
      } else {
        monthly_data_to_return <- monthly_data()
      }
    } else {
      # Just create a placeholder dataframe that has the correct column names:
      monthly_data_to_return <- data.frame("test1" = NULL, "test2" = NULL)
    }
    
    datatable(
      monthly_data_to_return,
      rownames = FALSE,
      options = list(
        searching = is_admin_enabled(),
        bInfo = FALSE
      )
    )
  })
  
  output$monthly_data_plot <- renderPlot({
    req(
      nrow(monthly_data()) > 0
    )  # Don't run what's below unless this condition is met.
    
    plot <- ggplot(
      data = monthly_data(),
      aes(
        x = Month,
        y = Total_Attendance,
        group = Name,
        color = Name,
        shape = Name
      )
    ) +
      geom_point(position = position_dodge(w = 0.2)) +
      theme_classic() +
      theme(axis.text.x = element_text(angle = 90, hjust = 0)) +
      xlab("Year and Month") +
      ylab("Total Attendance")
    
    if (
      length(all_months_in_range()) > 1
    ) {
      plot + geom_line(
        aes(group = Name),
        alpha = 1.0,
        position = position_dodge(w = 0.2)
      )
    } else {
      plot
    }
  })
  
  # Update the dropdown list of names
  updateSelectInput(
    session,
    "selected_person_names",
    choices = c("", sort(unique(dataset$Name))),
    selected = ""
  )
  
  # Hide the default loading message from ui.R, and show the application
  # container div, following the approach from
  # https://github.com/daattali/advanced-shiny/tree/master/loading-screen
  hide(id = "loading-message", anim = TRUE, animType = "fade")
})
