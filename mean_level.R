mean_level <- function(
    dataset = pop_days,
    id = id,
    predictor = predictor,
    time_var = day,
    baseline = 30,
    agg_days = 30) {

    id <- enquo(id)
    predictor <- enquo(predictor)
    time_var <- enquo(time_var)

    pm <- dataset %>%
        filter(!!time_var <= baseline & !!time_var > baseline - agg_days) %>%
        group_by(!!id) %>%
        summarise(pred_mean = mean(!!predictor))
    return(pm)
}