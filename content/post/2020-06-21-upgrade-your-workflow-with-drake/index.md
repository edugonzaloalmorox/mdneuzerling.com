---
title: Upgrade your workflow with drake
author: ~
date: '2020-06-21'
slug: upgrade-your-workflow-with-drake
tags:
    - R
images: ["/img/drake-model-execution-plan.png"]
featuredalt: "A drake model execution plan"
output: hugodown::md_document
rmd_hash: fa9d87177a635cb5

---

Drake is my new favourite R package.

Drake is a tool for orchestrating complicated workflows. You piece together a plan based on some high-level, abstract functions. These functions should be *pure* --- they need to be defined by their inputs only, not relying on any predefined variables that aren't in the function signature. Then, drake will take the steps in that plan and work out how to run it. Here's how I've defined the plan above:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/drake_plan.html'>drake_plan</a></span>(
  new_data = <span class='nf'>new_data_to_be_scored</span>(),
  tfidf = <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/read_rds.html'>read_rds</a></span>(<span class='nf'>file_in</span>(<span class='s'>"artefacts/tfidf.rds"</span>)),
  vectoriser = <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/read_rds.html'>read_rds</a></span>(<span class='nf'>file_in</span>(<span class='s'>"artefacts/vectoriser.rds"</span>)),
  review_rf = <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/read_rds.html'>read_rds</a></span>(<span class='nf'>file_in</span>(<span class='s'>"artefacts/review_rf.rds"</span>)),
  predictions = <span class='nf'>sentiment</span>(<span class='k'>new_data</span><span class='o'>$</span><span class='k'>review</span>,
                          random_forest = <span class='k'>review_rf</span>,
                          vectoriser = <span class='k'>vectoriser</span>,
                          tfidf = <span class='k'>tfidf</span>),
  validation = <span class='nf'>validate_predictions</span>(<span class='k'>predictions</span>),
  submit_predictions = <span class='nf'>target</span>(
    <span class='nf'>submit_predictions</span>(<span class='k'>predictions</span>),
    trigger = <span class='nf'>trigger</span>(condition = <span class='k'>validation</span>, mode = <span class='s'>"blacklist"</span>)
  )
)</code></pre>

</div>

Drake is magic. I'm not going to go through the intricacies of this plan or how drake works, since [the drake documentation is some of the best I've ever seen for an R package](https://books.ropensci.org/drake/). But here are some reasons to use drake:

1.  It doesn't matter what order you declare the steps, as drake is smart enough to determine the dependencies between them.
2.  If you change something in a step halfway through the plan, drake will work out what needs to be rerun and only rerun that. Drake frees you from having to work out what parts of your code you need to execute when you make a change.
3.  You'll never need a directory of files with names like "01-setup.R", "02-source-data.R", etc. ever again.
4.  Drake can work out which steps of your plan can be parallelised, and makes it easier to do so.
5.  You'll be encouraged to think about your project execution in terms of *pure functions*. R is idiomatically a functional language, and that's the style that makes drake work.

I came across this powerful package when I was researching best practices for R. I wanted to see if I could fit drake into some sort of standardised approach to training and implementing a machine learning model.

Project workflows
-----------------

When it comes to code, there are three major components to a machine learning project:

1.  Exploratory data analysis (EDA)
2.  Model training
3.  Model execution

These components are run independently of each other. EDA is a largely human task, and is usually only performed when the model is created or updated in some major way. The other two components need not operate together --- if model retraining is expensive, or new training data is infrequently available, we might retrain a model on some monthly basis while scoring new data on a daily basis.

I pieced together [a template](https://github.com/mdneuzerling/DrakeModelling) that implements these three components using R-specific tools:

1.  EDA --- **R Markdown**
2.  Model training --- **drake**
3.  Model execution --- **drake**

All three of these components might use similar functions. Typically we would place all of these functions in a directory (almost always called `R/`) and `source` them as needed. Here I want to try to combine these components into a custom R package.

R packages are the standard for complicated R projects. With packages, we gain access to the comprehensive `R CMD CHECK`, as well as `testthat` unit tests and `roxygen2` documentation. I'm certainly not the first to combine drake with a package workflow, but I wanted to have a single repository that combines all elements of a machine learning project.

This template uses a simple random forest sentiment analysis model, based on [labelled data available from the UCI machine learning repository](https://archive.ics.uci.edu/ml/datasets/Sentiment+Labelled+Sentences). Drake takes care of the data caching for us. This means that we can, say, adjust the hyper-parameters of our model and rerun the training plan, and only the modelling step and onward will be rerun.

This template considers machine learning workflows intended to be executed in batch --- for models that run as APIs, consider using `plumber` instead.

Training and execution
----------------------

After cloning the repo, navigate to the directory in which the files are located. The easiest way to do this is to open the project in RStudio.

Model training and execution plans are generated by functions in the package. The package doesn't actually need to be installed --- we can use [`devtools::load_all()`](https://devtools.r-lib.org//reference/load_all.html) to simulate the installation. The model can be trained with:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>devtools</span>::<span class='nf'><a href='https://devtools.r-lib.org//reference/load_all.html'>load_all</a></span>()
<span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='nf'>model_training_plan</span>())</code></pre>

</div>

Plot the plan with [`drake::vis_drake_graph`](https://docs.ropensci.org/drake/reference/vis_drake_graph.html):

![](drake-model-training-plan.png)

Model execution is run similarly:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>devtools</span>::<span class='nf'><a href='https://devtools.r-lib.org//reference/load_all.html'>load_all</a></span>()
<span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='nf'>model_execution_plan</span>())</code></pre>

</div>

Model artefacts --- the random forest model, the vectoriser, and the tfidf weightings --- are saved to and loaded from the `artefacts` directory. This is an arbitrary choice. We could just as easily use a different directory or remote storage.

I've simulated a production step with a `new_data_to_be_scored` function that returns a few reviews to be scored. Predictions are "submitted" through the `submit_prediction()` function. This function does nothing except sleep for 5 seconds. In practice we would submit model output wherever it needs to go --- locally, a cloud service, etc. It's hard to "productionise" a model when it's just a toy.

The exploratory data analysis piece can be found in the `inst/eda/` directory. It's a standard R Markdown file, and can be compiled with `knitr`.

Model and prediction verification
---------------------------------

Both training and execution plans include a *verification* step. These are functions that --- using the `assertthat` package --- ensure certain basic facts about the model and its predictions are true. If any of these assertions is false, an error is returned.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>validate_model</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>random_forest</span>, <span class='k'>vectoriser</span>, <span class='k'>tfidf</span> = <span class='kr'>NULL</span>) {
  <span class='k'>model_sentiment</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>sentiment</span>(<span class='k'>x</span>, <span class='k'>random_forest</span>, <span class='k'>vectoriser</span>, <span class='k'>tfidf</span>)
  <span class='k'>oob</span> <span class='o'>&lt;-</span> <span class='k'>random_forest</span><span class='o'>$</span><span class='k'>err.rate</span>[<span class='k'>random_forest</span><span class='o'>$</span><span class='k'>ntree</span>, <span class='s'>"OOB"</span>] <span class='c'># out of bag error</span>

  <span class='k'>assertthat</span>::<span class='nf'><a href='https://rdrr.io/pkg/assertthat/man/assert_that.html'>assert_that</a></span>(<span class='nf'>model_sentiment</span>(<span class='s'>"love"</span>) <span class='o'>==</span> <span class='s'>"good"</span>)
  <span class='k'>assertthat</span>::<span class='nf'><a href='https://rdrr.io/pkg/assertthat/man/assert_that.html'>assert_that</a></span>(<span class='nf'>model_sentiment</span>(<span class='s'>"bad"</span>) <span class='o'>==</span> <span class='s'>"bad"</span>)
  <span class='k'>assertthat</span>::<span class='nf'><a href='https://rdrr.io/pkg/assertthat/man/assert_that.html'>assert_that</a></span>(<span class='k'>oob</span> <span class='o'>&lt;</span> <span class='m'>0.4</span>)

  <span class='kc'>TRUE</span>
}</code></pre>

</div>

The model artefacts and predictions cannot be exported without passing this verification step. Their relevant drake targets are conditioned on the validation function returning `TRUE`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>output_model</span> <span class='o'>=</span> <span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/target.html'>target</a></span>(
  {
    <span class='nf'><a href='https://rdrr.io/r/base/files2.html'>dir.create</a></span>(<span class='s'>"artefacts"</span>, showWarnings = <span class='kc'>FALSE</span>)
    <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/read_rds.html'>write_rds</a></span>(<span class='k'>vectoriser</span>, <span class='nf'>file_out</span>(<span class='s'>"artefacts/vectoriser.rds"</span>))
    <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/read_rds.html'>write_rds</a></span>(<span class='k'>tfidf</span>, <span class='nf'>file_out</span>(<span class='s'>"artefacts/tfidf.rds"</span>))
    <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/read_rds.html'>write_rds</a></span>(<span class='k'>review_rf</span>, <span class='nf'>file_out</span>(<span class='s'>"artefacts/review_rf.rds"</span>))
  },
  trigger = <span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/trigger.html'>trigger</a></span>(condition = <span class='k'>validation</span>, mode = <span class='s'>"blacklist"</span>)
)</code></pre>

</div>

For example, suppose I changed the assertion above to demand that my model must have an out-of-bag error of less than 0.01% before it can be exported. My model isn't very good, however, so that step will error. The execution steps are dependent on that validation, and so they won't be run.

![](failed-validation.png)

The assertions I've included here are very basic. However, I think these steps of the plans are important and extensible. We could assert that a model:

-   produces sensible outputs, based on type or domain.
-   has an accuracy above a given threshold, based on one or more metrics.
-   does not produce outputs that are biased against a particular group.

We could also assert that predictions of new data:

-   are sensible.
-   do not contain sensitive data.
-   are not biased against particular groups.

Not the best practice
---------------------

If you're interested, [I've put the template up as a git repository](https://github.com/mdneuzerling/DrakeModelling), `DrakeModelling`.

This wasn't my first attempt to template a machine learning workflow. Before I discovered drake I tried to structure [a model as a package](https://github.com/mdneuzerling/ModelAsAPackage) such that *installing the package was the same as training the model*. I did this by having a vignette for model training, which inserted artefacts into the package.

It's a pretty fun way to train a model. Imagine installing a package and triggering a 12-hour model training process? But it's not a very clean approach. Hadley said it was like "fixing the plane while flying it", and he wasn't wrong.

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
<span class='c'>#&gt;  date     2020-06-21                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib source                            </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports     1.1.8      2020-06-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-06-15 [1] Github (r-lib/downlit@9191e1f)    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-06-20 [1] Github (r-lib/hugodown@f7df565)   </span>
<span class='c'>#&gt;  knitr         1.28       2020-02-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  pkgbuild      1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.3.1      2020-06-20 [1] Github (rstudio/rmarkdown@b53a85a)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr       1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.14       2020-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

