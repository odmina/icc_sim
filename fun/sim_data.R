# %% FUNCTION THAT SIMULATES A DATASET, MODEL AND PREDICTIONS
sim_data <- function(
    N = 20000,
    sample_size = 500,
    pred_ICC = 0.5,
    noise_ICC = 0.5,
    gtm_beta = 0.2,
    SA_incidence_day = 0.006
    ) {

    # TIME VECTOR (tv_days) - how many days in simulation?
    # days before followup plus followup lenght
    # baseline - day of the measurment
    days_before = 30
    days_follow_up = 30
    n_days <- days_before + days_follow_up
    tv_days <- seq.int(1, n_days, 1)
    baseline <- days_before

    # SIMULATION DATA TABLE - ONE ROW PER PERSON
    N <- 20000
    population <- data.table(id = seq.int(1, N, 1))

    # PREDICTOR THAT FLUCTUATES DAILY
    # decompose variance based in ICC
    pred_sd_total <- 1
    pred_vars <- get_vars_from_ICC(pred_sd_total, pred_ICC)
    pred_sd_r <- sqrt(pred_vars$var_r)
    pred_sd_v <- sqrt(pred_vars$var_v)

    # PER SUBJECT RISK & DAILY RANDOM RISK FLUCTUATION
    # Noise per subject 
    #   (variance of random effect in not caused by the variance of the mean predictor level). 
    # Daily random risk fluctuations are error term for daily measurements.
    # ICC is used to account for their relative relevance.
    noise_sd_total <- 1
    noise_vars <- get_vars_from_ICC(noise_sd_total, noise_ICC)
    noise_sd_r <- sqrt(noise_vars$var_r)
    noise_sd_v <- sqrt(noise_vars$var_v)

    # ADD NOISE AND PREDICTOR VARIABLES ON PERSON LEVEL
    population$noise_r <- rnorm(N, mean = 0, sd = noise_sd_r)
    population$pred_r <- rnorm(N, mean = 0, sd = pred_sd_r)

    # ADD DATA ON DAYS LEVEL
    # repeats each id n_days times
    rep_id_vec <- sort(rep(seq.int(1, N, 1), n_days))
    pop_days <- population[rep_id_vec, ]
    # adds days numbers - repeat tv days N times
    pop_days$day <- rep(tv_days, N)
    # add vars for predictor and noise for each patient-day
    pop_days$predictor <- pop_days$pred_r + rnorm(n = n_days * N, sd = pred_sd_v, mean = 0)
    pop_days$noise <- pop_days$noise_r + rnorm(n = n_days * N, sd = noise_sd_v, mean = 0)

    # FINAL SA RISK CALCULATION
    pop_days$sa_risk <- gtm_beta * pop_days$predictor + pop_days$noise

    # BINARY OUTCOME
    cutoff <- quantile(pop_days$sa_risk, probs = 1 - SA_incidence_day)
    pop_days$sa <- ifelse(pop_days$sa_risk > cutoff, 1, 0)

    # SA DURING FOLLOW-UP?
    sa_followup <- pop_days %>%
        filter(day > baseline) %>%
        group_by(id) %>%
        summarise(sa_followup = sum(sa) > 0)
    pop_days <- pop_days %>%
        left_join(sa_followup)
    population <- population %>%
        left_join(sa_followup)

    # MEAN PREDICTOR LEVEL
    # calculate
    mean_pred_30 <- mean_level(dataset = pop_days, predictor = predictor, agg_days = 30)
    mean_pred_14 <-  mean_level(dataset = pop_days, predictor = predictor, agg_days = 14)
    mean_pred_7 <- mean_level(dataset = pop_days, predictor = predictor, agg_days = 7)
    mean_pred_1 <- mean_level(dataset = pop_days, predictor = predictor, agg_days = 1)

    # join with pop_days
    pop_days <- pop_days %>%
        left_join(mean_pred_30) %>%
        rename(predictor_m30 = "pred_mean") %>%
        left_join(mean_pred_14) %>%
        rename(predictor_m14 = "pred_mean") %>%
        left_join(mean_pred_7) %>%
        rename(predictor_m7 = "pred_mean") %>%
        left_join(mean_pred_1) %>%
        rename(predictor_m1 = "pred_mean")
    # join with population
    population <- population %>%
        left_join(mean_pred_30) %>%
        rename(predictor_m30 = "pred_mean") %>%
        left_join(mean_pred_14) %>%
        rename(predictor_m14 = "pred_mean") %>%
        left_join(mean_pred_7) %>%
        rename(predictor_m7 = "pred_mean") %>%
        left_join(mean_pred_1) %>%
        rename(predictor_m1 = "pred_mean")

    # SAMPLE & PREDICTION DATASET
    # sample - up till baseline (1-30)
    # prediction - after baseline (31-60)
    sample_ids <- sample(1:N, size = sample_size, replace = FALSE)
    sample <- population[id %in% sample_ids]
    pred <- population[!(id %in% sample_ids)]
    sample_days <- pop_days[id %in% sample_ids & day <= baseline]
    pred_days <- pop_days[!(id %in% sample_ids) & day > baseline]

    # TRUNCATE OUTCOME DURING FOLLOW-UP TO AVOID INFLATED PERFORMANCE OF THE MIXED MODEL
    pred_days$not_dupl <- !duplicated(pred_days[ , c("id", "sa")]) | pred_days$sa == 0
    pred_days <- pred_days %>% filter(not_dupl)

    # not used - models fail to converge
    # SAMPLE DAYS SUBSETS USED FOR MODELING
    ## 14 days
    #m_days_14 <- sample_days$day > baseline - 14
    #sample_days_14 <- sample_days[m_days_14, ]
    ## 7 days
    #m_days_7 <- sample_days$day > baseline - 7
    #sample_days_7 <- sample_days[m_days_7, ]

    # MODEL 1.30 
    # all thirty days before followup, id as random effect
    m_mixed_30 <- glmer(sa ~ predictor + (1|id), 
        data = sample_days,
        family = "binomial")

    #not fited - due to low incidence, models fail to converge
    # MODEL 1.14 - mixed, 14 days_before
    #m_mixed_14 <- glmer(sa ~ predictor + (1|id), 
    #    data = sample_days_14, 
    #    family = "binomial")
    ##not fited -  due to low incidence, models fail to converge
    ## MODEL 1.07 - mixed, just 7 days_before
    #m_mixed_7 <- glmer(sa ~ predictor + (1|id), 
    #    data = sample_days_7, 
    #    family = "binomial")

    # MODEL 2.30 - WORKS ON AVERAGES FORM 30 DAYS
    m_lin_30 <- glm(sa_followup ~ predictor_m30, sample, family = "binomial")

    # MODEL 2.14 - WORKS ON AVERAGES FORM 14 DAYS
    m_lin_14 <- glm(sa_followup ~ predictor_m14, sample, family = "binomial")

    # MODEL 2.07 - WORKS ON AVERAGES FORM 7 DAYS
    m_lin_7 <- glm(sa_followup ~ predictor_m7, sample, family = "binomial")

    # MODEL 2.01 - WORKS ON AVERAGES FORM 7 DAYS
    m_lin_1 <- glm(sa_followup ~ predictor_m1, sample, family = "binomial")

    # get ROC curve - on the remainder of the dataset
    #   i.e. obsevations that are not included in the sample used for model fit
    # first make predictions based on variable predictor
    # do not include intercepts (it is achieved by re.form = ~0)
    pred_days$m_mixed_30 <- predict(m_mixed_30, 
        newdata = pred_days, 
        re.form = ~0, 
        type = "response")
    my_roc_mixed_30 <- roc(response = pred_days$sa, predictor = pred_days$m_mixed_30, direction = "<")

    #get ROC curve on glm pred mean 30
    pred$m_lin_30 <- predict(m_lin_30, newdata = pred)
    my_roc_lin_30 <- roc(response = pred$sa_followup, predictor = pred$m_lin_30, direction = "<")

    #get ROC curve on glm pred mean 14
    pred$m_lin_14 <- predict(m_lin_14, newdata = pred)
    my_roc_lin_14 <- roc(response = pred$sa_followup, predictor = pred$m_lin_14, direction = "<")

    #get ROC curve on glm pred mean 7
    pred$m_lin_7 <- predict(m_lin_7, newdata = pred)
    my_roc_lin_7 <- roc(response = pred$sa_followup, predictor = pred$m_lin_7, direction = "<")

    #get ROC curve on glm pred mean 1
    pred$m_lin_1 <- predict(m_lin_1, newdata = pred)
    my_roc_lin_1 <- roc(response = pred$sa_followup, predictor = pred$m_lin_1, direction = "<")

    ret <- data.frame(sample_size = sample_size,
    pred_ICC = pred_ICC,
    noise_ICC = noise_ICC,
    gtm_beta = gtm_beta,
    ve_pred = (cor(pred_days$predictor, pred_days$sa_risk))^2,
    SA_incidence_day = SA_incidence_day,
    SA_followup = sum(population$sa_followup)/N,
    auc_m_mixed_30 = my_roc_mixed_30$auc,
    auc_m_lin_30 = my_roc_lin_30$auc,
    auc_m_lin_14 = my_roc_lin_14$auc,
    auc_m_lin_7 = my_roc_lin_7$auc,
    auc_m_lin_1 = my_roc_lin_1$auc
    )

    return(ret)
}