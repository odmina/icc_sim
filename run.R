# %% LIBRARIES
library(parallel)

source("functions/sim_data.R")

# %% CREATE A DIRECTORY TO STORE SIMULATION RESULTS
dir_name <- paste0("sim_results_", Sys.Date(), "_", format(Sys.time(), "%H%M%S"))
dir.create(dir_name)

# %% SET SIMULATION PARAMETERS
N <- 20000
sample_sizes <- c(100, 200, 500, 1000)
pred_ICCs <- c(0.3, 0.5, 0.7)
noise_ICCs <- c(0.3, 0.5, 0.7)
gtm_betas <- c(0.2, 0.3, 0.4, 0.5)
SA_incidences_days <- 0.01

# %% EXPAND PARAMETERS TO A GRID
params <- expand.grid(N,
    sample_sizes,
    pred_ICCs,
    noise_ICCs,
    gtm_betas,
    SA_incidences_days)
names(params) <- c("N",
    "sample_sizes",
    "pred_ICCs",
    "noise_ICCs",
    "gtm_betas",
    "SA_incidences_days")
#mini_params <- params[1:8, ]

# %% SET UP CLUSTER
n_cores <- detectCores()
cl <- makeCluster(n_cores)
# load libraries to workers
clusterEvalQ(cl, {
        library(dplyr)
        library(data.table)
        library(lme4)
        library(pROC)
        })
# set working dir for each worker
wd <- getwd()
clusterExport(cl, "wd")
# load helper functions for each worker
clusterEvalQ(cl, {
        file_sim_data <- paste0(wd, "/functions/sim_data.R")
        source(file_sim_data)
        file_mean_level <- paste0(wd, "/functions/mean_level.R")
        source(file_mean_level)
        file_get_vars <- paste0(wd, "/functions/get_vars_from_icc.R")
        source(file_get_vars)
    })

# %% RUN PARELLELIZED
runs <- 100
for (i in seq_len(runs)) {
    sim_results <- clusterMap(cl, sim_data,
        N = params[["N"]],
        sample_size = params[["sample_sizes"]],
        pred_ICC = params[["pred_ICCs"]],
        gtm_beta = params[["gtm_betas"]],
        SA_incidence_day = params[["SA_incidences_days"]],    
        RECYCLE = FALSE,
        SIMPLIFY = FALSE, 
        USE.NAMES = TRUE)
    # save data to csv
    sim_results_df <- do.call("rbind", sim_results)
    results_file <- sprintf("results%04d.csv", i)
    write.csv(sim_results_df, paste0(dir_name, "/", results_file))
    rm(sim_results_df)
    rm(sim_results)
}

stopCluster(cl)


