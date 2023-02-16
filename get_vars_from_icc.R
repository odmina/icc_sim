# %% FUNCTION THAT DECOMPOSES TOTAL VARIANCE TO TRUE SCORE VARIANCE AND NOISE VARIANCE BY ICC
# Calculation based on Model 1 form 
#    Liljequist, D., Elfving, B., & Skavberg Roaldsen, K. (2019). 
#       Intraclass correlation – A discussion and demonstration of basic features. 
#       PLoS ONE, 14(7), e0219854. https://doi.org/10.1371/journal.pone.0219854
# Uses the following formula  ICC = var_r / (var_r + var_v) where 
#   var_r is the variance of means per subject (centered around sample mean)
#   var_v is the variance of scores whitin subjects
# Returns a list with var_r and var_v
get_vars_from_ICC <- function(sd_total = 1, ICC = 0.5) {
    var_total = sd_total^2
    var_r = var_total * ICC
    var_v = var_r * (1 - ICC) / ICC
    return(list(var_r = var_r, 
                var_v = var_v))  
}