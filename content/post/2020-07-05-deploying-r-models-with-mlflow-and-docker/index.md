---
title: Deploying R Models with MLflow and Docker
author: ~
date: '2020-07-05'
slug: deploying-r-models-with-mlflow-and-docker
tags:
    - R
images: ["/img/containers.jpeg"]
featuredalt: |
    Shipping containers
output: hugodown::md_document
rmd_hash: 01aeb04dbf80e40d

---

[MLflow](https://mlflow.org/) is a platform for the "machine learning cycle". It's a suite of tools for managing models, with tracking of hyperparameters and metrics, a registry of models, and options for serving. It's this last bit that I'm going to focus on today.

I haven't been able to find much discussion or documentation about MLflow's support for R. There's the [RStudio MLflow example](https://github.com/rstudio/mlflow-example), but I wanted to see if I could use MLflow to serve something more complex. I'm going to use the `crate` MLflow flavour along with Docker to see if MLflow can be used to serve R models with preprocessing and prediction pipelines that are compositions of multiple functions, which is the standard for R.

MLflow serves every model as an API, and it's an approach that I like. I can imagine serving multiple models simultaneously and querying them with a common dataset to compare performance.

I need to stress that MLflow isn't just for serving models --- one of its major appeals is the logging of hyperparameters and metrics in a model registry, along with a beautiful UI. I'm ignoring those components here, but that doesn't mean they're not important.

Packaging models with `crate`
-----------------------------

MLflow serves models through "flavours", which usually correspond to machine learning frameworks. In Python there are scikit-learn, TensorFlow, and PyTorch flavours, amongst others. In R there are just two: `keras` and `crate`. I'm not particularly interested in deep learning, so I'll focus on `crate`.

`crate` is a function provided by [the `carrier` package](https://github.com/r-lib/carrier). It allows the packaging of R functions so that they can be sent off to a different R processes. It's easy to see why this would be useful for serving machine learning models, since the goal is to package up a machine learning model and deploy it in some other environment.

Let's take a look at packaging up a simple linear regression with `crate`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>starwars_height_lm</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/stats/lm.html'>lm</a></span>(<span class='k'>height</span> <span class='o'>~</span> <span class='k'>mass</span>, data = <span class='k'>dplyr</span>::<span class='k'><a href='https://dplyr.tidyverse.org/reference/starwars.html'>starwars</a></span>)
<span class='k'>packaged_starwars_height_lm</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
    <span class='nf'>function</span>(<span class='k'>x</span>) <span class='k'>stats</span>::<span class='nf'><a href='https://rdrr.io/r/stats/predict.lm.html'>predict.lm</a></span>(<span class='k'>starwars_height_lm</span>),
    starwars_height_lm = <span class='k'>starwars_height_lm</span>
)</code></pre>

</div>

A `crate` function call consists of a main function, which has to be "freshly" defined within the call, along with a list of objects that accompany the function. I can serialise this `packaged_starwars_height_lm` crate and move it to another R process, and the linear model I trained will move along with it. Serialising in MLflow is done with the S3 generic [`mlflow::mlflow_save_model`](https://rdrr.io/pkg/mlflow/man/mlflow_save_model.html).

A couple of things to note here: I have to be very explicit about how I use functions in `crate`. Just typing `predict` wouldn't do here: I have to use the specific `predict.lm` method for linear models. I also have to declare that it's from the `stats` package. According to the help file, the accompanying objects will be automatically named after themselves if no name is provided, but I haven't found this to be true.

The problem
-----------

There are no package dependencies in the above linear model (well, there's `stats`, but that's always going to be available) so it will work out of the box in any R process. For any "real life" model, there will be dependencies. In particular, [I almost always work with a package workflow](/post/upgrade-your-workflow-with-drake/). My modelling helper functions are contained within a package dedicated to that one model. Each of those functions is a dependency that has to be included in the crated function.

I'll use a simple example. The below won't work, because I haven't given `crate` the three accompanying functions it needs:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>triple</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='m'>3</span><span class='o'>*</span><span class='k'>x</span>
<span class='k'>square</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='k'>x</span><span class='o'>**</span><span class='m'>2</span>
<span class='k'>triplesquare</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triple</span>(<span class='nf'>square</span>(<span class='k'>x</span>))
<span class='k'>fn</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(<span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triplesquare</span>(<span class='k'>x</span>))
<span class='nf'>fn</span>(<span class='m'>2</span>)
<span class='c'>#&gt; Error in triplesquare(x): could not find function "triplesquare"</span></code></pre>

</div>

If I provide the three functions, everything works:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>fn</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triplesquare</span>(<span class='k'>x</span>),
  triplesquare = <span class='k'>triplesquare</span>,
  square = <span class='k'>square</span>,
  triple = <span class='k'>triple</span>)
<span class='nf'>fn</span>(<span class='m'>2</span>)
<span class='c'>#&gt; [1] 12</span></code></pre>

</div>

But then, if I delete the functions from the global environment, the crated function no longer works:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/rm.html'>rm</a></span>(<span class='k'>triple</span>, <span class='k'>square</span>, <span class='k'>triplesquare</span>)
<span class='nf'>fn</span>(<span class='m'>2</span>)
<span class='c'>#&gt; Error in triple(square(x)): could not find function "triple"</span></code></pre>

</div>

I need to be able to provide these functions to `crate` in a way that they can be carried along with the crated function somehow.

Option 1: Install the package
-----------------------------

If I'm using a package workflow, then the obvious solution is to install the package. I'll be using [my usual "ReviewSentiment" model](/post/upgrade-your-workflow-with-drake/) as an example, here as a package called [ReviewSentimentMLflow](https://github.com/mdneuzerling/ReviewSentimentMLflow). This package trains a random forest model that predicts the sentiment of brief product reviews. The random forest has three artefacts: a `review_rf` model object, along with `vectoriser` and `tfidf` objects for preprocessing. I can crate all of this up along with my `sentiment` predict function as below. Note the explicit mention of the `ReviewSentimentMLflow` namespace, which is required if I'm installing the package:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>crated_model</span> <span class='o'>=</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>review</span>) { <span class='c'># Function must be "fresh", ie. not pre-defined</span>
    <span class='k'>ReviewSentimentMLflow</span>::<span class='nf'>sentiment</span>(<span class='k'>review</span>, <span class='k'>review_rf</span>, <span class='k'>vectoriser</span>, <span class='k'>tfidf</span>)
  },
  review_rf = <span class='k'>review_rf</span>,
  vectoriser = <span class='k'>vectoriser</span>,
  tfidf = <span class='k'>tfidf</span>
)</code></pre>

</div>

These other artefacts --- `review_rf`, `vectoriser` and `tfidf` --- are not part of the package. They are model artefacts generated during training. `crate` can handle those as is. I can serialise `crated_model` with `mlflow_save_model`, and then everything can be exported to another platform. There are a few helper functions used in the definition of `sentiment`, but as long as that `ReviewSentimentMLflow` package is installed on that platform I can serve the model with MLflow using the terminal command `mlflow models serve`.

But the packages I use for my models are highly specific to a certain dataset and use case; they certainly aren't going on CRAN. The underlying motivation here is that I want to be able to execute my model on a machine that isn't my computer, so that means I need to be able to move my package along with the `crated_model`.

### Accept that everything will be put in a container eventually

[Docker](https://www.docker.com/) containers are the go-to solution for reproducibility. The idea is straightforward: put the crated model and all dependencies into a container, so that everything moves as one. There's ample support for running containers, especially on the cloud, and containerisation is arguably the gold standard for reproducible workflows.

[I first learned how to use R with Docker at useR 2018](/post/user-getting-started-with-r-and-docker/), but getting everything incorporating everything into a Dockerfile was a real challenge. This is what worked in the end:

    FROM rocker/r-ver:4.0.0
    ENV RENV_VERSION 0.10.0
    ENV CRAN_REPO https://packagemanager.rstudio.com/all/__linux__/focal/latest
    ENV MINICONDA_INSTALLER Miniconda3-py38_4.8.3-Linux-x86_64.sh
    ENV LISTENING_HOST 0.0.0.0
    ENV LISTENING_PORT 5000
    # Copy the entirety of the context into the image. This should be the R package source.
    ADD . / /model-package/
    WORKDIR /model-package

    # Install system dependencies. I couldn't get sysreqs to work here, since python-minimal
    # isn't available on this implementation of rocker. Curl is required to download Miniconda.
    RUN apt-get -y update && \
        apt-get install -y curl libgit2-dev libssl-dev zlib1g-dev \
        pandoc pandoc-citeproc make libxml2-dev libgmp-dev libgfortran4 \
        libcurl4-openssl-dev libssh2-1-dev libglpk-dev git-core

    # renv::restore can be a bit buggy if .Rprofile and the renv directory exist
    RUN rm -f .Rprofile
    RUN rm -rf renv
    RUN Rscript -e "install.packages('remotes', repos = c(CRAN = Sys.getenv('CRAN_REPO')))"
    RUN Rscript -e "remotes::install_github('rstudio/renv', ref = Sys.getenv('RENV_VERSION'))"
    RUN Rscript -e "renv::restore(repos = c(CRAN = Sys.getenv('CRAN_REPO')))"

    # Install miniconda to /miniconda and install mlflow
    RUN curl -LO https://repo.anaconda.com/miniconda/$MINICONDA_INSTALLER
    RUN bash $MINICONDA_INSTALLER -p /miniconda -b
    RUN rm $MINICONDA_INSTALLER
    ENV PATH=/miniconda/bin:${PATH}
    RUN pip install mlflow
    ENV MLFLOW_BIN /miniconda/bin/mlflow
    ENV MLFLOW_PYTHON_BIN /miniconda/bin/python

    RUN Rscript -e "if (!require('devtools')) install.packages('devtools', repos = Sys.getenv('CRAN_REPO'))"
    RUN Rscript -e "devtools::install(dependencies = FALSE)"

    ENTRYPOINT ["/usr/bin/env"]
    CMD mlflow models serve -m artefacts/model --host $LISTENING_HOST --port $LISTENING_PORT

The flow of this Dockerfile is:

1.  Start with R (thanks to the [Rocker project](https://www.rocker-project.org/))
2.  Set some environment variables to guide reproducibility
3.  Copy the entire model package source code into the image (which contains the trained model artefacts, including the crated model)
4.  Install system dependencies with `apt-get`
5.  Install R package dependencies with `renv`
6.  Install [Miniconda](https://docs.conda.io/en/latest/miniconda.html) (a minimal version of Anaconda)
7.  Install the Python MLflow module and configure its environment variables (required to run MLflow, even in R)
8.  Install the model package
9.  Serve the model with mlflow

I've used [renv](https://rstudio.github.io/renv/) to lock down the package versions. I'm also using the [RStudio Package Manager](https://packagemanager.rstudio.com/client/#/) to download binaries instead of source code, which greatly reduces the package install time.

To build the image, I navigate to the directory containing the package code and run the following in a terminal:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>Docker build --tag review-sentiment .
</code></pre>

</div>

The build process will take some time, as it has to pull in all of the packages recorded in the `renv` lockfile. The resulting image is 2.5GB, which is disappointing given that the model artefacts (including the random forest) are altogether under a megabyte when compressed. A Docker guru could no doubt bring this size down, but there is a storage penalty for exporting an entire environment in which to run a model.

To run the model, I enter the following command at a terminal:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>Docker run -p 5000:5000 review-sentiment
</code></pre>

</div>

MLflow serves models as APIs, so I can query this model with `curl`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>curl -X POST "http://127.0.0.1:5000/predict/" -H  "accept: application/json" -H  "Content-Type: application/json" -d "\"love\""
# "good"
</code></pre>

</div>

This is a highly portable way of exporting a model. Actually, it doesn't matter too much how the the model is served here --- a model exposed with the `plumber` package would work just as well.

I think this approach betrays the objective of MLflow. I already have an exported model object, and it's reasonable to expect that the model object should work as is on any other machine. I can understand why I would use a container to provide a reproducible environment in which to serve that model, but it's MLflow's responsibility to do the actual serving.

I think it would be better to separate responsibilities here: containers provide a reproducible environment for model serving, but MLflow does the serving independently of the container.

Option 2: Don't install the package
-----------------------------------

Consider the original problem of crating model objects along with the helper functions required to work with them. There's another solution to this, and it's suggested by examples in the `carrier` documentation: I can take my functions, rip them out of their package environment, and stick them into the `crate` environment.

This is done through the [`rlang::set_env`](https://rlang.r-lib.org/reference/get_env.html) function, which returns a copy of the function in a new environment. If I don't specify the environment, it defaults to the caller environment, which in the case below is that of `crate`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>triple</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='m'>3</span><span class='o'>*</span><span class='k'>x</span>
<span class='k'>square</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='k'>x</span><span class='o'>**</span><span class='m'>2</span>
<span class='k'>triplesquare</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triple</span>(<span class='nf'>square</span>(<span class='k'>x</span>))
<span class='k'>fn</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triplesquare</span>(<span class='k'>x</span>),
  triplesquare = <span class='k'>rlang</span>::<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='k'>triplesquare</span>),
  square = <span class='k'>rlang</span>::<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='k'>square</span>),
  triple = <span class='k'>rlang</span>::<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='k'>triple</span>)
)
<span class='nf'><a href='https://rdrr.io/r/base/rm.html'>rm</a></span>(<span class='k'>triple</span>, <span class='k'>square</span>, <span class='k'>triplesquare</span>)
<span class='nf'>fn</span>(<span class='m'>2</span>)
<span class='c'>#&gt; [1] 12</span></code></pre>

</div>

### Metaprogramming is magic

I don't want to manually type out every single function in my package. But because I'm using R I don't have to. In R I can formulate the expressions I want to evaluate but do the evaluating later. This is called non-standard evaluation or **metaprogramming**. Let's suppose I have a vector of names of functions I want to apply the `set_env` treatment to. So, for [`c("triplesquare", "square", "triple")`](https://rdrr.io/r/base/c.html):

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='http://rlang.r-lib.org'>rlang</a></span>)
<span class='k'>triple</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='m'>3</span><span class='o'>*</span><span class='k'>x</span>
<span class='k'>square</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='k'>x</span><span class='o'>**</span><span class='m'>2</span>
<span class='k'>triplesquare</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triple</span>(<span class='nf'>square</span>(<span class='k'>x</span>))

<span class='k'>functions_to_crate</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"triplesquare"</span>, <span class='s'>"square"</span>, <span class='s'>"triple"</span>)
<span class='k'>functions_to_set_env</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/lapply.html'>lapply</a></span>(<span class='k'>functions_to_crate</span>, <span class='nf'>function</span> (<span class='k'>x</span>) {
  <span class='nf'><a href='https://rlang.r-lib.org/reference/nse-defuse.html'>expr</a></span>(<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='o'>!</span><span class='o'>!</span><span class='nf'><a href='https://rlang.r-lib.org/reference/sym.html'>sym</a></span>(<span class='k'>x</span>)))
})
<span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>functions_to_set_env</span>) <span class='o'>&lt;-</span> <span class='k'>functions_to_crate</span>

<span class='k'>fn</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triplesquare</span>(<span class='k'>x</span>),
  <span class='o'>!</span><span class='o'>!</span><span class='o'>!</span><span class='k'>functions_to_set_env</span>
)
<span class='nf'><a href='https://rdrr.io/r/base/rm.html'>rm</a></span>(<span class='k'>triple</span>, <span class='k'>square</span>, <span class='k'>triplesquare</span>)
<span class='nf'>fn</span>(<span class='m'>2</span>)
<span class='c'>#&gt; [1] 12</span></code></pre>

</div>

Metaprogramming is one of the trickier parts of R. It's not a standard feature of programming languages, so anyone who isn't coming from a lisp background is likely to be confused. I'll break down what's happening here, but for a full introduction to metaprogramming there's no better resource than [Advanced R](https://adv-r.hadley.nz/metaprogramming.html).

I'm using the `rlang` package which provides a nicer metaprogramming interface with a few more features. The core idea here is that sometimes I want to save an expression to be evaluated for later (with `expr`), but sometimes I want to evaluate it right now (with `!!`) --- a concept called *quasiquotation*. Consider the example below:

    expr(set_env(!!sym(x)))

I'm giving R here an expression [`set_env(!!sym(x))`](https://rlang.r-lib.org/reference/get_env.html) but, because I've wrapped it in `expr`, I'm telling R not to evaluate it immediately. Except there is a part here that I do want to evaluate immediately: `x` is a character that I want to convert into a symbolic value. That is, I want to convert `"triple"` into `triple`. I can do this with the `sym` function and, by prefacing it with `!!`, I can tell R to ignore the `expr` and do this conversion *immediately*:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rlang.r-lib.org/reference/nse-defuse.html'>expr</a></span>(<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='o'>!</span><span class='o'>!</span><span class='nf'><a href='https://rlang.r-lib.org/reference/sym.html'>sym</a></span>(<span class='s'>"triple"</span>)))
<span class='c'>#&gt; set_env(triple)</span></code></pre>

</div>

I can see how this expression would be evaluated by directly inspecting the abstract syntax tree (AST) with `lobstr`. First, letting `x <- "triple"` and without using `!!`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>lobstr</span>::<span class='nf'><a href='https://rdrr.io/pkg/lobstr/man/ast.html'>ast</a></span>(<span class='nf'><a href='https://rlang.r-lib.org/reference/nse-defuse.html'>expr</a></span>(<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='nf'><a href='https://rlang.r-lib.org/reference/sym.html'>sym</a></span>(<span class='s'>"triple"</span>))))
<span class='c'>#&gt; <span style='color: #FFAF00;'>█</span><span>─</span><span style='color: #BB00BB;font-weight: bold;'>expr</span><span> </span></span>
<span class='c'>#&gt; └─<span style='color: #FFAF00;'>█</span><span>─</span><span style='color: #BB00BB;font-weight: bold;'>set_env</span><span> </span></span>
<span class='c'>#&gt;   └─<span style='color: #FFAF00;'>█</span><span>─</span><span style='color: #BB00BB;font-weight: bold;'>sym</span><span> </span></span>
<span class='c'>#&gt;     └─"triple"</span></code></pre>

</div>

...and now with the `!!`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>x</span> <span class='o'>&lt;-</span> <span class='s'>"triple"</span>
<span class='k'>lobstr</span>::<span class='nf'><a href='https://rdrr.io/pkg/lobstr/man/ast.html'>ast</a></span>(<span class='nf'><a href='https://rlang.r-lib.org/reference/nse-defuse.html'>expr</a></span>(<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='o'>!</span><span class='o'>!</span><span class='nf'><a href='https://rlang.r-lib.org/reference/sym.html'>sym</a></span>(<span class='s'>"triple"</span>))))
<span class='c'>#&gt; <span style='color: #FFAF00;'>█</span><span>─</span><span style='color: #BB00BB;font-weight: bold;'>expr</span><span> </span></span>
<span class='c'>#&gt; └─<span style='color: #FFAF00;'>█</span><span>─</span><span style='color: #BB00BB;font-weight: bold;'>set_env</span><span> </span></span>
<span class='c'>#&gt;   └─<span style='color: #BB00BB;font-weight: bold;'>triple</span></span></code></pre>

</div>

The `!!` forces the evaluation of the AST at [`sym("triple")`](https://rlang.r-lib.org/reference/sym.html), without evaluating the rest of the expression. So the expression I have at the end is just [`set_env(triple)`](https://rlang.r-lib.org/reference/get_env.html).

I've now got an expression that I can evaluate when I want and in whatever environment I want. I'm generating code with code! And with `lapply` I can generate an expression like this for every function, and end up with a named list of expressions.

I've saved these expressions so that I can evaluate them in the call to `crate`, which will copy every function into the `crate` environment. I do this with `!!!` (or "bang-bang-bang"). This forces the evaluation of every element in my list of expressions and uses them as arguments to the `crate` function:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>fn</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'>triplesquare</span>(<span class='k'>x</span>),
  <span class='o'>!</span><span class='o'>!</span><span class='o'>!</span><span class='k'>functions_to_set_env</span>
)</code></pre>

</div>

### Crate everything

I have a method for taking a character vector of functions and including them in a crated function. I'm going to apply that method to a model package, in which all of my functions are in the package namespace:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'># Already defined and loaded: model_package_path</span>
<span class='nf'>loadd</span>(<span class='k'>review_rf</span>, <span class='k'>vectoriser</span>, <span class='k'>tfidf</span>)
<span class='k'>package_name</span> <span class='o'>&lt;-</span> <span class='k'>pkgload</span>::<span class='nf'><a href='https://rdrr.io/pkg/pkgload/man/packages.html'>pkg_name</a></span>(<span class='k'>model_package_path</span>)
<span class='k'>package_namespace_ls</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/ls.html'>ls</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/ns-reflect.html'>getNamespace</a></span>(<span class='k'>package_name</span>))
<span class='k'>package_contents_to_set_env</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/lapply.html'>lapply</a></span>(<span class='k'>package_namespace_ls</span>, <span class='nf'>function</span> (<span class='k'>x</span>) {
  <span class='k'>rlang</span>::<span class='nf'><a href='https://rlang.r-lib.org/reference/nse-defuse.html'>expr</a></span>(<span class='k'>rlang</span>::<span class='nf'><a href='https://rlang.r-lib.org/reference/get_env.html'>set_env</a></span>(<span class='o'>!</span><span class='o'>!</span><span class='k'>rlang</span>::<span class='nf'><a href='https://rlang.r-lib.org/reference/sym.html'>sym</a></span>(<span class='k'>x</span>)))
})
<span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>package_contents_to_set_env</span>) <span class='o'>&lt;-</span> <span class='k'>package_namespace_ls</span>
<span class='k'>crated_model</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>review</span>) {
    <span class='nf'>sentiment</span>(<span class='k'>review</span>, <span class='k'>review_rf</span>, <span class='k'>vectoriser</span>, <span class='k'>tfidf</span>)
  },
  review_rf = <span class='k'>review_rf</span>,
  vectoriser = <span class='k'>vectoriser</span>,
  tfidf = <span class='k'>tfidf</span>,
  <span class='o'>!</span><span class='o'>!</span><span class='o'>!</span><span class='k'>package_contents_to_set_env</span>
)
<span class='k'>crated_model</span>
<span class='c'>#&gt; Registered S3 method overwritten by 'pryr':</span>
<span class='c'>#&gt;   method      from</span>
<span class='c'>#&gt;   print.bytes Rcpp</span>
<span class='c'>#&gt; &lt;crate&gt; 8.03 MB</span>
<span class='c'>#&gt; * function: 18.1 kB</span>
<span class='c'>#&gt; * `create_tfidf`: 8.02 MB</span>
<span class='c'>#&gt; * `create_vocabulary`: 8.02 MB</span>
<span class='c'>#&gt; * `download_and_read_data`: 8.02 MB</span>
<span class='c'>#&gt; * `execution_plan`: 8.02 MB</span>
<span class='c'>#&gt; * `generate_roc`: 8.02 MB</span>
<span class='c'>#&gt; * `map_to_dtm`: 8.02 MB</span>
<span class='c'>#&gt; * `new_data_to_be_scored`: 8.02 MB</span>
<span class='c'>#&gt; * `read_review_file`: 8.02 MB</span>
<span class='c'>#&gt; * `sentiment`: 8.02 MB</span>
<span class='c'>#&gt; * `stem_tokeniser`: 8.02 MB</span>
<span class='c'>#&gt; * `text_preprocessor`: 8.02 MB</span>
<span class='c'>#&gt; * `training_plan`: 8.02 MB</span>
<span class='c'>#&gt; * `review_rf`: 7.44 MB</span>
<span class='c'>#&gt; * `tfidf`: 280 kB</span>
<span class='c'>#&gt; * `vectoriser`: 85.8 kB</span>
<span class='c'>#&gt; function(review) {</span>
<span class='c'>#&gt;     sentiment(review, review_rf, vectoriser, tfidf)</span>
<span class='c'>#&gt;   }</span></code></pre>

</div>

How cool is that? Everything in the model package is now also in the crated model, and it was all picked up automatically. There seems to be some issues with the print of this `packaged_model`, as those individual functions are not 8MB each. The actual `crate` is around 8MB, which compresses to under 1MB --- roughly the same as the `crate` without the functions.

I can now export this packaged model with [`mlflow::mlflow_save_model(packaged_model, "artefacts/model")`](https://rdrr.io/pkg/mlflow/man/mlflow_save_model.html). I'll still use a Docker image for reproducibility, and the Dockerfile will look almost identical to the first one:

    FROM rocker/r-ver:4.0.0
    ENV RENV_VERSION 0.10.0
    ENV CRAN_REPO https://packagemanager.rstudio.com/all/__linux__/focal/latest
    ENV MINICONDA_INSTALLER Miniconda3-py38_4.8.3-Linux-x86_64.sh
    # Copy the entirety of the context into the image. This should be the R package source.
    ADD renv.lock /

    # Install system dependencies. I couldn't get sysreqs to work here, since python-minimal
    # isn't available on this implementation of rocker. Curl is required to download Miniconda.
    RUN apt-get -y update && \
        apt-get install -y curl libgit2-dev libssl-dev zlib1g-dev \
        pandoc pandoc-citeproc make libxml2-dev libgmp-dev libgfortran4 \
        libcurl4-openssl-dev libssh2-1-dev libglpk-dev git-core

    RUN Rscript -e "install.packages('remotes', repos = c(CRAN = Sys.getenv('CRAN_REPO')))"
    RUN Rscript -e "remotes::install_github('rstudio/renv', ref = Sys.getenv('RENV_VERSION'))"
    RUN Rscript -e "renv::restore(repos = c(CRAN = Sys.getenv('CRAN_REPO')))"

    # Install miniconda to /miniconda and install mlflow
    RUN curl -LO https://repo.anaconda.com/miniconda/$MINICONDA_INSTALLER
    RUN bash $MINICONDA_INSTALLER -p /miniconda -b
    RUN rm $MINICONDA_INSTALLER
    ENV PATH=/miniconda/bin:${PATH}
    RUN pip install mlflow
    ENV MLFLOW_BIN /miniconda/bin/mlflow
    ENV MLFLOW_PYTHON_BIN /miniconda/bin/python

    ENTRYPOINT ["/usr/bin/env"]

A couple of differences between this Dockerfile and the first one:

-   I'm only copying one file from the model package --- the `renv.lock` file. That is, the only information I'm baking into the image from the model package is \*the list of package dependencies.
-   I'm no longer installing the model package into the image.
-   I'm no longer running `mlflow models serve` within the image itself. The image is just an environment in which commands are run.

This last point is a pretty big deal. I've changed my approach to reproducibility here by introducing a line between *environment* and *model*. I can change the model by running a new crated model. I can do this without having to rebuild the image, because the model is no longer baked into the image. I could even share a single image across multiple containers.

There's one snag here: `renv` dependencies. If I add another package as a dependency to the model, I'll need to rebuild the image. It's possible to use caching to speed things up, but I wonder if it's possible to use the [RStudio Package Manager](https://packagemanager.rstudio.com/client/#/) to pin our dependencies by *date*, and then have the image install new packages as needed? That way, as long as I use the same date-locked repository in both development and the Dockerfile, I won't have to rebuild the image every time I introduce a new dependency. My Docker skills aren't up to this task, but it doesn't sound impossible.

I'll build the image as before, but give it a different tag:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>Docker build --tag review-sentiment-env-only .
</code></pre>

</div>

My Docker image contains only the environment, so `docker run` is a little different. I mount the exported model as a volume within the container, and I give the `mlflow models serve` command when I *run* the image, not when I *build* it.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>docker run -p 5000:5000 -v $(pwd)/artefacts/model:/model review-sentiment-env-only mlflow models serve -m model --host 0.0.0.0 --port 5000
</code></pre>

</div>

### But that doesn't work

I really thought this would work, but when I try to query the API I get a dependency issue:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>curl -X POST "http://127.0.0.1:5000/predict/" -H  "accept: application/json" -H  "Content-Type: application/json" -d "\"love\""
# Invalid Request.  could not find function "%>%"
</code></pre>

</div>

Earlier I mentioned that `crate` expects specifically declared functions. I couldn't use `predict.lm` for a linear model; I had to use [`stats::predict.lm`](https://rdrr.io/r/stats/predict.lm.html). Well in my `ReviewSentimentMLflow` package I import `%>%` from `dplyr`/`magrittr` and use it without the double colon reference. That's why R can't find `%>%` here: it doesn't know what namespace it's in. Importing `dplyr` or `magrittr` won't fix this issue either, since R won't know to look in those namespaces.

I don't want to have to type `` magrittr::`%>%` `` every time I want to pipe, so I'll have to include this function in the call to `crate`. I won't use `rlang::set_env` this time, because I want these functions to keep their namespaces. When I implemented `%>%` I also noticed that the S3 method `randomForest:::predict.randomForest` was being called in the `sentiment` function. Both of these functions are included below:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>crated_model</span> <span class='o'>&lt;-</span> <span class='k'>carrier</span>::<span class='nf'><a href='https://rdrr.io/pkg/carrier/man/crate.html'>crate</a></span>(
  <span class='nf'>function</span>(<span class='k'>review</span>) {
    <span class='nf'>sentiment</span>(<span class='k'>review</span>, <span class='k'>review_rf</span>, <span class='k'>vectoriser</span>, <span class='k'>tfidf</span>)
  },
  review_rf = <span class='k'>review_rf</span>,
  vectoriser = <span class='k'>vectoriser</span>,
  tfidf = <span class='k'>tfidf</span>,
  <span class='o'>!</span><span class='o'>!</span><span class='o'>!</span><span class='k'>package_contents_to_set_env</span>,
  <span class='s'>"%&gt;%"</span> = <span class='k'>magrittr</span>::<span class='k'>`%&gt;%`</span>,
  <span class='s'>"predict.randomForest"</span> = <span class='k'>randomForest</span>:::<span class='k'><a href='https://rdrr.io/pkg/randomForest/man/predict.randomForest.html'>predict.randomForest</a></span>
)</code></pre>

</div>

It's a lot of work, declaring all of these dependencies, but now my `MLflow` model is being successfully served:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>curl -X POST "http://127.0.0.1:5000/predict/" -H  "accept: application/json" -H  "Content-Type: application/json" -d "\"love\""
# "good"
</code></pre>

</div>

MLflow and R
------------

Overall, I don't feel confident using MLflow to deploy and serve an R model. The support through the `carrier` package is promising, but not yet mature enough to serve anything other than simple models with simple preprocessing.

I think the `carrier` package is a great approach to exporting an R model, and that the ability to export an arbitrary function would be more flexible than exporting an object in a given machine learning framework. But the package needs more power in terms of dependency detection.

It's reasonable to expect that R models will be developed in package workflows, so that users can take advantage of powerful packages like `devtools`, `testthat`, and `roxygen2`. Dependencies are clearly declared in package workflows, and `R CMD check` will yell at the user if a dependency isn't listed. Given this, I think that `carrier` and MLflow can be advanced together by implementing automatic detection of dependencies within a package workflow.

In particular, `carrier` could be improved by

1.  supporting the importation of all functions within a given package into a `crate` call,
2.  supporting the importation of all declared imports within a NAMESPACE file (which would cover the above `%>%` issue), and
3.  providing better support for S3 dispatch.

I'd be cautious of doing this sort of global package import with arbitrary packages (it would fall apart as soon as it encounters compiled code), but I think it's suitable for package workflows or "models as packages". I've also heard of [a package called `defer`](https://github.com/lbartnik/defer) which may do some of the above, although I haven't looked into it.

I've outlined some approaches here for accommodating a package workflow with `carrier`, so there's possibly some room here for me to contribute.

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
<span class='c'>#&gt;  date     2020-07-05                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  ! package               * version    date       lib</span>
<span class='c'>#&gt;    askpass                 1.1        2019-01-13 [1]</span>
<span class='c'>#&gt;    assertthat              0.2.1      2019-03-21 [1]</span>
<span class='c'>#&gt;    backports               1.1.8      2020-06-17 [1]</span>
<span class='c'>#&gt;    base64enc               0.1-3      2015-07-28 [1]</span>
<span class='c'>#&gt;    base64url               1.4        2018-05-14 [1]</span>
<span class='c'>#&gt;    callr                   3.4.3      2020-03-28 [1]</span>
<span class='c'>#&gt;    carrier                 0.1.0      2018-10-16 [1]</span>
<span class='c'>#&gt;    cli                     2.0.2      2020-02-28 [1]</span>
<span class='c'>#&gt;    codetools               0.2-16     2018-12-24 [4]</span>
<span class='c'>#&gt;    colorspace              1.4-1      2019-03-18 [1]</span>
<span class='c'>#&gt;    crayon                  1.3.4      2017-09-16 [1]</span>
<span class='c'>#&gt;    curl                    4.3        2019-12-02 [1]</span>
<span class='c'>#&gt;    data.table              1.12.8     2019-12-09 [1]</span>
<span class='c'>#&gt;    desc                    1.2.0      2018-05-01 [1]</span>
<span class='c'>#&gt;    devtools                2.3.0      2020-04-10 [1]</span>
<span class='c'>#&gt;    digest                  0.6.25     2020-02-23 [1]</span>
<span class='c'>#&gt;    downlit                 0.0.0.9000 2020-06-15 [1]</span>
<span class='c'>#&gt;    dplyr                   0.8.5      2020-03-07 [1]</span>
<span class='c'>#&gt;    drake                 * 7.12.2     2020-06-02 [1]</span>
<span class='c'>#&gt;    ellipsis                0.3.1      2020-05-15 [1]</span>
<span class='c'>#&gt;    evaluate                0.14       2019-05-28 [1]</span>
<span class='c'>#&gt;    fansi                   0.4.1      2020-01-08 [1]</span>
<span class='c'>#&gt;    filelock                1.0.2      2018-10-05 [1]</span>
<span class='c'>#&gt;    float                   0.2-4      2020-04-22 [1]</span>
<span class='c'>#&gt;    forge                   0.2.0      2019-02-26 [1]</span>
<span class='c'>#&gt;    fs                      1.4.1      2020-04-04 [1]</span>
<span class='c'>#&gt;    generics                0.0.2      2018-11-29 [1]</span>
<span class='c'>#&gt;    ggplot2                 3.3.0      2020-03-05 [1]</span>
<span class='c'>#&gt;    glue                    1.4.1      2020-05-13 [1]</span>
<span class='c'>#&gt;    gtable                  0.3.0      2019-03-25 [1]</span>
<span class='c'>#&gt;    here                    0.1        2017-05-28 [1]</span>
<span class='c'>#&gt;    hms                     0.5.3      2020-01-08 [1]</span>
<span class='c'>#&gt;    htmltools               0.5.0      2020-06-16 [1]</span>
<span class='c'>#&gt;    httpuv                  1.5.2      2019-09-11 [1]</span>
<span class='c'>#&gt;    httr                    1.4.1      2019-08-05 [1]</span>
<span class='c'>#&gt;    hugodown                0.0.0.9000 2020-06-20 [1]</span>
<span class='c'>#&gt;    igraph                  1.2.5      2020-03-19 [1]</span>
<span class='c'>#&gt;    ini                     0.3.1      2018-05-20 [1]</span>
<span class='c'>#&gt;    janeaustenr             0.1.5      2017-06-10 [1]</span>
<span class='c'>#&gt;    jsonlite                1.6.1      2020-02-02 [1]</span>
<span class='c'>#&gt;    knitr                   1.28       2020-02-06 [1]</span>
<span class='c'>#&gt;    later                   1.1.0.1    2020-06-05 [1]</span>
<span class='c'>#&gt;    lattice                 0.20-41    2020-04-02 [4]</span>
<span class='c'>#&gt;    lgr                     0.3.4      2020-03-20 [1]</span>
<span class='c'>#&gt;    lifecycle               0.2.0      2020-03-06 [1]</span>
<span class='c'>#&gt;    lobstr                  1.1.1      2019-07-02 [1]</span>
<span class='c'>#&gt;    magrittr                1.5        2014-11-22 [1]</span>
<span class='c'>#&gt;    Matrix                  1.2-18     2019-11-27 [4]</span>
<span class='c'>#&gt;    memoise                 1.1.0.9000 2020-05-09 [1]</span>
<span class='c'>#&gt;    mlapi                   0.1.0      2017-12-17 [1]</span>
<span class='c'>#&gt;    mlflow                  1.9.0      2020-06-22 [1]</span>
<span class='c'>#&gt;    munsell                 0.5.0      2018-06-12 [1]</span>
<span class='c'>#&gt;    NLP                     0.2-0      2018-10-18 [1]</span>
<span class='c'>#&gt;    openssl                 1.4.1      2019-07-18 [1]</span>
<span class='c'>#&gt;    pillar                  1.4.4      2020-05-05 [1]</span>
<span class='c'>#&gt;    pkgbuild                1.0.7      2020-04-25 [1]</span>
<span class='c'>#&gt;    pkgconfig               2.0.3      2019-09-22 [1]</span>
<span class='c'>#&gt;    pkgload                 1.0.2      2018-10-29 [1]</span>
<span class='c'>#&gt;    plotROC                 2.2.1      2018-06-23 [1]</span>
<span class='c'>#&gt;    prettyunits             1.1.1      2020-01-24 [1]</span>
<span class='c'>#&gt;    processx                3.4.2      2020-02-09 [1]</span>
<span class='c'>#&gt;    progress                1.2.2      2019-05-16 [1]</span>
<span class='c'>#&gt;    promises                1.1.0      2019-10-04 [1]</span>
<span class='c'>#&gt;    pryr                    0.1.4      2018-02-18 [1]</span>
<span class='c'>#&gt;    ps                      1.3.3      2020-05-08 [1]</span>
<span class='c'>#&gt;    purrr                   0.3.4      2020-04-17 [1]</span>
<span class='c'>#&gt;    R6                      2.4.1      2019-11-12 [1]</span>
<span class='c'>#&gt;    randomForest            4.6-14     2018-03-25 [1]</span>
<span class='c'>#&gt;    Rcpp                    1.0.4.6    2020-04-09 [1]</span>
<span class='c'>#&gt;    readr                   1.3.1      2018-12-21 [1]</span>
<span class='c'>#&gt;    remotes                 2.1.1      2020-02-15 [1]</span>
<span class='c'>#&gt;    reticulate              1.15       2020-04-02 [1]</span>
<span class='c'>#&gt;  R ReviewSentimentMLflow * 0.1.0      &lt;NA&gt;       [?]</span>
<span class='c'>#&gt;    RhpcBLASctl             0.20-17    2020-01-17 [1]</span>
<span class='c'>#&gt;    rlang                 * 0.4.6      2020-05-02 [1]</span>
<span class='c'>#&gt;    rmarkdown               2.3.1      2020-06-20 [1]</span>
<span class='c'>#&gt;    rprojroot               1.3-2      2018-01-03 [1]</span>
<span class='c'>#&gt;    rsparse                 0.4.0      2020-04-01 [1]</span>
<span class='c'>#&gt;    rstudioapi              0.11       2020-02-07 [1]</span>
<span class='c'>#&gt;    scales                  1.1.0      2019-11-18 [1]</span>
<span class='c'>#&gt;    sessioninfo             1.1.1      2018-11-05 [1]</span>
<span class='c'>#&gt;    slam                    0.1-47     2019-12-21 [1]</span>
<span class='c'>#&gt;    SnowballC               0.7.0      2020-04-01 [1]</span>
<span class='c'>#&gt;    storr                   1.2.1      2018-10-18 [1]</span>
<span class='c'>#&gt;    stringi                 1.4.6      2020-02-17 [1]</span>
<span class='c'>#&gt;    stringr                 1.4.0      2019-02-10 [1]</span>
<span class='c'>#&gt;    swagger                 3.9.2      2018-03-23 [1]</span>
<span class='c'>#&gt;    testthat              * 2.3.2      2020-03-02 [1]</span>
<span class='c'>#&gt;    text2vec                0.6        2020-02-18 [1]</span>
<span class='c'>#&gt;    tibble                  3.0.1      2020-04-20 [1]</span>
<span class='c'>#&gt;    tidyselect            * 1.0.0      2020-01-27 [1]</span>
<span class='c'>#&gt;    tidytext                0.2.4      2020-04-17 [1]</span>
<span class='c'>#&gt;    tm                      0.7-7      2019-12-12 [1]</span>
<span class='c'>#&gt;    tokenizers              0.2.1      2018-03-29 [1]</span>
<span class='c'>#&gt;    txtq                    0.2.0      2019-10-15 [1]</span>
<span class='c'>#&gt;    usethis                 1.6.1      2020-04-29 [1]</span>
<span class='c'>#&gt;    vctrs                   0.3.1      2020-06-05 [1]</span>
<span class='c'>#&gt;    withr                   2.2.0      2020-04-20 [1]</span>
<span class='c'>#&gt;    xfun                    0.14       2020-05-20 [1]</span>
<span class='c'>#&gt;    xml2                    1.3.2      2020-04-23 [1]</span>
<span class='c'>#&gt;    yaml                    2.2.1      2020-02-01 [1]</span>
<span class='c'>#&gt;    zeallot                 0.1.0      2018-01-28 [1]</span>
<span class='c'>#&gt;  source                            </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Github (r-lib/downlit@9191e1f)    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Github (r-lib/hugodown@f7df565)   </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  &lt;NA&gt;                              </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Github (rstudio/rmarkdown@b53a85a)</span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt;  R ── Package was removed from disk.</span></code></pre>

</div>

[The image at the top of this page is in the public domain](https://www.pexels.com/photo/blue-white-orange-and-brown-container-van-163726/).

