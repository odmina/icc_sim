# WITH DECREASING INTRACLASS CORRELATION AUC GOES DOWN!!!!!!

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

# %% BASELINE RISK
# is represented by a random effect (it would be a random intercept in a mixed model).
# Normally distributed.
base_risk_SD <- 1
population$base_risk <- rnorm(N, mean = 0, sd = base_risk_SD)

# %% PREDICTOR THAT FLUCTUATES DAILY
# Based on Bernstein et. al. 2021 I assume that:
#   - mean levels of the predictor differ;
#   - SDs also vary from subject to subject, but for simplicity, 
#       SDs are held constant (will not affect the results).
# Pedictor levels are calculated based on Model 1 form 
#    Liljequist, D., Elfving, B., & Skavberg Roaldsen, K. (2019). 
#       Intraclass correlation – A discussion and demonstration of basic features. 
#       PLoS ONE, 14(7), e0219854. https://doi.org/10.1371/journal.pone.0219854
# pred_ICC represents intraclass corelation (ICC).
# Given ICC and true score variance (pred_ri_sd), 
#   intra-class variance is calculated (pred_ic_SD ** 2).
pred_ICC <- 0.5
pred_ri_sd <- 1
pred_vij_sd <- sqrt((pred_ri_sd ** 2 * (1 - pred_ICC)) / pred_ICC)
population$pred_ri <- rnorm(N, 0, pred_ri_sd)
rep_id_vec <- sort(rep(seq.int(1, N, 1), n_days)) #repeats each id n_days times
pop_days <- population[rep_id_vec, ]
pop_days$day <- rep(tv_days, N)
pop_days$predictor <- pop_days$pred_ri + rnorm(n = n_days * N, sd = pred_vij_sd, mean = 0)
#pop_days$predictor <- unlist(lapply(s_sample$pred_mean, rnorm, n = n_days, sd = pred_ic_sd))

# %% DAILY RANDOM RISK FLUCTUATION
# results from day to day risk and protective factors with varying hazard periods.
# Also normally distributed, same variance as baseline risk - it does not have to be the case
#   but on the other hand it should not affect the effect of simulation.
noise_SD <- 1
pop_days$noise <- rnorm(N * n_days, mean = 0, sd = noise_SD)

# %% FINAL SA RISK CALCULATION
pop_days$sa_risk <- pop_days$base_risk + pop_days$predictor + pop_days$noise

# %% BINARY OUTCOME
# Two alternatives:
#   - general population with 0,4% SA twelve-month prevalence (Borges et. al., 2010);
#   - clinical cohort with higher twelve-month prevalence of SA.
# I simulate clinical cohort.
SA_incidence_year <- 0.06
SA_incidence_day <- SA_incidence_year / 365
cutoff <- quantile(pop_days$sa_risk, probs = 1 - SA_incidence_day)
pop_days$sa <- ifelse(pop_days$sa_risk > cutoff, 1, 0)

# %% SAMPLE
sample_n <- 1000
sample_ids <- sample(1:N, size = sample_n, replace = FALSE)
sample_days <- pop_days[id %in% sample_ids]

# %% checks - to be removed
pop_days %>% 
    group_by(id) %>%
    summarise(attempts = sum(sa)) %>%
    group_by(attempts) %>%
    summarise(n = n())
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
pred_days$m_lme_pred <- predict(m_lme, newdata = pred_days, re.form = ~0, type = "response")
print("BASE")
(my_roc <- roc(response = pred_days$sa, predictor = pred_days$m_lme_pred))

# %% ICC
print("ICC")
(icc <- lmer(predictor ~ day + (1|id), data = sample_days))

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


