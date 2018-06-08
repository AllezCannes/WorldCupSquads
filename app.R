library(shiny)
library(shinyWidgets)
library(leaflet)
library(tidyverse)

Players_df <- read_rds("Players_df.rds")

flagIcon <- makeIcon(
  iconUrl = case_when(
    Players_df$Countries == "Russia" ~ "Country_flags/Russia.png",
    Players_df$Countries == "Saudi Arabia" ~ "Country_flags/Saudi_Arabia.png",
    Players_df$Countries == "Egypt" ~ "Country_flags/Egypt.png",
    Players_df$Countries == "Uruguay" ~ "Country_flags/Uruguay.png",
    Players_df$Countries == "Portugal" ~ "Country_flags/Portugal.png",
    Players_df$Countries == "Spain" ~ "Country_flags/Spain.png",
    Players_df$Countries == "Morocco" ~ "Country_flags/Morocco.png",
    Players_df$Countries == "Iran" ~ "Country_flags/Iran.png",
    Players_df$Countries == "France" ~ "Country_flags/France.png",
    Players_df$Countries == "Australia" ~ "Country_flags/Australia.png",
    Players_df$Countries == "Peru" ~ "Country_flags/Peru.png",
    Players_df$Countries == "Denmark" ~ "Country_flags/Denmark.png",
    Players_df$Countries == "Argentina" ~ "Country_flags/Argentina.png",
    Players_df$Countries == "Iceland" ~ "Country_flags/Iceland.png",
    Players_df$Countries == "Croatia" ~ "Country_flags/Croatia.png",
    Players_df$Countries == "Nigeria" ~ "Country_flags/Nigeria.png",
    Players_df$Countries == "Brazil" ~ "Country_flags/Brazil.png",
    Players_df$Countries == "Switzerland" ~ "Country_flags/Switzerland.png",
    Players_df$Countries == "Costa Rica" ~ "Country_flags/Costa_Rica.png",
    Players_df$Countries == "Serbia" ~ "Country_flags/Serbia.png",
    Players_df$Countries == "Germany" ~ "Country_flags/Germany.png",
    Players_df$Countries == "Mexico" ~ "Country_flags/Mexico.png",
    Players_df$Countries == "Sweden" ~ "Country_flags/Sweden.png",
    Players_df$Countries == "South Korea" ~ "Country_flags/South_Korea.png",
    Players_df$Countries == "Belgium" ~ "Country_flags/Belgium.png",
    Players_df$Countries == "Panama" ~ "Country_flags/Panama.png",
    Players_df$Countries == "Tunisia" ~ "Country_flags/Tunisia.png",
    Players_df$Countries == "England" ~ "Country_flags/England.png",
    Players_df$Countries == "Poland" ~ "Country_flags/Poland.png",
    Players_df$Countries == "Senegal" ~ "Country_flags/Senegal.png",
    Players_df$Countries == "Colombia" ~ "Country_flags/Colombia.png",
    Players_df$Countries == "Japan" ~ "Country_flags/Japan.png"
  ),
  iconWidth = 25, iconHeight = 25,
  shadowWidth = 10, shadowHeight = 10
)

ui <- bootstrapPage(
  tags$style(type = "text/css", "html, body {width:100%;height:100%}"),
  
  leafletOutput("map", width = "100%", height = "100%"),
  
  absolutePanel(top = 10, right = 10,
                pickerInput("countries", label = "Select a Country:",
                            choices = list("All countries", 
                                           `Group A` = c("Egypt", "Russia", "Saudi Arabia", "Uruguay"),
                                           `Group B` = c("Iran", "Morocco", "Portugal", "Spain"),
                                           `Group C` = c("Australia", "Denmark", "France", "Peru"),
                                           `Group D` = c("Argentina", "Croatia", "Iceland", "Nigeria"),
                                           `Group E` = c("Brazil", "Costa Rica", "Serbia", "Switzerland"),
                                           `Group F` = c("Germany", "Mexico", "South Korea", "Sweden"),
                                           `Group G` = c("Belgium", "England", "Panama", "Tunisia"),
                                           `Group H` = c("Colombia", "Japan", "Poland", "Senegal")),
                            options = list(

                              `live-search` = TRUE)
                )
  )
)

server <- function(input, output, session) {
  
  filteredData <- reactive({
    if (input$countries == "All countries") {
      Players_df
    } else {
      filter(Players_df, Countries == input$countries)
    }
  })
  
  filteredIcon <- reactive({
    if (input$countries == "All countries") {
      flagIcon
    } else {
      flagIcon$iconUrl <- rep(paste0("Country_flags/", str_replace_all(input$countries, " ", "_"), ".png"), 23)
    }
    flagIcon
  })
  
  output$map <- renderLeaflet({
    leaflet(filteredData()) %>%
      addProviderTiles(providers$Esri.WorldTopoMap) %>%
      addMarkers(~lon_final, ~lat_final, 
                 icon = filteredIcon(), 
                 label = ~Player, 
                 labelOptions = labelOptions(textsize = "12px"),
                 popup = ~popup_text)
  })
  
  observe({
    leafletProxy("map", data = filteredData()) %>%
      clearShapes() %>%
      addMarkers(~lon_final, ~lat_final, 
                 icon = filteredIcon(), 
                 label = ~Player, 
                 labelOptions = labelOptions(textsize = "12px"),
                 popup = ~popup_text)
  })
}

shinyApp(ui, server)