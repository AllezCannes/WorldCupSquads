library(tidyverse)
library(rvest)
library(XML)
library(RCurl)
library(ggmap)
library(leaflet)

wiki_URL <- "https://en.wikipedia.org/wiki/2018_FIFA_World_Cup_squads" #Storing the URL since it will be called upon multiple times.

#Setting up the xpaths to extract the WC squads
xpaths <- vector(mode = "character", length = 32) #First setting an empty vector that the for loop below will store.

for (i in 1:32) {
  xpaths[i] <- paste0('//*[@id="mw-content-text"]/div/table[', i, ']') #Store xpaths for each of the 32 teams
}

#The following takes the table of contents from the squads page, 
#and turns it into a dataframe with the group each NT belonged to, 
#along with the NT names and the paths to extract the squad. Then,
#it iterates through each country and extracts its squad and stores
#it as a list column.
Countries_df <- read_html(wiki_URL) %>% #Read the HTML page...
  html_node(xpath = '//*[@id="toc"]') %>%  #Extract the node storing the table of contents
  html_text() %>% #Read the table of contents as text
  str_split("\n") %>% #Split the string by the newline code separating the 32 nations
  unlist() %>% #Flatten to a vector
  as_tibble() %>% #Set it to a data frame
  rename(Countries = value) %>% #Change the variable name to "Countries"
  filter(str_detect(Countries, "^[1-8]\\."), !str_detect(Countries, "Group")) %>% #Keep only those rows that list the countries
  separate(Countries, c("Groups", "delete", "Countries"), sep = c(1, 3)) %>% #Split the number indicating the group each NT was in from the country name and store them in separate variables
  mutate(Groups = LETTERS[as.numeric(Groups)], #Change the numbers indicating the group to its corresponding letter
         Countries = str_trim(Countries), #Remove white space around Country name
         xpaths = xpaths, #Store country's xpaths from the earlier for loop
         squads = map(xpaths, function (x) read_html(wiki_URL) %>%  #For each NT, read the page...
                        html_node(xpath = x) %>% #Extract the squad table...
                        html_table())) #And read it as a table

Players_df <- Countries_df %>% 
  unnest(squads) %>%  #Spread out the data frame so that each row is a player.
  filter(Player != "") #Remove blank rows

#Now extracting the players' wiki pages so that I can look up their personal information (place of birth, height, playing position)
player_links <- read_html(wiki_URL) %>% #Read the page
  html_nodes("th > a:nth-child(1)") %>% #Find the node for the list of players
  html_attr("href") #Extract the redirect link for each player
player_links <- player_links[1:nrow(Players_df)] #Not sure where those links at the end came from. *shrug* buh-bye

player_info <- function(x) { #Creating a function grabbing players' info that would be applied to every player.
  player_info <- html_session("https://en.wikipedia.org/") %>% #Go to wikipedia
    jump_to(x) %>% #And go to the player's link x
    html_node('.infobox') %>% #Grab the node's infobox
    html_table(fill = TRUE) #Turn that info into a table
  player_info <- player_info[, 1:2] #Grab just the first couple of columns
  player_info <- player_info %>% 
    as_tibble() %>% #Turn that into a tibble
    filter(.[[1]] %in% c("Place of birth", "Height", "Playing position")) #Select only the rows of info I want
  names(player_info) <- c("attribute", "info") #Change the names of the variables
  return(player_info)
}

Players_df <- Players_df %>% #Take the players data frame
  mutate(player_links = player_links, #Store their respective links
         player_data = map(player_links, player_info)) %>% #and apply the function created above to extract info from the player's wikipage
  unnest() %>% #open the player_data. This will repeat the line 3x for each player.
  spread(key = attribute, value = info) #Spread the data so that those 3 pieces of info have their own variable.

#Now grabbing the images in the infobox
player_image <- function (x) { #Creating a function that will...
  html_session("https://en.wikipedia.org/") %>% #Back to Wikipedia we go
    jump_to(x) %>% #And go to the player's link x
    html_node('.image img') %>% #Find the node of the image in the infobox
    html_attr("src") #Grab its URL location
}

Players_df <- mutate(Players_df, image = map(player_links, player_image)) #Apply the function created above for each player

#Cleaning up the data 
Players_df <- Players_df %>% 
  mutate(Captain = if_else(str_detect(Player, "\\(c\\)"), "Captain", ""), #Add a captain variable if "(c)" is in the player's name.
         Player = Player %>% str_remove("\\(c\\)") %>% str_trim(), #Removing the "(c)" from the player's name and any whitespace.
         `Date of birth (age)` = `Date of birth (age)` %>% str_replace("^\\(\\d{4}-\\d{2}-\\d{2}\\)", "") %>% str_trim(), #Removing the "(yyyy-mm-dd)" part in this field
         Player = Player %>% str_remove("\\[[^]]*\\]") %>% str_trim(), #Remove footnotes
         Club = Club %>% str_remove("\\[[^]]*\\]") %>% str_trim(), #Remove footnotes
         Height = Height %>% str_remove("\\[[^]]*\\]") %>% str_trim(), #Remove footnotes
         `Place of birth` = `Place of birth` %>% str_remove("\\[[^]]*\\]") %>% str_trim(), #Remove footnotes
         `Playing position` = `Playing position` %>% str_remove("\\[[^]]*\\]") %>% str_trim()) %>% #Remove footnotes
  separate(Club, c("Club", "club_delete"), sep = "\\[", extra = "merge", fill = "right") %>% #Remove footnotes for those that didn't work above for some reason
  separate(Height, c("Height", "height_delete"), sep = "\\[", extra = "merge", fill = "right") %>% #Remove footnotes for those that didn't work above for some reason 
  separate(`Place of birth`, c("Place of birth", "birth_delete"), sep = "\\[", extra = "merge", fill = "right") %>% #Remove footnotes for those that didn't work above for some reason
  separate(`Playing position`, c("Playing position", "position_delete"), sep = "\\[", extra = "merge", fill = "right") %>% #Remove footnotes for those that didn't work above for some reason
  select(-delete, -xpaths, -Pos., -player_links, -club_delete, -height_delete, -birth_delete, -position_delete) #Remove unneeded columns

#For each birthplace, get long and lat. Beforehand, I need to set up an alternate version of the place of birth 
#variable to remove country names that don't exist anymore. Somehow the geolocation API works better if they only have
#the city name.
temp <- count(Players_df, `Place of birth`)
View(temp)

Players_df <- mutate(Players_df, 
                     location_lookup = `Place of birth`,
                     location_lookup = str_replace(location_lookup, "West Germany", "Germany"),
                     location_lookup = str_replace(location_lookup, "East Germany", "Germany"),
                     location_lookup = str_replace(location_lookup, "West Berlin", "Berlin, Germany"),
                     location_lookup = str_replace(location_lookup, ", FR Yugoslavia", ""),
                     location_lookup = str_replace(location_lookup, ", SFR Yugoslavia", ""),
                     location_lookup = str_replace(location_lookup, ", Yugoslavia", ""),
                     location_lookup = str_replace(location_lookup, ", SR Macedonia", ""),
                     location_lookup = str_replace(location_lookup, ", SR Croatia", ""), 
                     location_lookup = str_replace(location_lookup, "Leningrad, RSFSR,Soviet Union", "St Petersburg"),
                     location_lookup = str_replace(location_lookup, ", Soviet Union", ""),
                     location_lookup = str_replace(location_lookup, ", Russian SFSR", ""),
                     location_lookup = str_replace(location_lookup, ", RSFSR", ""),
                     location_lookup = str_replace(location_lookup, ", Uzbek SSR", ""),
                     location_lookup = str_replace(location_lookup, ", Czechoslovakia", ""),
                     location_lookup = str_replace(location_lookup, "Zaire", "Democratic Republic of the Congo"))
                     
rm(temp)

locations_df <- distinct(Players_df, location_lookup)

locations_df <- mutate_geocode(locations_df, location_lookup, source = "google", output = "latlon") #Get lon/lat for places of birth

locations_df_missed <- locations_df %>% #Issues with the API limitations lead to some cities missed. 
  filter(is.na(lon)) %>%  
  select(-lon, -lat) %>% 
  mutate_geocode(location_lookup, source = "google", output = "latlon")

#The next few lines repeat the process and then re-merge the locations
locations_df_missed2 <- locations_df_missed %>% 
  filter(is.na(lon)) %>% 
  select(-lon, -lat) %>% 
  mutate_geocode(location_lookup, source = "google", output = "latlon")

locations_df <- bind_rows(
  filter(locations_df, !is.na(lon)),
  filter(locations_df_missed, !is.na(lon)),
  locations_df_missed2
)

#Add a very slight random shock to the latitude and longitude coordinates so that the markers don't end up on top of each other.
Players_df <- Players_df %>% 
  left_join(locations_df) %>% 
  mutate(lat_final = jitter(lat, amount = 0.02),
         lon_final = jitter(lon, amount = 0.02))

Players_df <- mutate(Players_df,
                     links = paste0("https://en.wikipedia.org", player_links), #Bringing in player links
                     popup_text = paste0("<center>", #Setting up poopup info
                       ifelse(!is.na(image), paste0("<img src = https:", image, " width='100'>"), ""),
                       "</br><b>", Player, "</b>",
                       "</br><b>Date of birth</b>: ", Date.of.birth..age., 
                       "</br><b>Place of birth</b>: ", Place.of.birth,
                       "</br><b>Playing position</b>: ", Playing.position,
                       "</br><b>Club</b>: ", Club, 
                       "</br><a href='", links, "' target='_blank'>More info...</a></center>"))

#Saving for the app
write_rds(Players_df, "Players_df.rds") 
write_rds(Countries_df, "Countries_df.rds") 

#Setting up icons - Flags taken from https://www.iconfinder.com
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

#Map test
leaflet(Players_df) %>%
  addProviderTiles(providers$Esri.WorldTopoMap) %>%
  addMarkers(~lon_final, ~lat_final, 
             icon = flagIcon, 
             label = ~Player, 
             labelOptions = labelOptions(textsize = "12px"),
             popup = ~popup_text)
