---
title: Machine Learning Pipelines with Tidymodels and Targets
author: ~
date: '2020-07-26'
slug: machine-learning-pipelines-with-tidymodels-and-targets
tags:
    - R
images: ["/img/coffee-pipeline.png"]
output: hugodown::md_document
rmd_hash: 62823082669ef4f0

---

There aren't enough `tidymodels` examples on the Internet. Here's a simple machine learning model using the recent *coffee* Tidy Tuesday data set. The plot above gives the approach: I'll define some preprocessing and a model, optimise some hyperparameters, and fit and evaluate the result. And I'll piece all of the components together using `targets`, an experimental successor to the `drake` package that I love so much.

As usual, I don't care too much about the model itself. I'm more interested in the process.

Exploratory data analysis
=========================

I'll start with some token data visualisation. I almost always start exploring new data with the `visdat` package. It lets me see at a glance the data types, as well as any missing data:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>visdat</span>::<span class='nf'><a href='http://visdat.njtierney.com//reference/vis_dat.html'>vis_dat</a></span>(<span class='k'>coffee</span>)
</code></pre>
<img src="figs/visdat-1.png" width="700px" style="display: block; margin: auto;" />

</div>

I doubt very much I'll want to use all of these columns, especially since I only have 1339 rows of data. But some of the columns I do like the look of have missing values, and those will need to be dealt with.

I'll be looking at `cupper_points` as a measure of coffee quality, although I've seen some analyses on this data use `total_cup_points`. The `cupper_points` score ranges from 0 to 10, presumably with 10 being the best. I was curious which countries produce the best coffee, I made a ggplot that makes use of the `ggridges` package to produce density plots:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee</span> <span class='o'>%&gt;%</span> 
  <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='o'>!</span><span class='nf'><a href='https://rdrr.io/r/base/NA.html'>is.na</a></span>(<span class='k'>country_of_origin</span>)) <span class='o'>%&gt;%</span>
  <span class='nf'>inner_join</span>(
    <span class='k'>coffee</span> <span class='o'>%&gt;%</span>
      <span class='nf'>group_by</span>(<span class='k'>country_of_origin</span>) <span class='o'>%&gt;%</span> 
      <span class='nf'>summarise</span>(n = <span class='nf'>n</span>(), average_cupper_points = <span class='nf'><a href='https://rdrr.io/r/base/mean.html'>mean</a></span>(<span class='k'>cupper_points</span>)) <span class='o'>%&gt;%</span>
      <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='k'>n</span> <span class='o'>/</span> <span class='nf'><a href='https://rdrr.io/r/base/sum.html'>sum</a></span>(<span class='k'>n</span>) <span class='o'>&gt;</span> <span class='m'>0.01</span>),
    by = <span class='s'>"country_of_origin"</span>
  ) <span class='o'>%&gt;%</span> 
  <span class='nf'>ggplot</span>(<span class='nf'>aes</span>(
    x = <span class='k'>cupper_points</span>,
    y = <span class='nf'>fct_reorder</span>(<span class='k'>country_of_origin</span>, <span class='k'>average_cupper_points</span>),
    fill = <span class='k'>average_cupper_points</span>
  )) <span class='o'>+</span> 
  <span class='k'>ggridges</span>::<span class='nf'><a href='https://rdrr.io/pkg/ggridges/man/geom_density_ridges.html'>geom_density_ridges</a></span>() <span class='o'>+</span>
  <span class='nf'><a href='https://rdrr.io/r/graphics/plot.window.html'>xlim</a></span>(<span class='m'>5</span>, <span class='m'>10</span>) <span class='o'>+</span>
  <span class='nf'>scale_fill_gradient</span>(low = <span class='s'>"#A8805C"</span>, high = <span class='s'>"#5F3622"</span>) <span class='o'>+</span>
  <span class='nf'>ggtitle</span>(<span class='s'>"Coffee quality by country of origin"</span>) <span class='o'>+</span>
  <span class='nf'>xlab</span>(<span class='s'>"cupper points"</span>) <span class='o'>+</span>
  <span class='nf'>ylab</span>(<span class='kr'>NULL</span>) <span class='o'>+</span>
  <span class='nf'>theme_minimal</span>(base_size = <span class='m'>16</span>, base_family = <span class='s'>"Montserrat"</span>) <span class='o'>+</span>
  <span class='nf'>theme</span>(legend.position = <span class='s'>"none"</span>)
</code></pre>
<img src="figs/coffee-plot-1.png" width="700px" style="display: block; margin: auto;" />

</div>

Modelling
=========

It's time to make a model! First I'll generate an 80/20 train/test split:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/Random.html'>set.seed</a></span>(<span class='m'>123</span>)
<span class='k'>coffee_split</span> <span class='o'>&lt;-</span> <span class='nf'>initial_split</span>(<span class='k'>coffee</span>, prop = <span class='m'>0.8</span>)
<span class='k'>coffee_train</span> <span class='o'>&lt;-</span> <span class='nf'>training</span>(<span class='k'>coffee_split</span>)
<span class='k'>coffee_test</span> <span class='o'>&lt;-</span> <span class='nf'>testing</span>(<span class='k'>coffee_split</span>)</code></pre>

</div>

The split between test and train is sacred. I start a model by splitting out the test data, and then I forget that it exists until it's time to evaluate my model. If I introduce any information from `coffee_test` into `coffee_train` then I can't trust my model metrics, since I would have no way of knowing if my model is overfitting. This is called *data leakage*.

It is very easy to accidentally leak data from test to train. Suppose I have some missing values that I want to impute with the mean. If I impute using the mean of the entire data set, then that's data leakage. Suppose I scale and centre my numeric variables. I use the mean and variance of the entire data set, then that's data leakage.

The usual methods of manipulating data often aren't suitable for preprocessing modelling data. It's easy enough to centre and scale a variable with `mutate()`, but data manipulation for machine learning requires tools that respect the split between test and train. That's what `recipes` are for.

Preprocessing with recipes
--------------------------

In `tidymodels`, [preprocessing is done with recipes](/post/user-recipes-for-data-processing/). There's a particular language for preprocessing with `recipes`, and it follows a common (and cute) theme. A `recipe` abstractly defines how to manipulate the data. It is then `prep`ared on a training set, and can be used to `bake` new data.

Recipes require an understanding of which variables are predictors and which are outcomes (it would make no sense to preprocess the outcome of the test set). Traditionally in R this is done with a formula, like `cupper_points ~ flavour + aroma`, or `cupper_points ~ .` if everything as a predictor. Instead, I'm going to use the "role" approach that `recipes` takes to declare some variables as predictors and `cupper_points` as an outcome. The rest will be "support" variables, some of which will be used in imputation. I like this approach, since it means that I don't need to maintain a list of variables to be fed to the `fit` function. Instead, the `fit` function will only use the variables with the "predictor" role.

The recipe I'll use defines the steps below. Just a heads up: I'm not claiming that this is *good* preprocessing. I haven't even seen what the impact of this preprocessing is on the resulting model. I'm just using this as an example of some preprocessing steps.

1.  Sets the roles of every variable in the data. A variable can have more than one role, but here we'll call everything either "outcome", "predictor", or "support". `tidymodels` treats "outcome" and "predictor" variables specially, but otherwise any string can be a role.
2.  Convert all strings to factors. You read that right.
3.  Impute `country_of_origin`, and then `altitude_mean_meters` using k-nearest-neighbours with a handful of other variables.
4.  Convert all missing varieties to an "unknown" value.
5.  Collapse `country_of_origin`, `processing_method` and `variety` levels so that infrequently occurring values are collapsed to "other".
6.  Centre and scale all numeric variables.

[Many thanks to Julia Silge for helping me define this recipe](https://stackoverflow.com/questions/63008228/tidymodels-tune-grid-cant-subset-columns-that-dont-exist-when-not-using-for)!

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee_recipe</span> <span class='o'>&lt;-</span> <span class='nf'>recipe</span>(<span class='k'>coffee_train</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>update_role</span>(<span class='nf'><a href='https://tidyselect.r-lib.org/reference/everything.html'>everything</a></span>(), new_role = <span class='s'>"support"</span>) <span class='o'>%&gt;%</span> 
  <span class='nf'>update_role</span>(<span class='k'>cupper_points</span>, new_role = <span class='s'>"outcome"</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>update_role</span>(
    <span class='k'>variety</span>, <span class='k'>processing_method</span>, <span class='k'>country_of_origin</span>,
    <span class='k'>aroma</span>, <span class='k'>flavor</span>, <span class='k'>aftertaste</span>, <span class='k'>acidity</span>, <span class='k'>sweetness</span>, <span class='k'>altitude_mean_meters</span>,
    new_role = <span class='s'>"predictor"</span>
  ) <span class='o'>%&gt;%</span>
  <span class='nf'>step_string2factor</span>(<span class='nf'>all_nominal</span>(), <span class='o'>-</span><span class='nf'>all_outcomes</span>()) <span class='o'>%&gt;%</span>
  <span class='nf'>step_knnimpute</span>(<span class='k'>country_of_origin</span>,
                 impute_with = <span class='nf'>imp_vars</span>(
                 <span class='k'>in_country_partner</span>, <span class='k'>company</span>, <span class='k'>region</span>, <span class='k'>farm_name</span>, <span class='k'>certification_body</span>
                 )
  ) <span class='o'>%&gt;%</span>
  <span class='nf'>step_knnimpute</span>(<span class='k'>altitude_mean_meters</span>,
                 impute_with = <span class='nf'>imp_vars</span>(
                 <span class='k'>in_country_partner</span>, <span class='k'>company</span>, <span class='k'>region</span>, <span class='k'>farm_name</span>, <span class='k'>certification_body</span>,
                 <span class='k'>country_of_origin</span>
                 )
  ) <span class='o'>%&gt;%</span>
  <span class='nf'>step_unknown</span>(<span class='k'>variety</span>, <span class='k'>processing_method</span>, new_level = <span class='s'>"unknown"</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>step_other</span>(<span class='k'>country_of_origin</span>, threshold = <span class='m'>0.01</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>step_other</span>(<span class='k'>processing_method</span>, <span class='k'>variety</span>, threshold = <span class='m'>0.10</span>) <span class='o'>%&gt;%</span> 
  <span class='nf'>step_normalize</span>(<span class='nf'>all_numeric</span>(), <span class='o'>-</span><span class='nf'>all_outcomes</span>())
<span class='k'>coffee_recipe</span>
<span class='c'>#&gt; Data Recipe</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Inputs:</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt;       role #variables</span>
<span class='c'>#&gt;    outcome          1</span>
<span class='c'>#&gt;  predictor          9</span>
<span class='c'>#&gt;    support         33</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Operations:</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Factor variables from all_nominal(), -all_outcomes()</span>
<span class='c'>#&gt; K-nearest neighbor imputation for country_of_origin</span>
<span class='c'>#&gt; K-nearest neighbor imputation for altitude_mean_meters</span>
<span class='c'>#&gt; Unknown factor level assignment for variety, processing_method</span>
<span class='c'>#&gt; Collapsing factor levels for country_of_origin</span>
<span class='c'>#&gt; Collapsing factor levels for processing_method, variety</span>
<span class='c'>#&gt; Centering and scaling for all_numeric(), -all_outcomes()</span></code></pre>

</div>

I won't actually need to `prep` or `bake` anything here, since that's all handled for me behind the scenes in the `workflow` step below. But just to demonstrate, I'll briefly remember that the test data exists and bake it with this recipe. The baked test data below contains no missing `processing_method` values. It does, however, contain "unknown" and "Other".

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee_recipe</span> <span class='o'>%&gt;%</span> 
  <span class='nf'>prep</span>(<span class='k'>coffee_train</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>bake</span>(<span class='k'>coffee_test</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>count</span>(<span class='k'>processing_method</span>)
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 4 x 2</span></span>
<span class='c'>#&gt;   processing_method     n</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;fct&gt;</span><span>             </span><span style='color: #949494;font-style: italic;'>&lt;int&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> Natural / Dry        57</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> Washed / Wet        168</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> unknown              28</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> other                14</span></span></code></pre>

</div>

Model specification
-------------------

An issue with R's distributed package ecosystem is that the same variable can have multiple names across different packages. For example, `ranger` and `randomForest` are packages used to train random forests, but where `ranger` uses `num.trees` to define the number of trees in the forest, `randomForest` uses `ntree`. Under `tidymodels`, these names are standardised to `trees`. Moreover, the same standard name is used for other models where "number of trees" is a valid concept, such as boosted trees.

Note that I'm setting the hyperparameters with `tune()`, which means that I expect to fill these values in later. Think of `tune()` as a placeholder. Apart from `trees`, the other hyperparameter I'm looking at is `mtry`. When splitting a branch in a random forest, the algorithm doesn't have access to all of the variables. It's only provided with a certain number of randomly chosen variables, and it must select the best one to use to split the data. This number of random variables is `mtry`.

The "engine" here determines what will be used to fit the model. `tidymodels` wraps machine learning package, and it has no capacity to train a model by itself. I'm using the `ranger` package as the engine here, but I could also use the `randomForest` package.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee_model</span> <span class='o'>&lt;-</span> <span class='nf'>rand_forest</span>(
    trees = <span class='nf'>tune</span>(),
    mtry = <span class='nf'>tune</span>()
  ) <span class='o'>%&gt;%</span>
  <span class='nf'>set_engine</span>(<span class='s'>"ranger"</span>) <span class='o'>%&gt;%</span> 
  <span class='nf'>set_mode</span>(<span class='s'>"regression"</span>)
<span class='k'>coffee_model</span>
<span class='c'>#&gt; Random Forest Model Specification (regression)</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Main Arguments:</span>
<span class='c'>#&gt;   mtry = tune()</span>
<span class='c'>#&gt;   trees = tune()</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Computational engine: ranger</span></code></pre>

</div>

I haven't provided any data to the model specification. Just as in Python's `sklearn`, in `tidymodels` models are defined in a separate step to fitting. The above is just a *specification* for a model.

Workflows
---------

A `workflow` combines a preprocessing recipe and a model specification. Once I've introduced the recipe, all of the preprocessing will be handled for me.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee_workflow</span> <span class='o'>&lt;-</span> <span class='nf'>workflow</span>() <span class='o'>%&gt;%</span> 
  <span class='nf'>add_recipe</span>(<span class='k'>coffee_recipe</span>) <span class='o'>%&gt;%</span> 
  <span class='nf'>add_model</span>(<span class='k'>coffee_model</span>)
<span class='k'>coffee_workflow</span>
<span class='c'>#&gt; ══ Workflow ═════════════════════════════════════════════════════════════════════════════════════════════════</span>
<span class='c'>#&gt; <span style='font-style: italic;'>Preprocessor:</span><span> Recipe</span></span>
<span class='c'>#&gt; <span style='font-style: italic;'>Model:</span><span> rand_forest()</span></span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ── Preprocessor ─────────────────────────────────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt; 7 Recipe Steps</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ● step_string2factor()</span>
<span class='c'>#&gt; ● step_knnimpute()</span>
<span class='c'>#&gt; ● step_knnimpute()</span>
<span class='c'>#&gt; ● step_unknown()</span>
<span class='c'>#&gt; ● step_other()</span>
<span class='c'>#&gt; ● step_other()</span>
<span class='c'>#&gt; ● step_normalize()</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ── Model ────────────────────────────────────────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt; Random Forest Model Specification (regression)</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Main Arguments:</span>
<span class='c'>#&gt;   mtry = tune()</span>
<span class='c'>#&gt;   trees = tune()</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Computational engine: ranger</span></code></pre>

</div>

Hyperparameter tuning
---------------------

Earlier I set some hyperparameters with `tune()`, so I'll need to explore which values I can assign to them. I'll create a grid of values to explore. Most of these hyperparameters have sensible defaults, but I'll define my own to be explicit about what I'm doing.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee_grid</span> <span class='o'>&lt;-</span> <span class='nf'>expand_grid</span>(mtry = <span class='m'>3</span><span class='o'>:</span><span class='m'>5</span>, trees = <span class='nf'><a href='https://rdrr.io/r/base/seq.html'>seq</a></span>(<span class='m'>500</span>, <span class='m'>1500</span>, by = <span class='m'>200</span>))</code></pre>

</div>

I'll use cross-validation on `coffee_train` to evaluate the performance of each combination of hyperparameters.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/Random.html'>set.seed</a></span>(<span class='m'>123</span>)
<span class='k'>coffee_folds</span> <span class='o'>&lt;-</span> <span class='nf'>vfold_cv</span>(<span class='k'>coffee_train</span>, v = <span class='m'>5</span>)
<span class='k'>coffee_folds</span>
<span class='c'>#&gt; #  5-fold cross-validation </span>
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 5 x 2</span></span>
<span class='c'>#&gt;   splits            id   </span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;list&gt;</span><span>            </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> </span><span style='color: #949494;'>&lt;split [857/215]&gt;</span><span> Fold1</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> </span><span style='color: #949494;'>&lt;split [857/215]&gt;</span><span> Fold2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> </span><span style='color: #949494;'>&lt;split [858/214]&gt;</span><span> Fold3</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> </span><span style='color: #949494;'>&lt;split [858/214]&gt;</span><span> Fold4</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span> </span><span style='color: #949494;'>&lt;split [858/214]&gt;</span><span> Fold5</span></span></code></pre>

</div>

Here's where I search through the hyperparameter space. With 5 folds and 18 combinations of hyperparameters to explore, R has to train and evaluate 90 models. In general, this sort of tuning takes a while. I could speed this up with parallel processing, but I'm not sure it's worth the hassle for such a small data set.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee_grid_results</span> <span class='o'>&lt;-</span> <span class='k'>coffee_workflow</span> <span class='o'>%&gt;%</span> 
  <span class='nf'>tune_grid</span>(
    resamples = <span class='k'>coffee_folds</span>,
    grid = <span class='k'>coffee_grid</span>
  )</code></pre>

</div>

Now it's time to see how the models performed! I'll look at root mean squared error to evaluate this model:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>collect_metrics</span>(<span class='k'>coffee_grid_results</span>) <span class='o'>%&gt;%</span>
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='k'>.metric</span> <span class='o'>==</span> <span class='s'>"rmse"</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>arrange</span>(<span class='k'>mean</span>) <span class='o'>%&gt;%</span>
    <span class='nf'><a href='https://rdrr.io/r/utils/head.html'>head</a></span>() <span class='o'>%&gt;%</span> 
    <span class='k'>knitr</span>::<span class='nf'><a href='https://rdrr.io/pkg/knitr/man/kable.html'>kable</a></span>()
</code></pre>

|  mtry|  trees| .metric | .estimator |       mean|    n|   std\_err| .config |
|-----:|------:|:--------|:-----------|----------:|----:|----------:|:--------|
|     3|   1500| rmse    | standard   |  0.3127119|    5|  0.0565917| Model06 |
|     3|   1100| rmse    | standard   |  0.3129998|    5|  0.0563920| Model04 |
|     3|    500| rmse    | standard   |  0.3136543|    5|  0.0565772| Model01 |
|     3|    700| rmse    | standard   |  0.3137247|    5|  0.0565831| Model02 |
|     3|   1300| rmse    | standard   |  0.3137998|    5|  0.0564674| Model05 |
|     3|    900| rmse    | standard   |  0.3139521|    5|  0.0565038| Model03 |

</div>

`tidymodels` also comes with some nice auto-plotting functionality for model metrics:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>autoplot</span>(<span class='k'>coffee_grid_results</span>, metric = <span class='s'>"rmse"</span>)
</code></pre>
<img src="figs/coffee-grid-results-rmse-plot-1.png" width="700px" style="display: block; margin: auto;" />

</div>

The goal is to minimise RMSE. I can take a look at the hyperparameter combinations that optimise this value:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>show_best</span>(<span class='k'>coffee_grid_results</span>, metric = <span class='s'>"rmse"</span>) <span class='o'>%&gt;%</span> <span class='k'>knitr</span>::<span class='nf'><a href='https://rdrr.io/pkg/knitr/man/kable.html'>kable</a></span>()
</code></pre>

|  mtry|  trees| .metric | .estimator |       mean|    n|   std\_err| .config |
|-----:|------:|:--------|:-----------|----------:|----:|----------:|:--------|
|     3|   1500| rmse    | standard   |  0.3127119|    5|  0.0565917| Model06 |
|     3|   1100| rmse    | standard   |  0.3129998|    5|  0.0563920| Model04 |
|     3|    500| rmse    | standard   |  0.3136543|    5|  0.0565772| Model01 |
|     3|    700| rmse    | standard   |  0.3137247|    5|  0.0565831| Model02 |
|     3|   1300| rmse    | standard   |  0.3137998|    5|  0.0564674| Model05 |

</div>

The issue I have here is that 1500 trees is a lot[^1]. When I look at the plot above I can see that 500 trees does pretty well. It may not be the best, but it's one third as complex.

I think it's worth cutting back on accuracy a tiny bit if it means simplifying the model a lot. `tidymodels` contains a function that does just this. I'll ask for the combination of hyperparameters that minimises the number of trees in the random forest, while not being more than 5% away from the best combination overall:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>select_by_pct_loss</span>(<span class='k'>coffee_grid_results</span>, metric = <span class='s'>"rmse"</span>, limit = <span class='m'>5</span>, <span class='k'>trees</span>) <span class='o'>%&gt;%</span>
  <span class='k'>knitr</span>::<span class='nf'><a href='https://rdrr.io/pkg/knitr/man/kable.html'>kable</a></span>()
</code></pre>

|  mtry|  trees| .metric | .estimator |       mean|    n|   std\_err| .config |      .best|     .loss|
|-----:|------:|:--------|:-----------|----------:|----:|----------:|:--------|----------:|---------:|
|     5|    500| rmse    | standard   |  0.3172264|    5|  0.0549082| Model13 |  0.3127119|  1.443642|

</div>

Model fitting
-------------

I can't fit a model with undefined hyperparameters. I'll use the above combination to "finalise" the model. Every hyperparameter that I set to "tune" will be set to the result of `select_by_pct_loss`.

That's everything I need to fit a model. I have a preprocessing recipe, a model specification, and a nice set of hyperparameters. All that's left to call is `fit`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>fitted_coffee_model</span> <span class='o'>&lt;-</span> <span class='k'>coffee_workflow</span> <span class='o'>%&gt;%</span> 
  <span class='nf'>finalize_workflow</span>(
    <span class='nf'>select_by_pct_loss</span>(<span class='k'>coffee_grid_results</span>, metric = <span class='s'>"rmse"</span>, limit = <span class='m'>5</span>, <span class='k'>trees</span>)
  ) <span class='o'>%&gt;%</span> 
  <span class='nf'>fit</span>(<span class='k'>coffee_train</span>)</code></pre>

</div>

Model evaluation
----------------

Now that I have a model I can remember that my test set exists. I'll look at a handful of metrics to see how the model performs. `metrics_set(rmse, mae, rsq)` is a function that returns a function that compares the true and predicted values. It returns the root mean squared error, mean absolute error, and R squared value.

I'm using some possibly non-idiomatic R code below. `metric_set(rmse, mae, rsq)` returns a function, so I can immediately call it as a function. This leads to two sets of parameters in brackets right next to each other. There's nothing *wrong* with this, but I don't know if it's good practice:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>fitted_coffee_model</span> <span class='o'>%&gt;%</span>
  <span class='nf'><a href='https://rdrr.io/r/stats/predict.html'>predict</a></span>(<span class='k'>coffee_test</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>metric_set</span>(<span class='k'>rmse</span>, <span class='k'>mae</span>, <span class='k'>rsq</span>)(<span class='k'>coffee_test</span><span class='o'>$</span><span class='k'>cupper_points</span>, <span class='k'>.pred</span>)
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 3 x 3</span></span>
<span class='c'>#&gt;   .metric .estimator .estimate</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>   </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>          </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> rmse    standard       0.293</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> mae     standard       0.174</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> rsq     standard       0.506</span></span></code></pre>

</div>

Targets
=======

There are a lot of steps involved in fitting and evaluating this model, so it would help to have a way to orchestrate the whole process. [Normally I would use the `drake` package for this](/post/upgrade-your-workflow-with-drake/) but Will Landau, its creator and maintainer, has been working on [a spiritual successor called targets](https://github.com/wlandau/targets). This is an **experimental** package right now, but I thought I'd give it a go for this.

`targets` will look very familiar to users of `drake`. [Will has laid out some reasons for creating a separate package](https://wlandau.github.io/targets/articles/need.html). `drake` uses *plans*, which are R objects. `targets` takes a similar approach with its *pipelines*. However, `targets` requires that the pipeline be defined in a specific `_targets.R` file. This file can can also set up required functions and objects for the pipeline, and load necessary packages. The requirement is that it ends with a `targets` pipeline.

I've put all of the steps required to fit and evaluate this model into a `targets` pipeline. The recipe is lengthy, and likely to change often as I refine my preprocessing approach. It's best to create a function `define_coffee_recipe` and place it in a file somewhere in my project (probably the `R/` directory). I can then source it it within `_targets.R`. This way, I can change the preprocessing approach without changing the model pipeline. In a complicated project, it would be best to do this for most of the targets, especially the model definition and metrics.

A pipeline consists of a set of `tar_target`s. The first argument of each is a name for the target, and the second is the command that generates the target's output. Just as with `drake`, a pipieline should consist of pure functions: no side-effects, with each target defined only by its inputs and its output. This way, `targets` can automatically detect the dependencies of each target. A convenient consequence of this is that the order in which the targets are provided is irrelevant, as the package is able to work it out from the dependencies alone.

My `_targets.R` file with the pipeline is below. Note that the data retrieval step ("coffee") uses a "never" cue. Like `drake`, the `targets` package automatically works out when a step has been invalidated and needs to be rerun. The "never" cue tells `targets` to never run the "coffee" step unless the result isn't cached. I can do this because I'm confident that the TidyTuesday data will never change.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='https://wlandau.github.io/targets'>targets</a></span>)
<span class='nf'><a href='https://rdrr.io/r/base/source.html'>source</a></span>(<span class='s'>"R/define_coffee_recipe.R"</span>)

<span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_options.html'>tar_options</a></span>(packages = <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"tidyverse"</span>, <span class='s'>"tidymodels"</span>))

<span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_pipeline.html'>tar_pipeline</a></span>(
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>coffee</span>,
    <span class='k'>tidytuesdayR</span>::<span class='nf'><a href='https://rdrr.io/pkg/tidytuesdayR/man/tt_load.html'>tt_load</a></span>(<span class='m'>2020</span>, week = <span class='m'>28</span>)<span class='o'>$</span><span class='k'>coffee</span>,
    cue = <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_cue.html'>tar_cue</a></span>(<span class='s'>"never"</span>)
  ),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(<span class='k'>coffee_split</span>, <span class='nf'>initial_split</span>(<span class='k'>coffee</span>, prop = <span class='m'>0.8</span>)),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(<span class='k'>coffee_train</span>, <span class='nf'>training</span>(<span class='k'>coffee_split</span>)),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(<span class='k'>coffee_test</span>, <span class='nf'>testing</span>(<span class='k'>coffee_split</span>)),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(<span class='k'>coffee_recipe</span>, <span class='nf'>define_coffee_recipe</span>(<span class='k'>coffee_train</span>)),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>coffee_model</span>,
    <span class='nf'>rand_forest</span>(
      trees = <span class='nf'>tune</span>(),
      mtry = <span class='nf'>tune</span>()
    ) <span class='o'>%&gt;%</span> <span class='nf'>set_engine</span>(<span class='s'>"ranger"</span>) <span class='o'>%&gt;%</span> <span class='nf'>set_mode</span>(<span class='s'>"regression"</span>)
  ),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>coffee_workflow</span>,
    <span class='nf'>workflow</span>() <span class='o'>%&gt;%</span> <span class='nf'>add_recipe</span>(<span class='k'>coffee_recipe</span>) <span class='o'>%&gt;%</span> <span class='nf'>add_model</span>(<span class='k'>coffee_model</span>)
  ),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>coffee_grid</span>,
    <span class='nf'>expand_grid</span>(mtry = <span class='m'>3</span><span class='o'>:</span><span class='m'>5</span>, trees = <span class='nf'><a href='https://rdrr.io/r/base/seq.html'>seq</a></span>(<span class='m'>500</span>, <span class='m'>1500</span>, by = <span class='m'>200</span>))
  ),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>coffee_grid_results</span>,
    <span class='k'>coffee_workflow</span> <span class='o'>%&gt;%</span>
        <span class='nf'>tune_grid</span>(resamples = <span class='nf'>vfold_cv</span>(<span class='k'>coffee_train</span>, v = <span class='m'>5</span>), grid = <span class='k'>coffee_grid</span>)
  ),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>hyperparameters</span>,
    <span class='nf'>select_by_pct_loss</span>(<span class='k'>coffee_grid_results</span>, metric = <span class='s'>"rmse"</span>, limit = <span class='m'>5</span>, <span class='k'>trees</span>)
  ),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>fitted_coffee_model</span>,
    <span class='k'>coffee_workflow</span> <span class='o'>%&gt;%</span> <span class='nf'>finalize_workflow</span>(<span class='k'>hyperparameters</span>) <span class='o'>%&gt;%</span> <span class='nf'>fit</span>(<span class='k'>coffee_train</span>)
  ),
  <span class='nf'><a href='https://rdrr.io/pkg/targets/man/tar_target.html'>tar_target</a></span>(
    <span class='k'>metrics</span>,
    <span class='k'>fitted_coffee_model</span> <span class='o'>%&gt;%</span>
      <span class='nf'><a href='https://rdrr.io/r/stats/predict.html'>predict</a></span>(<span class='k'>coffee_test</span>) <span class='o'>%&gt;%</span>
      <span class='nf'>metric_set</span>(<span class='k'>rmse</span>, <span class='k'>mae</span>, <span class='k'>rsq</span>)(<span class='k'>coffee_test</span><span class='o'>$</span><span class='k'>cupper_points</span>, <span class='k'>.pred</span>)
  )
)</code></pre>

</div>

As long as this `_targets.R` file exists in the working directory the `targets` package will be able to pick it up and use it. The graph at the top of this page was generated with [`tar_visnetwork()`](https://rdrr.io/pkg/targets/man/tar_visnetwork.html) (no argument necessary). The pipeline can be run with [`tar_make()`](https://rdrr.io/pkg/targets/man/tar_make.html).

What I love about this orchestration is that I can see where the dependencies are used. I can be sure that the test data isn't used for preprocessing, or hyperparameter tuning. And it's just such a pretty plot!

------------------------------------------------------------------------

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>devtools</span>::<span class='nf'><a href='https://rdrr.io/pkg/sessioninfo/man/session_info.html'>session_info</a></span>()
<span class='c'>#&gt; ─ Session info ───────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  setting  value                       </span>
<span class='c'>#&gt;  version  R version 4.0.0 (2020-04-24)</span>
<span class='c'>#&gt;  os       Ubuntu 20.04 LTS            </span>
<span class='c'>#&gt;  system   x86_64, linux-gnu           </span>
<span class='c'>#&gt;  ui       X11                         </span>
<span class='c'>#&gt;  language en_AU:en                    </span>
<span class='c'>#&gt;  collate  en_AU.UTF-8                 </span>
<span class='c'>#&gt;  ctype    en_AU.UTF-8                 </span>
<span class='c'>#&gt;  tz       Australia/Melbourne         </span>
<span class='c'>#&gt;  date     2020-07-27                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib source                            </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports     1.1.8      2020-06-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  blob          1.2.1      2020-01-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  broom       * 0.7.0      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cellranger    1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  class         7.3-17     2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  codetools     0.2-16     2018-12-24 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  colorspace    1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  data.table    1.13.0     2020-07-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DBI           1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dbplyr        1.4.4      2020-05-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dials       * 0.0.8      2020-07-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DiceDesign    1.8-1      2019-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-07-25 [1] Github (r-lib/downlit@ed969d0)    </span>
<span class='c'>#&gt;  dplyr       * 1.0.0      2020-05-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  farver        2.0.3      2020-01-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forcats     * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  foreach       1.5.0      2020-03-30 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.4.2      2020-06-30 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  furrr         0.1.0      2018-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  future        1.17.0     2020-04-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics      0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggplot2     * 3.3.2.9000 2020-07-10 [1] Github (tidyverse/ggplot2@a11e098)</span>
<span class='c'>#&gt;  ggridges      0.5.2      2020-01-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  globals       0.12.5     2019-12-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gower         0.2.2      2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  GPfit         1.0-8      2019-02-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gtable        0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hardhat       0.1.4      2020-07-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  haven         2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  highr         0.8        2019-03-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httr          1.4.2      2020-07-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-07-25 [1] Github (r-lib/hugodown@3980496)   </span>
<span class='c'>#&gt;  igraph        1.2.5      2020-03-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  infer       * 0.5.3      2020-07-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ipred         0.9-9      2019-04-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  iterators     1.0.12     2019-07-26 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  jsonlite      1.7.0      2020-06-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr         1.29       2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  labeling      0.3        2014-08-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice       0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lava          1.6.7      2020-03-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lhs           1.0.2      2020-04-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  listenv       0.8.0      2019-12-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lubridate     1.7.8      2020-04-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  MASS          7.3-51.6   2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Matrix        1.2-18     2019-11-27 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  modeldata   * 0.0.2      2020-06-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  modelr        0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  munsell       0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  nnet          7.3-14     2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  parsnip     * 0.1.2      2020-07-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pillar        1.4.6      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild      1.0.8      2020-05-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.1.0      2020-05-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  plyr          1.8.6      2020-03-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pROC          1.16.2     2020-03-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.3      2020-07-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prodlim       2019.11.13 2019-11-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr       * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ranger        0.12.1     2020-01-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.5      2020-07-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr       * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readxl        1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  recipes     * 0.1.13     2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reprex        0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.7      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.3.3      2020-07-25 [1] Github (rstudio/rmarkdown@204aa41)</span>
<span class='c'>#&gt;  rpart         4.1-15     2019-04-12 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rsample     * 0.0.7      2020-06-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rstudioapi    0.11       2020-02-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rvest         0.3.5      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  scales      * 1.1.1      2020-05-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr     * 1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  survival      3.1-12     2020-04-10 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  targets     * 0.0.0.9000 2020-07-25 [1] Github (wlandau/targets@1455610)  </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble      * 3.0.3      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidymodels  * 0.1.1      2020-07-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyr       * 1.1.0      2020-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect    1.1.0      2020-05-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyverse   * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  timeDate      3043.102   2018-02-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tune        * 0.1.1      2020-07-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  utf8          1.1.4      2018-05-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs         0.3.2      2020-07-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  visdat        0.5.3      2019-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  workflows   * 0.1.2      2020-07-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.16       2020-07-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xml2          1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yardstick   * 0.0.7      2020-07-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

[^1]: Adding more trees to a random forest doesn't make the model overfit, or have any other detriment on model performance. But additional trees do carry a computational cost, in both model training and prediction. It's good to keep the number as low as possible without harming model performance.

