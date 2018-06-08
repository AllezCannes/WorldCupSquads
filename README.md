README
================
AllezCannes
June 7, 2018

In anticipation of the FIFA 2018 Men's World Cup, I decided to challenge my R skills with a small project: Create an application that maps out the birth location of all the players participating in the tournament. The application is located [here](https://allezcannes.shinyapps.io/Soccer_squads/). The data was scraped on June 5, 2018, and could be subject to change until June 13, 2018.

The app is simple to use: Each marker shown indicates a player born in that location representing the national squad of the corresponding flag. You can select a particular country using the drop down (or the search bar) on the top right of the webpage to look at that squad's players. Hover on a marker to see the player's name, and click on it to get more information about him. Click on "more info" to be redirected to the player's Wikipedia page. Zoom in and out of the map, as some players are born in the same city, and their markers can therefore be clustered close together.

The application is hosted on <http://www.shinyapps.io> for free. The app will disable after 25 hours per month of usage. My apologies if it takes off and the app is given the proverbial hug of death.

Note that I only know what Wikipedia knows. This means that the accuracy of the information listed is only as good as Wikipedia. Specifically, some players (notably Saudi and a couple of South Korean players) do not have their birth city shown on Wikipedia. In those cases, I just picked the center of the country.

All work was done in R, a free and open-sourced programming language used for data analysis and visualization. In the spirit of open-sourced software, I've provided all my code in [this github repository](https://github.com/AllezCannes/WorldCupSquads). If you want to run the code on your own computer, you can download R [here](https://cran.r-project.org/), and I highly suggest using the R Studio IDE, available for download [here](https://www.rstudio.com/products/rstudio/download/#download).

The code used to scrape and clean the data is located [here](https://github.com/AllezCannes/WorldCupSquads/blob/master/Extracting_WC_Players.r), and the code that powers the application linked above can be found [here](https://github.com/AllezCannes/WorldCupSquads/blob/master/app.R).

The "Extracting WC Players" file goes through the following process:

-   Scrape this [Wikipedia's page](https://en.wikipedia.org/wiki/2018_FIFA_World_Cup_squads) for the names of the countries and the groups they belong to, as well as the names and links to the players making up each of the squads.

-   For each of the players, scrape their info box on their respective wikipedia page, as well as the link to their image (if any).

-   Cleaning/Tidying the information scraped.

-   Updating the names of cities or countries that have changed since the player's birth (e.g. West or East Germany, Leningrad, Soviet Union, etc.)

-   Look up the longitude and latitude coordinates of the cities using Google Maps API. While this is free to use, it limits to 2,500 searches per day. Since there are 736 players, this can be a limitation when I mess up and have to re-run stuff.

-   Give a slight random shock to the coordinates to avoid the markers of players born in the same city to be on top of each other. Obviously, I don't know their place of birth anymore than what Wikipedia says, so the locations are meaningless if you zoom to the city level (in fact, some markers for players born in port cities may be located in the water - this does not indicate that the player was born at sea).

Finally, **ALLEZ LES BLEUS !!!**
