---
title: Model as a package
author: ''
date: '2019-12-11'
slug: model-as-a-package
tags:
    - R
images: ["/img/ModelAsAPackage.png"]
featuredalt: "Word cloud of review text"
output: hugodown::md_document
rmd_hash: 88295f1b09e321e6

---

There's a concept in R of an [analysis as a package](https://www.r-bloggers.com/creating-an-analysis-as-a-package-and-vignette), in which everything you need for your data analysis is contained within a custom package. When you install the package and build the vignettes, the data analysis is performed and results saved as a pretty HTML or PDF file, generated with R Markdown. I wanted to extend this concept to a machine learning **model as a package**.

The idea here is that, using vignettes, we can make equivalent installing a package with training a model. The functions in the package can be used in model training or for scoring new data, probably with some overlap. To demonstrate this I've created a simple sentiment analysis model based on [review data from the UCI Machine Learning Repository](https://archive.ics.uci.edu/ml/datasets/Sentiment+Labelled+Sentences).

[You can check out the repository for the model/package here](https://github.com/mdneuzerling/ModelAsAPackage). I've also copied [the output of the vignette](/rmd/ModelAsAPackage.html) so you can see what's knitted when the package is installed. You can install this package with [`devtools::install_github("mdneuzerling/ModelAsAPackage", build_vignettes = TRUE)`](https://devtools.r-lib.org//reference/remote-reexports.html). The package can be loaded and attached as any other package would be and the training vignette opened with `vignette("model-training", package = "ModelAsAPackage")`.

Want to see the (not-so-great) model score some text? Try giving an argument to the `sentiment` function. I'm happy to report that `sentiment("love") == "good"`.

I thought this might work because of a few things:

-   Vignettes are created before the source code is bundled, so in theory we can train a model before the package has finished compiling.
-   R uses lazy evaluation, so if a package function refers to an object that doesn't yet exist (because it hasn't been created by the vignette) that's okay.
-   I like using the same functions for model training as I do for model scoring, like the `map_to_dtm` function in this package.
-   I wanted to take full advantage of `roxygen2` for documenting package functions, and `testthat` for unit tests. I especially like the ease with which you can test within RStudio.

However, I have my doubts:

-   In order for tests to work, I have to run [`devtools::build_vignettes`](https://devtools.r-lib.org//reference/build_vignettes.html) before running [`devtools::install`](https://devtools.r-lib.org//reference/install.html). There's something here with namespaces whereby the data objects suddenly become "unexported" after tests are attempted. I don't know why!
-   There are some relative paths in the code. I'm assuming that the working directory is `<package_root>/vignettes` when this vignette is knitted, so I can move up one level to obtain the root directory of the package. This should be okay if we're following the standard package structure, but I've been hurt too many times by relative file paths to feel comfortable about this.
-   I'm not sure how this would operate with the `plumber` package. I don't know if we can integrate the expected `plumber.R` function in the package, except for sticking it in the `inst` directory and then finding it with `system.file`.
-   This all seems like a lot of complexity for not too much benefit. Maybe doing this again would be easier now that I have a template.

These sorts of projects should be shared, even if I don't think that this is a major success!

A quick shout out for [the excellent book on R packages by Hadley Wickham](http://r-pkgs.had.co.nz/). It's well worth keeping bookmarked.

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
<span class='c'>#&gt;  date     2020-06-13                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib source                            </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports     1.1.7      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.4.0      2019-10-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-06-12 [1] Github (r-lib/hugodown@6812ada)   </span>
<span class='c'>#&gt;  knitr         1.28       2020-02-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  pkgbuild      1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.4.6    2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.2.3      2020-06-12 [1] Github (rstudio/rmarkdown@4ee96c8)</span>
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

