# %% LIBRARIES
library(tidyverse)

# %% LOAD DATA
data_folder <- readline("Name of the folder where simulation results are stored: ")
files <- list.files(data_folder)
files <- paste0(data_folder, "/", files)
dfs <- lapply(files, read_csv, show_col_types = FALSE)
for (i in seq_len(length(dfs))) {
    dfs[[i]]$run <- i
}
sim_results_wide <- do.call("rbind", dfs)
model_cols <- c("auc_m_mixed_30", "auc_m_lin_30", "auc_m_lin_14", "auc_m_lin_7", "auc_m_lin_1")
sim_results <- sim_results_wide %>%
    pivot_longer(cols = all_of(model_cols), 
        names_to = "model_type", 
        values_to = "auc")

# %% performance of models by model type, icc faceted over sample_size
ggplot(data = sim_results) +
    geom_boxplot(aes(x=model_type, y=auc, fill = as.factor(pred_ICC))) +
    facet_wrap(~sample_size) +
    theme_classic() +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
    ggtitle("performance of models by ICC and model type, facets - sample_size")
#ggsave("figures/icc_type_n.png")

# %% performance of models by model type, icc faceted over gtm_beta, sample_size=200
ggplot(data = sim_results %>% filter(
        sample_size==200)) +
    geom_boxplot(aes(x=model_type, y=auc, fill = as.factor(pred_ICC))) +
    facet_wrap(~gtm_beta) +
    theme_classic() +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
    ggtitle("performance of models by ICC and model type, \nfacets - ground truth model predictor beta1, n=200")
#ggsave("figures/icc_type_beta.png")