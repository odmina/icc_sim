---
title: "Repeated measurements can boost the ablitity to predict suicide attempts: a stimulation"
---

Suicide is one of the leading causes of death, especially in younger age groups. Twelve-month prevalence of suicide attempts is 0.3-0.4% (1). Thus, from a statistical point of view, suicide attempts prediction poses all the challenges of predicting a rare phenomenon. At the same time, suicidal behaviors have multiple risk factors that individually have small statistical effects (2). Simulation in this repository shows that one-time or sparse measurements of suicide attempt predictors may severely limit power to detect those small effects. 

If a variable is measured more than once for one patient, intraclass correlation (ICC) can be calculated. High values of ICC mean that variable levels observed in multiple measurements coming from one patient (one class) are congruent, while low values mean that variable levels may vary considerably between measurements. 

ICCs of predictor variables used in suicide research are largely unknown because study designs that allow calculating them gained momentum only recently. In longitudinal research that spans months or years, predictor level at time point 1 is used to model suicide attempt risk at time point 2, and those time points are often a few months apart (or more). This simulation shows that if the predictor's ICC is low, it significantly limits the model's predictive performance because the predictor level at time point 1 can differ considerably from its level at time point 2. 

## References

1. 