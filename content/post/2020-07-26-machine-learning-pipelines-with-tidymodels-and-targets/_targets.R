library(targets)
source("R/define_coffee_recipe.R")

tar_options(packages = c("tidyverse", "tidymodels"))
    
tar_pipeline(
  tar_target(
    coffee,
    tidytuesdayR::tt_load(2020, week = 28)$coffee,
    cue = tar_cue("never")
  ),
  tar_target(coffee_split, initial_split(coffee, prop = 0.8)),
  tar_target(coffee_train, training(coffee_split)),
  tar_target(coffee_test, testing(coffee_split)),
  tar_target(coffee_recipe, define_coffee_recipe(coffee_train)),
  tar_target(
    coffee_model,
    rand_forest(
      trees = tune(),
      mtry = tune()
    ) %>% set_engine("ranger") %>% set_mode("regression")
  ),
  tar_target(
    coffee_workflow,
    workflow() %>% add_recipe(coffee_recipe) %>% add_model(coffee_model)
  ),
  tar_target(
    coffee_grid,
    expand_grid(mtry = 3:5, trees = seq(500, 1500, by = 200))
  ),
  tar_target(
    coffee_grid_results,
    coffee_workflow %>%
        tune_grid(resamples = vfold_cv(coffee_train, v = 5), grid = coffee_grid)
  ),
  tar_target(
    hyperparameters,
    select_by_pct_loss(coffee_grid_results, metric = "rmse", limit = 5, trees)
  ),
  tar_target(
    fitted_coffee_model,
    coffee_workflow %>% finalize_workflow(hyperparameters) %>% fit(coffee_train)
  ),
  tar_target(
    metrics,
    fitted_coffee_model %>%
      predict(coffee_test) %>%
      metric_set(rmse, mae, rsq)(coffee_test$cupper_points, .pred)
  )
)