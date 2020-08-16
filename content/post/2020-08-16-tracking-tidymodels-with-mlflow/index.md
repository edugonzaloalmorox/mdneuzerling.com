---
title: Tracking Tidymodels with MLflow
author: ~
date: '2020-08-16'
slug: tracking-tidymodels-with-mlflow
tags:
    - R
images: ["/img/mlflow-tracking.png"]
output: hugodown::md_document
rmd_hash: 006bffda390fe1c4

---

After I posted [my efforts to use MLflow to serve a model with R](/post/deploying-r-models-with-mlflow-and-docker/), I was worried that people may think I don't *like* MLflow. I want to declare this: MLflow is awesome. I'll showcase its model tracking features, and how to integrate them into a `tidymodels` model.

The Tracking component of MLflow can be used to record parameters, metrics and artifacts every time a model is trained. All of this information is presented in a very nice user interface. I'll also finish off here by demonstrating how to serve a model created with Tidymodels, which I find much easier than serving a model created with arbitrary code.

Prepare a model
---------------

I'll prepare a model using the recent TidyTuesday coffee data. This is the same process I followed in [my last post](/post/machine-learning-pipelines-with-tidymodels-and-targets/), except I'll stop short of fitting and evaluating the model so I can track those steps with MLflow.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/invisible.html'>invisible</a></span>(<span class='k'>tidytuesdayR</span>::<span class='nf'><a href='https://rdrr.io/pkg/tidytuesdayR/man/tt_load.html'>tt_load</a></span>(<span class='m'>2020</span>, week = <span class='m'>28</span>)<span class='o'>$</span><span class='k'>coffee</span>)
<span class='c'>#&gt; </span>
<span class='c'>#&gt;   Downloading file 1 of 1: `coffee_ratings.csv`</span>
<span class='k'>coffee_split</span> <span class='o'>&lt;-</span> <span class='nf'>initial_split</span>(<span class='k'>coffee</span>, prop = <span class='m'>0.8</span>)
<span class='k'>coffee_train</span> <span class='o'>&lt;-</span> <span class='nf'>training</span>(<span class='k'>coffee_split</span>)
<span class='k'>coffee_test</span> <span class='o'>&lt;-</span> <span class='nf'>testing</span>(<span class='k'>coffee_split</span>)
<span class='k'>coffee_recipe</span> <span class='o'>&lt;-</span> <span class='nf'>recipe</span>(<span class='k'>coffee_train</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>update_role</span>(<span class='nf'>everything</span>(), new_role = <span class='s'>"support"</span>) <span class='o'>%&gt;%</span> 
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
  <span class='nf'>step_unknown</span>(<span class='k'>variety</span>, <span class='k'>processing_method</span>, new_level = <span class='s'>"Unknown"</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>step_other</span>(<span class='k'>country_of_origin</span>, threshold = <span class='m'>0.01</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>step_other</span>(<span class='k'>processing_method</span>, threshold = <span class='m'>0.10</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>step_other</span>(<span class='k'>variety</span>, threshold = <span class='m'>0.10</span>) <span class='o'>%&gt;%</span> 
  <span class='nf'>step_normalize</span>(<span class='nf'>all_numeric</span>(), <span class='o'>-</span><span class='nf'>all_outcomes</span>())
<span class='k'>coffee_model</span> <span class='o'>&lt;-</span> <span class='nf'>rand_forest</span>(trees = <span class='nf'>tune</span>(), mtry = <span class='nf'>tune</span>()) <span class='o'>%&gt;%</span>
  <span class='nf'>set_engine</span>(<span class='s'>"ranger"</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>set_mode</span>(<span class='s'>"regression"</span>)
<span class='k'>coffee_workflow</span> <span class='o'>&lt;-</span> <span class='k'>workflows</span>::<span class='nf'><a href='https://workflows.tidymodels.org//reference/workflow.html'>workflow</a></span>() <span class='o'>%&gt;%</span>
  <span class='nf'>add_recipe</span>(<span class='k'>coffee_recipe</span>) <span class='o'>%&gt;%</span>
  <span class='nf'>add_model</span>(<span class='k'>coffee_model</span>)
<span class='k'>coffee_grid</span> <span class='o'>&lt;-</span> <span class='nf'>expand_grid</span>(mtry = <span class='m'>3</span><span class='o'>:</span><span class='m'>5</span>, trees = <span class='nf'><a href='https://rdrr.io/r/base/seq.html'>seq</a></span>(<span class='m'>500</span>, <span class='m'>1500</span>, by = <span class='m'>200</span>))
<span class='k'>coffee_grid_results</span> <span class='o'>&lt;-</span> <span class='k'>coffee_workflow</span> <span class='o'>%&gt;%</span>
  <span class='nf'>tune_grid</span>(<span class='k'>resamples</span> <span class='o'>&lt;-</span> <span class='nf'>vfold_cv</span>(<span class='k'>coffee_train</span>, v = <span class='m'>5</span>), grid = <span class='k'>coffee_grid</span>)
<span class='k'>hyperparameters</span> <span class='o'>&lt;-</span> <span class='k'>coffee_grid_results</span> <span class='o'>%&gt;%</span> 
  <span class='nf'>select_by_pct_loss</span>(metric = <span class='s'>"rmse"</span>, limit = <span class='m'>5</span>, <span class='k'>trees</span>)</code></pre>

</div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>coffee_workflow</span>
<span class='c'>#&gt; ══ Workflow ════════════════════════════════════════════════════════════════════════════════════════════════════════════</span>
<span class='c'>#&gt; <span style='font-style: italic;'>Preprocessor:</span><span> Recipe</span></span>
<span class='c'>#&gt; <span style='font-style: italic;'>Model:</span><span> rand_forest()</span></span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ── Preprocessor ────────────────────────────────────────────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt; 8 Recipe Steps</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ● step_string2factor()</span>
<span class='c'>#&gt; ● step_knnimpute()</span>
<span class='c'>#&gt; ● step_knnimpute()</span>
<span class='c'>#&gt; ● step_unknown()</span>
<span class='c'>#&gt; ● step_other()</span>
<span class='c'>#&gt; ● step_other()</span>
<span class='c'>#&gt; ● step_other()</span>
<span class='c'>#&gt; ● step_normalize()</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ── Model ───────────────────────────────────────────────────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt; Random Forest Model Specification (regression)</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Main Arguments:</span>
<span class='c'>#&gt;   mtry = tune()</span>
<span class='c'>#&gt;   trees = tune()</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Computational engine: ranger</span></code></pre>

</div>

Automatic tracking with workflows
=================================

MLflow tracking is organised around *experiments* and *runs*. Broadly speaking, an experiment is a *project*, whereas a run is a process in which a model is trained and evaluated. But these categories could be repurposed for anything[^1].

In each run the user can record *parameters* and *metrics*. Parameters and metrics are both arbitrary key-value pairs that could be used for anything. In my coffee example, I might have parameters `trees: 500` and `mtry: 3`. My metric might be `mae: 0.2`. I would log this information with [`mlflow_log_param("trees", 500)`](https://rdrr.io/pkg/mlflow/man/mlflow_log_param.html) or [`mlflow_log_metric("mae", 0.2)`](https://rdrr.io/pkg/mlflow/man/mlflow_log_metric.html). That's all I need to do, and MLflow takes care of the rest.

I'll be storing all of this information locally, with MLflow recording information in the `mlruns` directory in my working directory. Alternatively, [I could host my tracking information remotely, for example in a database](https://www.mlflow.org/docs/latest/tracking.html#where-runs-are-recorded).

Certain kinds of Python model *flavours*, such as Tensorflow, have *autotracking* in which parameters and metrics are automatically recorded. I'll try and implement a rough version of this for a Tidymodels `workflow`. I'm aiming for functions here that let me record parameters and metrics for any type of model implemented through as a Tidymodels `workflow`, so that I can change from a random forest to a linear model without adjusting my MLflow code.

I'll start with a function for logging model hyperparameters as MLflow parameters. This function will only log hyperparameters set by the user, since the default values have a `NULL` expression, but I think that this approach makes sense. It also passes on the input workflow unmodified, so it's pipe-friendly:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>log_workflow_parameters</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>workflow</span>) {
  <span class='c'># Would help to have a check here: has this workflow been finalised?</span>
  <span class='c'># It may be sufficient to check that the arg quosures carry no environments.</span>
  <span class='k'>spec</span> <span class='o'>&lt;-</span> <span class='k'>workflows</span>::<span class='nf'><a href='https://workflows.tidymodels.org//reference/workflow-extractors.html'>pull_workflow_spec</a></span>(<span class='k'>workflow</span>)
  <span class='k'>parameter_names</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>spec</span><span class='o'>$</span><span class='k'>args</span>)
  <span class='k'>parameter_values</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/lapply.html'>lapply</a></span>(<span class='k'>spec</span><span class='o'>$</span><span class='k'>args</span>, <span class='k'>rlang</span>::<span class='k'><a href='https://rlang.r-lib.org/reference/set_expr.html'>get_expr</a></span>)
  <span class='kr'>for</span> (<span class='k'>i</span> <span class='kr'>in</span> <span class='nf'><a href='https://rdrr.io/r/base/seq.html'>seq_along</a></span>(<span class='k'>spec</span><span class='o'>$</span><span class='k'>args</span>)) {
    <span class='k'>parameter_name</span> <span class='o'>&lt;-</span> <span class='k'>parameter_names</span>[[<span class='k'>i</span>]]
    <span class='k'>parameter_value</span> <span class='o'>&lt;-</span> <span class='k'>parameter_values</span>[[<span class='k'>i</span>]]
    <span class='kr'>if</span> (<span class='o'>!</span><span class='nf'><a href='https://rdrr.io/r/base/NULL.html'>is.null</a></span>(<span class='k'>parameter_value</span>)) {
      <span class='nf'><a href='https://rdrr.io/pkg/mlflow/man/mlflow_log_param.html'>mlflow_log_param</a></span>(<span class='k'>parameter_name</span>, <span class='k'>parameter_value</span>)
    }
  }
  <span class='k'>workflow</span>
}</code></pre>

</div>

Now I'll do the same for metrics. The input to this function will be a metrics tibble produced by the `yardstick` package, which is a component of `tidymodels`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>log_metrics</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>metrics</span>, <span class='k'>estimator</span> = <span class='s'>"standard"</span>) {
  <span class='k'>metrics</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='k'>.estimator</span> <span class='o'>==</span> <span class='k'>estimator</span>) <span class='o'>%&gt;%</span> <span class='nf'>pmap</span>(
    <span class='nf'>function</span>(<span class='k'>.metric</span>, <span class='k'>.estimator</span>, <span class='k'>.estimate</span>) {
      <span class='nf'><a href='https://rdrr.io/pkg/mlflow/man/mlflow_log_metric.html'>mlflow_log_metric</a></span>(<span class='k'>.metric</span>, <span class='k'>.estimate</span>)  
    }
  )
  <span class='k'>metrics</span>
}</code></pre>

</div>

Packaging workflows is pretty easy
----------------------------------

There's one last component I need to make this work. Apart from parameters and metrics, I can also store *artifacts* with each run. These are usually models, but could be anything. MLflow supports exporting models with the [`carrier::crate`](https://rdrr.io/pkg/carrier/man/crate.html) function. [This is a tricky function to use](/post/deploying-r-models-with-mlflow-and-docker/), since the user must comprehensively list their dependencies. For a `workflow` with a `recipe`, it's a lot easier. All of the preprocessing is contained within the recipe, and the fitted workflow object contains this.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'># I haven't yet defined fitted_coffee_model, so I won't run this</span>
<span class='k'>crated_model</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>x</span>) <span class='k'>workflows</span>:::<span class='nf'><a href='https://workflows.tidymodels.org//reference/predict-workflow.html'>predict.workflow</a></span>(<span class='k'>fitted_coffee_model</span>, <span class='k'>x</span>),
  fitted_coffee_model = <span class='k'>fitted_coffee_model</span>
)</code></pre>

</div>

MLflow tracks *artifacts* along with parameters and metrics. These are any files associated with the run, including models. I think the `mlflow_log_model` function should be used here, but it doesn't work for me. Instead I save the crated model with `mlflow_save_model` and log it with `mlflow_log_artifact`.

Tracking a model training run with MLflow
-----------------------------------------

I'll set my experiment as `coffee`. I only need to do this once per session:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/pkg/mlflow/man/mlflow_set_experiment.html'>mlflow_set_experiment</a></span>(experiment_name = <span class='s'>"coffee"</span>)</code></pre>

</div>

To actually *do* an MLflow run, I wrap my model training and evaluation code in a [`with(mlflow_start_run(), ...)`](https://rdrr.io/r/base/with.html) block. I insert my logging functions into my training code:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/with.html'>with</a></span>(<span class='nf'><a href='https://rdrr.io/pkg/mlflow/man/mlflow_start_run.html'>mlflow_start_run</a></span>(), {
  <span class='k'>fitted_coffee_model</span> <span class='o'>&lt;-</span> <span class='k'>coffee_workflow</span> <span class='o'>%&gt;%</span>
    <span class='nf'>finalize_workflow</span>(<span class='k'>hyperparameters</span>) <span class='o'>%&gt;%</span>
    <span class='nf'>log_workflow_parameters</span>() <span class='o'>%&gt;%</span>  
    <span class='nf'>fit</span>(<span class='k'>coffee_train</span>)
  <span class='k'>metrics</span> <span class='o'>&lt;-</span> <span class='k'>fitted_coffee_model</span> <span class='o'>%&gt;%</span>
    <span class='nf'><a href='https://rdrr.io/r/stats/predict.html'>predict</a></span>(<span class='k'>coffee_test</span>) <span class='o'>%&gt;%</span>
    <span class='nf'>metric_set</span>(<span class='k'>rmse</span>, <span class='k'>mae</span>, <span class='k'>rsq</span>)(<span class='k'>coffee_test</span><span class='o'>$</span><span class='k'>cupper_points</span>, <span class='k'>.pred</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>log_metrics</span>()
  <span class='k'>crated_model</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
    <span class='nf'>function</span>(<span class='k'>x</span>) <span class='k'>workflows</span>:::<span class='nf'><a href='https://workflows.tidymodels.org//reference/predict-workflow.html'>predict.workflow</a></span>(<span class='k'>fitted_coffee_model</span>, <span class='k'>x</span>),
    fitted_coffee_model = <span class='k'>fitted_coffee_model</span>
  )
  <span class='nf'><a href='https://rdrr.io/pkg/mlflow/man/mlflow_save_model.html'>mlflow_save_model</a></span>(<span class='k'>crated_model</span>, <span class='k'>here</span>::<span class='nf'><a href='https://rdrr.io/pkg/here/man/here.html'>here</a></span>(<span class='s'>"models"</span>))
  <span class='nf'><a href='https://rdrr.io/pkg/mlflow/man/mlflow_log_artifact.html'>mlflow_log_artifact</a></span>(<span class='k'>here</span>::<span class='nf'><a href='https://rdrr.io/pkg/here/man/here.html'>here</a></span>(<span class='s'>"models"</span>, <span class='s'>"crate.bin"</span>))
})
<span class='c'>#&gt; <span style='color: #BB0000;'>2020/08/17 09:09:28 INFO mlflow.store.artifact.cli: Logged artifact from local file /home/mdneuzerling/mdneuzerling.com/models/crate.bin to artifact_path=None</span></span>
<span class='c'><span style='color: #BB0000;'>#&gt; </span></span>
<span class='c'>#&gt; Root URI: /home/mdneuzerling/Documents/coffee/mlruns/1/d2bdcbdf3e9849598b393951fa69214c/artifacts</span></code></pre>

</div>

I can see all the run information, stored as plain text, appearing in my `mlruns` directory now:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>fs</span>::<span class='nf'><a href='http://fs.r-lib.org/reference/dir_tree.html'>dir_tree</a></span>(<span class='s'>"mlruns/1/f26b040f80244b00882d2925ebdc8396/"</span>)
<span class='c'>#&gt; <span style='color: #0000BB;font-weight: bold;'>mlruns/1/f26b040f80244b00882d2925ebdc8396/</span></span>
<span class='c'>#&gt; ├── <span style='color: #0000BB;font-weight: bold;'>artifacts</span></span>
<span class='c'>#&gt; │   └── crate.bin</span>
<span class='c'>#&gt; ├── meta.yaml</span>
<span class='c'>#&gt; ├── <span style='color: #0000BB;font-weight: bold;'>metrics</span></span>
<span class='c'>#&gt; │   ├── mae</span>
<span class='c'>#&gt; │   ├── rmse</span>
<span class='c'>#&gt; │   └── rsq</span>
<span class='c'>#&gt; ├── <span style='color: #0000BB;font-weight: bold;'>params</span></span>
<span class='c'>#&gt; │   ├── mtry</span>
<span class='c'>#&gt; │   └── trees</span>
<span class='c'>#&gt; └── <span style='color: #0000BB;font-weight: bold;'>tags</span></span>
<span class='c'>#&gt;     ├── mlflow.source.name</span>
<span class='c'>#&gt;     ├── mlflow.source.type</span>
<span class='c'>#&gt;     └── mlflow.user</span></code></pre>

</div>

I have a quibble here: I create an experiment with a name, but MLflow identifies experiments with an integer ID. It would be great if I could write [`with(mlflow_start_run(experiment_name = "coffee"), ...)`](https://rdrr.io/r/base/with.html), but only the `experiment_id` is supported. It's a minor point, but I'm not a fan of having that separate `mlflow_set_experiment` function there because it's a state that I have to manage in a functional language. The other issue here is that while my collaborators and I might all be using the same `experiment_name`, we don't know that we'll be on the same `experiment_id`.

Viewing runs with the MLflow UI
-------------------------------

MLflow comes with a gorgeous user interface for exploring previous model runs. I can run it with `mlflow_ui` and view it in my browser:

![](mlflow-ui.png)

A word of warning: the model hyperparameters in this UI are placed directly next to the model metrics. The dashboard makes it look like I should be selecting the hyperparameters which reduce my error metrics. I can't use the same test data to select my hyperparameters *and* evaluate my model, because this leaks information from the test set to the model. But the UI places the hyperparameters next to the metrics, making it look as though I should be selecting the hyperparameters with the best metrics.

This isn't a flaw of MLflow, though. One thing I could do here to make the data leakage trap easier to avoid is to log the "cross-validation RMSE" that was used to select the hyperparameters. If I include this is a column before the other metrics, it makes it clear what I used to select those `trees` and `mtry` values.

What I really like about this use of MLflow is that if there's an error in my model training run, MLflow will pick that up and record what it can, and label the run as an error in the UI:

![](mlflow-ui-with-errors.png)

Serving coffee
--------------

MLflow Models is the MLflow component used for serving exported models as APIs. I can serve my coffee model that I exported earlier with [`mlflow_rfunc_serve("models")`](https://rdrr.io/pkg/mlflow/man/mlflow_rfunc_serve.html). Since I'm overwriting this directory with each run (before I log the artifact with the run), this will be the last model to have been exported. This command will open up a Swagger UI, so I don't have to mess around with piecing together a HTTP request.

To test this, I can try to predict the results of a random data point in the test set. Note the `na = "string"` argument here, since missing values will be incorrectly represented without it:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>coffee_test %>% select(-cupper_points) %>% sample_n(1) %>% jsonlite::toJSON(na = "string")`
</code></pre>

</div>

![](mlflow-prediction.png)

It seems as though this method only serves one prediction at a time, even if multiple rows are provided.

I could also have served this model through the command line with `mlflow models serve -m models/`.

`tidymodels` works really well with MLflow
------------------------------------------

`tidymodels` presents an excellent opportunity to make life a bit easier for R users who want to take advantage of MLflow.

MLflow exports models through patterns known as *flavours*. [There are many flavour available for Python](https://www.mlflow.org/docs/latest/models.html#built-in-model-flavors), but only `crate` and `keras` for R. `crate` does have the advantage of supporting arbitrary R code, however.

A `tidymodels` flavour for workflows/parsnip models could be implemented through the `crate` flavour, as I've done above, or separately. This isn't as tricky as exporting arbitrary R code, since all of the preprocessing is done through the `recipes` package.

The `tidymodels` framework also opens up the possibility of autologging. I've implemented some functions above that accomplish this, but they're a little rough. With a bit of polish, users could take advantage of MLflow with very little effort.

------------------------------------------------------------------------

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>devtools</span>::<span class='nf'><a href='https://rdrr.io/pkg/sessioninfo/man/session_info.html'>session_info</a></span>()
<span class='c'>#&gt; ─ Session info ───────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  setting  value                       </span>
<span class='c'>#&gt;  version  R version 4.0.0 (2020-04-24)</span>
<span class='c'>#&gt;  os       Ubuntu 20.04.1 LTS          </span>
<span class='c'>#&gt;  system   x86_64, linux-gnu           </span>
<span class='c'>#&gt;  ui       X11                         </span>
<span class='c'>#&gt;  language en_AU:en                    </span>
<span class='c'>#&gt;  collate  en_AU.UTF-8                 </span>
<span class='c'>#&gt;  ctype    en_AU.UTF-8                 </span>
<span class='c'>#&gt;  tz       Australia/Melbourne         </span>
<span class='c'>#&gt;  date     2020-08-17                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib source                            </span>
<span class='c'>#&gt;  askpass       1.1        2019-01-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports     1.1.8      2020-06-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  base64enc     0.1-3      2015-07-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  blob          1.2.1      2020-01-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  broom       * 0.7.0      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  carrier       0.1.0      2018-10-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cellranger    1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  class         7.3-17     2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  codetools     0.2-16     2018-12-24 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  colorspace    1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  curl          4.3        2019-12-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DBI           1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dbplyr        1.4.4      2020-05-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dials       * 0.0.8      2020-07-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DiceDesign    1.8-1      2019-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-07-25 [1] Github (r-lib/downlit@ed969d0)    </span>
<span class='c'>#&gt;  dplyr       * 1.0.1      2020-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forcats     * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  foreach       1.5.0      2020-03-30 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forge         0.2.0      2019-02-26 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.5.0      2020-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  furrr         0.1.0      2018-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  future        1.17.0     2020-04-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics      0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggplot2     * 3.3.2.9000 2020-08-07 [1] Github (tidyverse/ggplot2@6d91349)</span>
<span class='c'>#&gt;  git2r         0.27.1     2020-05-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  globals       0.12.5     2019-12-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gower         0.2.2      2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  GPfit         1.0-8      2019-02-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gtable        0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hardhat       0.1.4      2020-07-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  haven         2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  here          0.1        2017-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httpuv        1.5.2      2019-09-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httr          1.4.2      2020-07-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-08-13 [1] Github (r-lib/hugodown@2af491d)   </span>
<span class='c'>#&gt;  infer       * 0.5.3      2020-07-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ini           0.3.1      2018-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ipred         0.9-9      2019-04-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  iterators     1.0.12     2019-07-26 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  jsonlite      1.7.0      2020-06-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr         1.29       2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  later         1.1.0.1    2020-06-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice       0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lava          1.6.7      2020-03-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lhs           1.0.2      2020-04-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  listenv       0.8.0      2019-12-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lubridate     1.7.9      2020-06-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  MASS          7.3-51.6   2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Matrix        1.2-18     2019-11-27 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  mlflow      * 1.10.0     2020-07-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  modeldata   * 0.0.2      2020-06-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  modelr        0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  munsell       0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  nnet          7.3-14     2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  openssl       1.4.2      2020-06-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  parsnip     * 0.1.2      2020-07-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pillar        1.4.6      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild      1.1.0      2020-07-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.1.0      2020-05-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  plyr          1.8.6      2020-03-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pROC          1.16.2     2020-03-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.3      2020-07-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prodlim       2019.11.13 2019-11-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  promises      1.1.1      2020-06-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.4      2020-08-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr       * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ranger        0.12.1     2020-01-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.5      2020-07-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr       * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readxl        1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  recipes     * 0.1.13     2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reprex        0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reticulate    1.16       2020-05-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.7      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.3.3      2020-08-13 [1] Github (rstudio/rmarkdown@204aa41)</span>
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
<span class='c'>#&gt;  swagger       3.9.2      2018-03-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble      * 3.0.3      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidymodels  * 0.1.1      2020-07-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyr       * 1.1.1      2020-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect    1.1.0      2020-05-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyverse   * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  timeDate      3043.102   2018-02-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tune        * 0.1.1      2020-07-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs         0.3.2      2020-07-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  workflows   * 0.1.2      2020-07-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.16       2020-07-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xml2          1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yardstick   * 0.0.7      2020-07-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  zeallot       0.1.0      2018-01-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

[^1]: Here's an idea: use MLflow to track reports! Every report is an experiment, and every production of a report is a run.

