# %% SIMULATION ASSUMPTIONS
# Based on Rudd's fluid vulnerability theory (2006),
# which states that:
#   - each individual has some baseline chronic suicide risk;
#   - the risk fluctuates over time;
#   - those fluctuations may be crutial to explaing ideation to action;
#   - methods that allow to tract time changes should be utilized in research.
# Ref: Bryan, C. J., & Rudd, M. D. (2016). 
#   The importance of temporal dynamics in the transition from suicidal thought to behavior. 
#   Clinical Psychology: Science and Practice, 23(1), 21–25.
# Thus, for each individual I model:
#   - random baseline suicide risk (normally distributed);
#   - random time fluctuations of suicide risk;
#   - predictior that fluctuates over time;
#   - siucide risk changes that are dependent on the predictior.
# I intent do show that sampling from one point of such ground truth data leads to
#   gross effect underestimation and this underestimation increases with assumed hazard period lenght.

# %% LIBRARIES
library(dplyr)
library(data.table)
library(lme4)
library(pROC)

# %% TIME VECTOR
# I am using one day data resolution for ground truth simulation.
# Then I am going to use week, month and year hazard periods and varying timeframes for risk change.
n_days <- 2*365 #two years
tv_days <- seq.int(1, n_days, 1)

# %% SIMULATION NUMBER OF OBSERVATIONS
N <- 20000
population <- data.table(id = seq.int(1, N, 1))

# %% FUNCTION THAT DECOMPOSES TOTAL VARIANCE TO TRUE SCORE VARIANCE AND BY ICC
# Calculation based on Model 1 form 
#    Liljequist, D., Elfving, B., & Skavberg Roaldsen, K. (2019). 
#       Intraclass correlation – A discussion and demonstration of basic features. 
#       PLoS ONE, 14(7), e0219854. https://doi.org/10.1371/journal.pone.0219854
# Uses the following formula  ICC = var_r / (var_r + var_v) where 
#   var_r is the variance of means per subject (centered around sample mean)
#   var_v is the variance of scores whitin subjects
# Returns a list with var_r and var_v
get_disp_from_ICC <- function(sd_total = 1, ICC = 0.5) {
    var_r = var_total * ICC
    var_v = var_r * (1 - ICC) / ICC
    return(list(var_r = var_r, 
                var_v = var_v))  
}

# %% PREDICTOR THAT FLUCTUATES DAILY
# Based on Bernstein et. al. 2021 I assume that:
#   - mean levels of the predictor differ;
#   - SDs also vary from subject to subject, but for simplicity, 
#       SDs are held constant (will not affect the results).
# pred_ICC represents intraclass corelation (ICC).
# pred_var_total represents total variance of the predictior
pred_ICC <- 0.5
pred_var_total <- 1
pred_vars <- get_var_from_ICC(pred_var_total, pred_ICC)
pred_sd_r <- sqrt(pred_vars$var_r)
pred_sd_v <- sqrt(pred_vars$var_v)

# %% PER SUBJECT RISK & DAILY RANDOM RISK FLUCTUATION
# Noise per subject 
#   (variance of random effect in not caused by the variance of the mean predictor level). 
# Daily random risk fluctuations are error term for daily measurements.
# To account for their relative relevance ICC is also used.
noise_ICC <- 0.5
noise_var_total <- 1
noise_vars <- get_var_from_ICC(noise_var_total, noise_ICC)
noise_sd_r <- sqrt(noise_vars$var_r)
noise_sd_v <- sqrt(noise_vars$var_v)

# %% ADD NOISE AND PREDICTOR VARIABLES ON SUBJECT LEVEL
population$noise_r <- rnorm(N, mean = 0, sd = noise_sd_r)
population$pred_r <- rnorm(N, mean = 0, sd = pred_sd_r)

# %% ADD DATA ON DAYS LEVEL
rep_id_vec <- sort(rep(seq.int(1, N, 1), n_days)) #repeats each id n_days times
pop_days <- population[rep_id_vec, ]
pop_days$day <- rep(tv_days, N)
pop_days$predictor <- pop_days$pred_r + rnorm(n = n_days * N, sd = pred_sd_v, mean = 0)
pop_days$noise <- pop_days$noise_r + rnorm(n = n_days * N, sd = noise_sd_v, mean = 0)

# %% FINAL SA RISK CALCULATION
variance_scaling = 0.2
pop_days$sa_risk <- variance_scaling * pop_days$predictor + pop_days$noise

# %% BINARY OUTCOME
SA_incidence_day <- 0.0014
cutoff <- quantile(pop_days$sa_risk, probs = 1 - SA_incidence_day)
pop_days$sa <- ifelse(pop_days$sa_risk > cutoff, 1, 0)

# %% SAMPLE
sample_n <- 200
sample_ids <- sample(1:N, size = sample_n, replace = FALSE)
sample_days <- pop_days[id %in% sample_ids]

# %% checks 
pop_days %>% 
    group_by(id) %>%
    summarise(attempts = sum(sa)) %>%
    group_by(attempts) %>%
    summarise(n = n(), proc = n / N)
sample_days %>% 
    group_by(id) %>%
    summarise(attempts = sum(sa)) %>%
    group_by(attempts) %>%
    summarise(n = n())

# %% Mixed model reflecting ground truth - sample
m_lme <- glmer(sa ~ predictor + (1|id), data = sample_days, family = "binomial")

# %% get ROC curve - on the remainder of the dataset
#   i.e. obsevations that are not included in the sample used for model fit
# first make predictions based on variable predictor
# do not include intercepts (it is achieved by re.form = ~0)
pred_days <- pop_days[!(id %in% sample_ids)]
pred_days$m_lme_pred <- predict(m_lme, 
    newdata = pred_days, 
    re.form = ~0, 
    type = "response")
print("BASE")
(my_roc <- roc(response = pred_days$sa, predictor = pred_days$m_lme_pred))

# %% Simple model with one measurement and follow-up 
# I start with sampling one day and then check whether a SA occured during follow-up
# day 365 - measurement, next days - followup
# 1. get predictor level
predictor <- pop_days[pop_days$day == 365, c("id", "predictor")]
# 2. get info on SA during followup
sa_followup <- pop_days[ ,  
    .(sa = any(sa == 1 & day > 365)), 
    by = id]
# 3. join predictor with info about SA
d1 <- predictor[sa_followup, on = .(id)]
d1_sample <- d1[id %in% sample_ids]
d1_pred <- d1[!(id %in% sample_ids)]
# 4. model
m_d1 <- glm(sa ~ predictor, data = d1_sample, family = "binomial")
d1_pred$y_hat <- predict(m_d1, newdata = d1_pred, type = "response")
print("MODEL")
(my_roc_d1 <- roc(response = d1_pred$sa, predictor = d1_pred$y_hat))


