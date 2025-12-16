# To organize the sensor data from Jacques
library(readr)
library(dplyr)
library(lubridate)
library(parallel)
library(doParallel)

im <- list.files("/Users/davidkahler/Downloads/Turbidity/", 
                 pattern = "*.txt$", 
                 full.names = TRUE, 
                 recursive = TRUE, 
                 ignore.case=TRUE, 
                 include.dirs = TRUE)

registerDoParallel(detectCores())
x <- foreach (i = 1:length(im), .combine = 'rbind') %dopar% { # parallel computing loop: this changes how data are transferred back from each operation.
     y <- read_csv(im[i], skip = 3, col_names = FALSE)
     if (length(y) > 0) {
          z <- y %>%
               mutate(dt = force_tz(as_datetime(X1), tz = "Africa/Johannesburg"), temp = X3, Sensor = X4) %>%
               select(dt, temp, Sensor) %>%
               mutate(d = as_date(dt)) %>%
               group_by(d) %>%
               summarize(t = mean(temp, rm.na = TRUE), s = mean(Sensor, rm.na = TRUE), c = length(Sensor)) %>%
               mutate(dn = as.numeric(d))
          print(z)
     }
}

n <- max(x$dn) - min(x$dn) + 1
y <- array(NA, dim = n)
count <- min(x$dn) - 1 # so that we add first.
for (i in 1:n) {
     count <- count + 1
     y[i] <- count
}

z <- foreach (i = 1:n, .combine = 'rbind') %dopar% {
     look <- y[i]
     tem <- 0
     sig <- 0
     num <- 0
     for (j in 1:nrow(x)) {
          if (x$dn[j] == look) {
               tem <- tem + (x$t[j] * x$c[j])
               sig <- sig + (x$s[j] * x$c[j])
               num <- num + x$c[j]
          }
     }
     print(c(look, tem, sig, num))
}
     
z <- data.frame(z)
z <- z %>%
     mutate(d = as_date(X1)) %>%
     mutate(temperature = X2/X4) %>%
     mutate(turbidity = X3/X4) %>%
     select(d, temperature, turbidity)




