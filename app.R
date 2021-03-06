library(shiny)
#library(rvest)
#library(tidyverse)
library(forecast)
library(not)


wbs.sdll.cpt <- function(x, sigma = stats::mad(diff(x)/sqrt(2)), universal = TRUE, M = NULL, th.const = NULL, th.const.min.mult = 0.3, lambda = 0.9) {

	

	n <- length(x)

    if (n <= 1) {

        no.of.cpt <- 0

        cpt <- integer(0)

    }

    else {

		if (sigma == 0) stop("Noise level estimated at zero; therefore no change-points to estimate.")

		if (universal) {

        	u <- universal.M.th.v3(n, lambda)

        	th.const <- u$th.const

        	M <- u$M

    	}

    	else if (is.null(M) || is.null(th.const)) stop("If universal is FALSE, then M and th.const must be specified.")

    	th.const.min <- th.const * th.const.min.mult

    	th <- th.const * sqrt(2 * log(n)) * sigma

    	th.min <- th.const.min * sqrt(2 * log(n)) * sigma



 		rc <- t(wbs.K.int(x, M))

 		if (max(abs(rc[,4])) < th) {

    	    no.of.cpt <- 0

        	cpt <- integer(0)



 		}

		else {

			indices <- which(abs(rc[,4]) > th.min)

			if (length(indices) == 1) {

				cpt <- rc[indices, 3]

				no.of.cpt <- 1

			}

			else {

				rc.sel <- rc[indices,,drop=F]

				ord <- order(abs(rc.sel[,4]), decreasing=T)

				z <- abs(rc.sel[ord,4])

				z.l <- length(z)

				dif <- -diff(log(z))

				dif.ord <- order(dif, decreasing=T)

				j <- 1

				while ((j < z.l) & (z[dif.ord[j]+1] > th)) j <- j+1

				if (j < z.l) no.of.cpt <- dif.ord[j] else no.of.cpt <- z.l

				cpt <- sort((rc.sel[ord,3])[1:no.of.cpt])			

			}

		} 

    }

    est <- mean.from.cpt(x, cpt)

	list(est=est, no.of.cpt=no.of.cpt, cpt=cpt)

}





wbs.sdll.cpt.rep <- function(x, sigma = stats::mad(diff(x)/sqrt(2)), universal = TRUE, M = NULL, th.const = NULL, th.const.min.mult = 0.3, lambda = 0.9, repeats = 9) {



	res <- vector("list", repeats)

	

	cpt.combined <- integer(0)

	

	nos.of.cpts <- rep(0, repeats)

	

	for (i in 1:repeats) {

		

		res[[i]] <- wbs.sdll.cpt(x, sigma, universal, M, th.const, th.const.min.mult, lambda)

		cpt.combined <- c(cpt.combined, res[[i]]$cpt)

		nos.of.cpts[i] <- res[[i]]$no.of.cpt				

		

	}



	med.no.of.cpt <- median(nos.of.cpts)

	

	med.index <- which.min(abs(nos.of.cpts - med.no.of.cpt))

	

	med.run <- res[[med.index]]

	

	list(med.run = med.run, cpt.combined = sort(cpt.combined))



}





universal.M.th.v3 <- function(n, lambda = 0.9) {

		

	mat.90 <- matrix(0, 24, 3)

	mat.90[,1] <- c(10, 50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)

	mat.90[,2] <- c(1.420, 1.310, 1.280, 1.270, 1.250, 1.220, 1.205, 1.205, 1.200, 1.200, 1.200, 1.185, 1.185, 1.170, 1.170, 1.160, 1.150, 1.150, 1.150, 1.150, 1.145, 1.145, 1.135, 1.135)

	mat.90[,3] <- rep(100, 24)

	

	mat.95 <- matrix(0, 24, 3)

	mat.95[,1] <- c(10, 50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)

	mat.95[,2] <- c(1.550, 1.370, 1.340, 1.320, 1.300, 1.290, 1.265, 1.265, 1.247, 1.247, 1.247, 1.225, 1.225, 1.220, 1.210, 1.190, 1.190, 1.190, 1.190, 1.190, 1.190, 1.180, 1.170, 1.170)

	mat.95[,3] <- rep(100, 24)



	if (lambda == 0.9) A <- mat.90 else A <- mat.95



	d <- dim(A)

	if (n < A[1,1]) {

		th <- A[1,2]

		M <- A[1,3]

	}

	else if (n > A[d[1],1]) {

		th <- A[d[1],2]

		M <- A[d[1],3]

	}

	else {

		ind <- order(abs(n - A[,1]))[1:2]

		s <- min(ind)

		e <- max(ind)

		th <- A[s,2] * (A[e,1] - n)/(A[e,1] - A[s,1]) + A[e,2] * (n - A[s,1])/(A[e,1] - A[s,1])

		M <- A[s,3] * (A[e,1] - n)/(A[e,1] - A[s,1]) + A[e,3] * (n - A[s,1])/(A[e,1] - A[s,1])

	}



	list(th.const=th, M=M)

}





wbs.K.int <- function(x, M) {

	

	n <- length(x)

	if (n == 1) return(matrix(NA, 4, 0))

	else {

		cpt <- t(random.cusums(x, M)$max.val)

		return(cbind(cpt, wbs.K.int(x[1:cpt[3]], M), wbs.K.int(x[(cpt[3]+1):n], M) + c(rep(cpt[3], 3), 0)            ))

	}

	

}





mean.from.cpt <- function(x, cpt) {



	n <- length(x)

	len.cpt <- length(cpt)

	if (len.cpt) cpt <- sort(cpt)

	beg <- endd <- rep(0, len.cpt+1)

	beg[1] <- 1

	endd[len.cpt+1] <- n

	if (len.cpt) {

		beg[2:(len.cpt+1)] <- cpt+1

		endd[1:len.cpt] <- cpt

	}

	means <- rep(0, len.cpt+1)

	for (i in 1:(len.cpt+1)) means[i] <- mean(x[beg[i]:endd[i]])

	rep(means, endd-beg+1)

}

all.intervals <- function(n) {
	
	M <- (n-1)*n/2
	
	ind <- matrix(0, M, 2)

	ind[,1] <- rep(1:(n-1), (n-1):1)

	ind[,2] <- 2:(M+1) - rep(cumsum(c(0, (n-2):1)), (n-1):1)
	
	ind

}





random.cusums <- function(x, M) {



	y <- c(0, cumsum(x))



	n <- length(x)

	

	M <- min(M, (n-1)*n/2)

		

	res <- matrix(0, M, 4)

	

	if (n==2) ind <- matrix(c(1, 2), 2, 1)

	else if (M == (n-1)*n/2) {

		ind <- matrix(0, 2, M)

		ind[1,] <- rep(1:(n-1), (n-1):1)

		ind[2,] <- 2:(M+1) - rep(cumsum(c(0, (n-2):1)), (n-1):1)

	}

	else {

		ind <- ind2 <- matrix(floor(runif(2*M) * (n-1)), nrow=2)

		ind2[1,] <- apply(ind, 2, min)

		ind2[2,] <- apply(ind, 2, max)

		ind <- ind2 + c(1, 2)

	}



	res[,1:2] <- t(ind)

	res[,3:4] <- t(apply(ind, 2, max.cusum, y))



	max.ind <- which.max(abs(res[,4]))



	max.val <- res[max.ind,,drop=F]



	list(res=res, max.val=max.val, M.eff=M)



}





max.cusum <- function(ind, y) {

	

		z <- y[(ind[1]+1):(ind[2]+1)] - y[ind[1]]

		m <- ind[2]-ind[1]+1

		ip <- sqrt(((m-1):1) / m / (1:(m-1))) * z[1:(m-1)] - sqrt((1:(m-1)) / m / ((m-1):1)) * (z[m] - z[1:(m-1)])

		ip.max <- which.max(abs(ip))

		

		c(ip.max + ind[1] - 1, ip[ip.max])



}





clipped <- function(x, minn, maxx) {
	
	pmin(pmax(x, minn), maxx)
		
}


read_data_wiki <- function() {
	
	cv.page <- "https://en.wikipedia.org/wiki/2020_coronavirus_pandemic_in_the_United_Kingdom"

	i <- 1
	
	repeat {
		
		xp <- paste('//*[@id="mw-content-text"]/div/table[', as.character(i), ']', sep="")
		read_html(cv.page) %>% html_node(xpath=xp) %>% html_table(fill=TRUE) -> dd
		if (dim(dd)[2] >= 19) break
		i <- i+1
		
	}
	
	cases_str <- str_remove_all(dd[[13]], "[,abcdefghijklmnopqrstuvwxyz]")
#	gsub(",", "", dd[[13]]) -> cases_str
	n <- length(cases_str)
	cases_int <- as.numeric(cases_str[2:(n-4)])

	tested_str <- str_remove_all(dd[[20]], "[,abcdefghijklmnopqrstuvwxyz]")

#	gsub(",", "", dd[[20]]) -> tested_str
#	gsub("a", "", tested_str) -> tested_str
#	gsub("b", "", tested_str) -> tested_str
#	gsub("c", "", tested_str) -> tested_str
#	gsub("d", "", tested_str) -> tested_str
#	gsub("e", "", tested_str) -> tested_str
#	gsub("f", "", tested_str) -> tested_str


	tested_int <- c(rep(0, 6), diff(as.numeric(tested_str[7:(n-4)])))

	tested_actual <- tested_int[30:(n-5)]
	cases_actual <- cases_int[30:(n-5)]

	deaths_str <- str_remove_all(dd[[15]], "[,abcdefghijklmnopqrstuvwxyz]")


#	gsub(",", "", dd[[15]]) -> deaths_str
	deaths_actual <- as.numeric(deaths_str[38:(n-5)])
	
	m <- length(deaths_actual)
	if (is.na(deaths_actual[m])) deaths_actual <- deaths_actual[1:(m-1)]
	
	deaths_actual[which(is.na(deaths_actual))] <- 0
	
	list(tested_actual=tested_actual, cases_actual=cases_actual, deaths_actual=deaths_actual)
	
}


read_data_wiki_secure <- function() {
	
		tryCatch(read_data_wiki(), error=function(c) {list(tested_actual=0, cases_actual=0, deaths_actual=0)})
	
}



read_data_emma <- function() {
	
	f <- read_csv("https://raw.githubusercontent.com/emmadoughty/Daily_COVID-19/master/Data/COVID19_by_day.csv", col_types = cols())
	cases_int <- f %>% pull(2)
	n <- length(cases_int)
	cases_actual <- cases_int[35:n]
	tested_int <- f %>% pull(4)
	tested_actual <- tested_int[35:n]
	deaths_int <- f %>% pull(6)
	deaths_actual <- deaths_int[42:n]

	list(tested_actual=tested_actual, cases_actual=cases_actual, deaths_actual=deaths_actual)
	
}

read_data_emma_secure <- function() {
	
	tryCatch(read_data_emma(), error=function(c) {list(tested_actual=0, cases_actual=0, deaths_actual=0)})
	
}


read_data_manual <- function() {
	
tested_actual <- 
c(1296,  1497,  1267,  1775,   386,  2748,  1424,  2255,  1122,  2053,  1447,  1301,  1215,  1698,  3597,  4975,  2533,  3826,  6337,  5779,  8400,  2355,  5842,  5522,  5605,  6491,  6583,  7847, 8911,  6999,  6961,  7209,  8240,  9793, 10215, 10590,  9406, 12334, 13313, 10912, 12959, 10713, 13543, 12993, 12776, 10745, 11879, 11170, 13839, 13943, 15472, 15944, 14106, 11626, 13522, 14629, 18401, 23115, 25577, 26355, 29571, 33455, 54575, 73191, 63667, 56397, 62956, 69839, 57006, 65092, 67443, 63339, 64362, 65337, 60410, 61741, 71644, 69590, 78537, 76684, 67409, 67409, 60744, 67681, 80297, 80297, 80297, 46887, 68086, 79870, 79356, 96061, 71701, 71392, 71737, 93460, 85786, 127249, 110485, 142276)

cases_actual <- c(5,    3,   12,    4,   12,   36,   29,   48,   45,   69,   43,   61,   78,  136,  202,  342,  251,  152,  407,  676,  643,  714, 1035,  665,  967, 1427, 1452, 2129, 2885, 2546, 2433, 2619, 3009, 4324, 4244, 4450, 3735, 5903, 3802, 3634, 5492, 4344, 5706, 5234, 5288, 4342, 5252, 4605, 4618, 5599, 5526, 5850, 4676, 4301, 4451, 4583, 5386, 4913, 4463, 4310, 3996, 4076, 6032, 6201, 4806, 4339, 3985, 4406, 6111, 5614, 4649, 3896, 3923, 3877, 3403, 3242, 3446, 3560, 3451, 3534, 2684, 2412, 2472, 2615, 3287, 2959, 2409, 1625, 2004, 2013, 1887, 2095, 2445, 1936, 1570, 1613, 1871, 1805, 1650, 1557)

extra_cases <- c(5, 10, 69, 46, 241, 243, 278, 222, 265, 296, 341, 254, 374, 331)

cases_actual[29:(29+14-1)] <- cases_actual[29:(29+14-1)] + extra_cases

#deaths_actual <- c(1,   0,   1,   2,   1,   2,   2,   1,  10,  14,  20,  16,  32,  41,  33,  56,  48,  54,  87, 156, 181, 260, 209, 180, 381, 563, 569, 684, 708, 621, 439, 786, 938, 881, 980, 917, 737, 717, 778, 761, 861, 847, 888, 596, 449, 823, 759, 616, 684, 813, 413, 360, 586, 765)

deaths_actual <- c(1,    1,    0,    1,    4,    0,    2,    1,   18,   15,   22,   16,   34,   43,   36,   56,   35,   74,  149,  186,  183,  284,  294,  214,  374,  382,  670,  652,  714,  760,  644,  568, 1038, 1034, 1103, 1152,  839,  686,  744, 1044,  842, 1029,  935, 1115,  498,  559, 1172,  837,  727, 1005,  843,  420,  338,  909,  765, 674, 739, 621, 315, 288, 693, 649, 539, 626, 346, 269, 210, 627, 494, 428, 384, 468, 170, 160, 545, 363, 338, 351, 282, 118, 121, 134, 412, 377, 324, 215, 113, 111, 324, 359, 176, 357, 204, 77, 55, 286, 245, 151, 202, 181, 36, 38, 233, 184, 135, 173, 128, 43, 15, 171, 154, 149, 186, 100, 36, 25, 155, 176, 89, 137, 67, 22, 16, 155, 126, 85, 48, 148, 21, 11, 138, 85, 66, 114, 40, 27, 11, 110, 79, 53, 123, 61, 14, 7, 119, 83, 38, 120, 74, 8, 9, 89, 65, 49, 98)

		list(tested_actual=tested_actual, cases_actual=cases_actual, deaths_actual=deaths_actual)
	
}


read_data_covid <- function() {
	
#	d_emma <- read_data_emma_secure()
#	d_wiki <- read_data_wiki_secure()
	d_wiki <- read_data_manual()
		
#	if (length(d_emma$deaths_actual) > length(d_wiki$deaths_actual))
#		deaths_actual <- d_emma$deaths_actual
#	else 
	deaths_actual <- d_wiki$deaths_actual	

#	if (length(d_emma$cases_actual) > length(d_wiki$cases_actual))
#		cases_actual <- d_emma$cases_actual
#	else 
	cases_actual <- d_wiki$cases_actual	

#	if (length(d_emma$tested_actual) > length(d_wiki$tested_actual))
#		tested_actual <- d_emma$tested_actual
#	else 
	tested_actual <- d_wiki$tested_actual	
	
	
	list(tested_actual=tested_actual, cases_actual=cases_actual, deaths_actual=deaths_actual)

}





ans <- function(x) {
	
	2 * sqrt(x + 3/8)
	
}

inv_ans <- function(y) {
	
	(y/2)^2 - 1/8
	
}





#robust.not <- function(x, tries = 19, num.zero = 10^(-10)) {
#	
#	cpts <- rep(0, tries)
#	
#	sols <- matrix(0, tries, length(x))
#	
#	
#	
#	for (i in 1:tries) {
#		sols[i,] <- predict(not(x, contrast="pcwsLinContMean"))
#		cpts[i] <- sum(abs(diff(diff(sols[i,]))) > num.zero)
#		
#	}
#
#	no.of.cpt <- sort(cpts)[ceiling(tries/2)]
#	fsols <- sols[cpts == no.of.cpt, , drop=F]
#	
#	no.of.fsols <- dim(fsols)[1]
#
#	mses <- rep(0, no.of.fsols)
#	
#	for (i in 1:no.of.fsols) mses[i] <- sum((x - fsols[i,])^2)
#
#	fsols[which.min(mses),]
#
#}

robust.not <- function(x) {
	
	predict(not(x, contrast="pcwsLinContMean", rand.intervals=F, intervals=all.intervals(length(x))))
	
}







fcast_deaths <- function() {
	
	d <- read_data_covid()
	
	d <- d$deaths_actual

	n <- length(d)

	d_ans <- ans(d)
	d_ans_fit_pl <- robust.not(d_ans)
	d_ans_fcast_pl <- clipped(2 * d_ans_fit_pl[n] - d_ans_fit_pl[n-1], 0, Inf)
	d_fit_pq <- clipped(inv_ans(d_ans_fit_pl), 0, Inf)
	d_fcast_pq <- clipped(round(inv_ans(d_ans_fcast_pl)), 0, Inf)
	
	d_fit_pl <- clipped(robust.not(d), 0, Inf)
	d_fcast_pl <- clipped(round(2 * d_fit_pl[n] - d_fit_pl[n-1]), 0, Inf)

	d_fit_fcast_tv <- forecast(d, 1)
	d_fit_tv <- clipped(as.numeric(d_fit_fcast_tv$fitted), 0, Inf)
	d_fcast_tv <- clipped(round(as.numeric(d_fit_fcast_tv$mean)), 0, Inf)

	d_ans_fit_fcast_tv <- forecast(d_ans, 1)
	d_ans_fit_tv <- as.numeric(d_ans_fit_fcast_tv$fitted)
	d_ans_fcast_tv <- as.numeric(d_ans_fit_fcast_tv$mean)
	d_fit_tva <- clipped(inv_ans(d_ans_fit_tv), 0, Inf)
	d_fcast_tva <- clipped(round(inv_ans(d_ans_fcast_tv)), 0, Inf)
	
	
	d_fit_lc <- clipped(mean.from.cpt(d, wbs.sdll.cpt(d_ans)$cpt), 0, Inf)
	d_fcast_lc <- round(d_fit_lc[n])

	

	
	
	list(d=d, d_ans=d_ans, d_ans_fit_pl=d_ans_fit_pl, d_ans_fcast_pl=d_ans_fcast_pl, d_fit_pq=d_fit_pq, d_fcast_pq=d_fcast_pq, d_fit_tv=d_fit_tv, d_fcast_tv=d_fcast_tv, d_fit_tva=d_fit_tva, d_fcast_tva=d_fcast_tva, d_fit_lc=d_fit_lc, d_fcast_lc=d_fcast_lc, d_fit_pl=d_fit_pl, d_fcast_pl=d_fcast_pl)	
	
}


dd <- fcast_deaths()


ui <- function(req) {
	fluidPage(

  titlePanel("Trends and next day forecasts for the total number of Covid-19 associated UK deaths"),

  sidebarLayout(

    sidebarPanel(

radioButtons("radio", h3("Trend estimates (references and methodology notes at the bottom of the page)"),
                        choices = list("piecewise linear" = 1, "piecewise quadratic" = 2, "default in R package 'forecast'" = 3, "piecewise constant" = 4),
                                       ,selected = 2)
                                     




    ),

    mainPanel(

	h4("Last updated 7 August 2020"),
	h3(textOutput("f_deaths")),
      plotOutput(outputId = "ts_plot"),
      			h4("black: actual figures", align="center", style = "color:black"),
			h4("brown: statistical trend estimates", align="center", style = "color:brown"),
			h6("References:"),
			h6("[piecewise linear trend]", tags$a(href="https://rss.onlinelibrary.wiley.com/doi/full/10.1111/rssb.12322", "NOT with a piecewise-linear, continuous fit")),			
			h6("[piecewise quadratic trend]", tags$a(href="https://en.wikipedia.org/wiki/Anscombe_transform", "Anscombe transform"), "+", tags$a(href="https://rss.onlinelibrary.wiley.com/doi/full/10.1111/rssb.12322", "NOT with a piecewise-linear, continuous fit"), "+", tags$a(href="https://en.wikipedia.org/wiki/Anscombe_transform#Inversion", "asymptotically unbiased inverse Anscombe")),
			h6("[default in R package 'forecast'] R package ", tags$a(href="https://CRAN.R-project.org/package=forecast", "forecast")),
			h6("[piecewise constant trend]",  tags$a(href="https://en.wikipedia.org/wiki/Anscombe_transform", "Anscombe transform"), "+", tags$a(href="https://link.springer.com/article/10.1007/s42952-020-00060-x", "WBS2.SDLL"), "+ least-squares fit to the original data with the detected change-point locations"),
			h6("[data source]", tags$a(href="https://coronavirus.data.gov.uk/", "https://coronavirus.data.gov.uk/")),
#			h6("[data sources]", tags$a(href="https://en.wikipedia.org/wiki/2020_coronavirus_pandemic_in_the_United_Kingdom", "https://en.wikipedia.org/wiki/2020_coronavirus_pandemic_in_the_United_Kingdom"), "and", tags$a(href="https://github.com/emmadoughty/Daily_COVID-19/blob/master/Data/COVID19_by_day.csv", "https://github.com/emmadoughty/Daily_COVID-19/blob/master/Data/COVID19_by_day.csv")),
			h6("[this app]", tags$a(href="https://github.com/pfryz/covid-19-deaths", "https://github.com/pfryz/covid-19-deaths")),
			h6("[author]", tags$a(href="http://stats.lse.ac.uk/fryzlewicz/", "Piotr Fryzlewicz"))



    )
  )
)
}


server <- function(input, output) {

	dd <- fcast_deaths()

	
	output$f_deaths <- renderText({

		if (input$radio == 1) pred_deaths <- dd$d_fcast_pl else if
		  (input$radio == 2) pred_deaths <- dd$d_fcast_pq else if (input$radio == 3) pred_deaths <- dd$d_fcast_tv else pred_deaths <- dd$d_fcast_lc
		
		paste("Next day's predicted number of deaths:", pred_deaths)
		
		
	})
	
	
	output$ts_plot <- renderPlot({

    		ts.plot(dd$d, main="Daily number of reported deaths, starting from 6th March 2020", ylab="", xlab="Day number")
	if (input$radio == 1)		lines(dd$d_fit_pl, col="brown", lwd=2)
   if (input$radio == 2) 		lines(dd$d_fit_pq, col="brown", lwd=2)
   if (input$radio == 3)	lines(dd$d_fit_tv, col="brown", lwd=2)
   if (input$radio == 4)	lines(dd$d_fit_lc, col="brown", lwd=2)


    })



	
}






shinyApp(ui = ui, server = server)
