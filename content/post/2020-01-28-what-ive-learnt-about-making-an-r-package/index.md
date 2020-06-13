---
title: What I've learnt about making an R package
author: ''
date: '2020-01-28'
slug: what-ive-learnt-about-making-an-r-package
categories: []
tags:
    - R
images: ["/img/boxes.jpg"]
featuredalt: "Two small stacked carboard boxes stacked. This image is used under the Simplified Pixabay License."
output: hugodown::md_document
rmd_hash: 5396e888d442b2cc

---

The last few weeks have been all about R package development for me. First I was exploring GitHub actions with the lovely people at the [rOpenSci OzUnconf](https://ozunconf19.ropensci.org/), and then I was off to San Francisco to learn about [Building Tidy Tools with the Wickham siblings](https://github.com/rstudio-conf-2020/build-tidy-tools). I've picked up a lot about package development, so I'm documenting some of trickier things that I've learnt.

A great resource for package development is [Hadley's book](http://r-pkgs.had.co.nz/). Check it out.

General hints
-------------

-   [There's a difference between *attaching* and *loading* a package](http://r-pkgs.had.co.nz/namespace.html). Attaching a package also loads it, and this is what happens when you run the `library` function.
    -   I've heard it claimed before that it's inefficient to use double colons like [`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html) because R "loads the package every time". That's not true. R loads the package on the first use of a double colon function, but doesn't attach it. For every call afterwards, that package has *already been loaded*.
-   Running [`devtools::check()`](https://devtools.r-lib.org//reference/check.html) (as opposed to `R CMD CHECK`) will automatically run [`devtools::document()`](https://devtools.r-lib.org//reference/document.html) before the package check *if devtools can see that you're using Roxygen*. This isn't always obvious for a brand new package, so I found that I had to run [`devtools::document()`](https://devtools.r-lib.org//reference/document.html) initially. After that first command, however, [`devtools::check()`](https://devtools.r-lib.org//reference/check.html) started documenting.
-   Use the `@keywords internal` Roxygen tag for documented internal functions, that is, functions without an `@export` tag. This [partially hides the documentation from regular users](http://r-pkgs.had.co.nz/man.html), while still allowing interested users and developers to access it. [Thank you to the \#rstats Twitter for helping me out with this one!](https://twitter.com/mdneuzerling/status/1219402128722137089)
-   If you want to skip the portion of a package check where R connects to CRAN (because you're behind a proxy or you don't have an internet connection) run [`rcmdcheck::rcmdcheck(repos = FALSE)`](https://rdrr.io/pkg/rcmdcheck/man/rcmdcheck.html). This lets you continue package development on planes.
-   When you use a function like `mutate(mtcars, kph = 0.425144 * mpg)`, the package check will complain because it's expecting to see `mtcars` and `mpg` as global variables. It's just a note so you can ignore it, but if you're like me and interpret notes in package checks as personal attacks, then this [StackExchange post](https://stackoverflow.com/questions/9439256/how-can-i-handle-r-cmd-check-no-visible-binding-for-global-variable-notes-when) post has some options.
    -   Personally, I just add [`utils::globalVariables(c("mtcars", "mpg"))`](https://rdrr.io/r/utils/globalVariables.html) to a `globals.R` file in my `R` folder. If there's a chance someone else will be looking at your source code, you should add a (non-Roxygen) comment explaining why so they don't get confused.
-   If you're creating a custom package for a **specific** data set, I recommend creating a `download_data` function that creates the `inst/extdata` folder and downloads the external data only if it doesn't already exist. You can add `inst/extdata` to your `.gitignore`. This means that you can host your source code but not your data (which may be quite large) on git, without having to worry about doing multiple redundant downloads. This will also let you delete your R Markdown cache without deleting your local data.

Managing dependencies
---------------------

-   If your package uses another package, add it to your DESCRIPTION file with [`usethis::use_package(package)`](https://usethis.r-lib.org/reference/use_package.html). By default, this will add the package to the "Imports" section. This is *probably* what you want, but you can put it in another section by changing the `type` argument in `use_package` to "Depends" or "Suggests".
    -   "Imports" in the DESCRIPTION file is **not** the same as "Imports" in the NAMESPACE file. The DESCRIPTION file doesn't really "import" anything in the namespace sense --- it just tells R that those packages should be installed.
-   Once you've added a package to your DESCRIPTION file, you can use it in your functions in one of three ways. They are, **in order of preference** (Thank you to Hadley for confirming this at the workshop):
    1.  Use a double colon like [`dplyr::mutate`](https://dplyr.tidyverse.org/reference/mutate.html). This is the preferred option since it doesn't change the namespace of your package.
    2.  Add a Roxygen tag `@ImportFrom`, such as `@ImportFrom dplyr mutate`. This adds the `mutate` function to the namespace available to your package functions without anything else from the `dplyr` package. This allows you to use `mutate` by itself in your package functions. Because this only adds a single function at a time, you're unlikely to encounter a namespace collision (two objects with the same name in the namespace).
    3.  Add a Roxygen tag `@Import`, such as `@Import dplyr`. This adds every function in the `dplyr` package to the namespace available to your package functions. This isn't recommended because it makes it very easy to run into a namespace collision.
        -   Something Hadley said: it's okay to do this if you're running a package that's been *explicitly designed* to be imported in this manner. For example, tidyverse functions import the entire `rlang` namespace. It's also more acceptable to do this if you're only importing the entire namespace of a *single* package, since that's unlikely to lead to conflicts.
-   You can use the same `@Import` or `@ImportFrom` multiple times, and Roxygen will only add it once to the NAMESPACE. I like to keep my dependencies close to the functions that use them, so if I need a pipe in many functions I'll put `@ImportFrom magrittr %>%` in each file. That's just my personal preference, though.
-   Once you've added either an `@ImportFrom` or `@Import` tag, you need to [`devtools::document()`](https://devtools.r-lib.org//reference/document.html) for the change to take effect. This will add the relevant lines to your NAMESPACE file. [`devtools::check()`](https://devtools.r-lib.org//reference/check.html) will usually do this for you.
    -   This often catches me out if I change the NAMESPACE through a Roxygen tag and then re-install the package without running [`devtools::check()`](https://devtools.r-lib.org//reference/check.html). I get frustrated that my changes aren't taking effect, until I realise my mistake!
-   The `base` package never needs to be explicitly referred to or mentioned in your DESCRIPTION file.
    -   You *do* need to explicitly refer to functions and objects from the `utils` and `stats` packages, eg. [`stats::var(c(2, 3, 3, 3, 4))`](https://rdrr.io/r/stats/cor.html), and put them in your DESCRIPTION file.
-   Packages used in your vignettes that are not used in your package itself should go in the "Suggests" portion of your namespace, eg. [`usethis::use_package("ggplot2", type = "Suggests")`](https://usethis.r-lib.org/reference/use_package.html).

Importing S3 methods
--------------------

There's something that still confuses me. Let me preface this by saying that I'm not going to pretend to understand S3.

Suppose that one of your dependencies uses an S3 method for a generic. For example, the `randomForest` package has an (unexported) `predict.randomForest` S3 method that allows you to make predictions with new data using the `predict` generic. How do you deal with that dependency without importing the whole `randomForest` namespace?

I created a quick package to test this out. [You can find it on GitHub](https://github.com/mdneuzerling/ImportingRandomForest).

The option I went with here is to call on the internal function directly: `randomForest:::predict.randomForest()`. This works, but you'll get a note because you're generally not supposed to use [`:::`](https://rdrr.io/r/base/ns-dblcolon.html) in functions. If you're submitting to CRAN, this could be an issue. Here are the results of `R CMD CHECK`:

    ── R CMD check results ─────────────────── ImportingRandomForest 0.0.0.9000 ────
    Duration: 11.3s

    ❯ checking dependencies in R code ... NOTE
      Unexported object imported by a ':::' call: ‘randomForest:::predict.randomForest’
        See the note in ?[`:::`](https://rdrr.io/r/base/ns-dblcolon.html) about the use of this operator.

    0 errors ✔ | 0 warnings ✔ | 1 note ✖

Alternatively, the [`stats::predict`](https://rdrr.io/r/stats/predict.html) generic seems to work with the Roxygen tag `@importFrom randomForest randomForest`. I feel like this is a fluke --- the S3 method is imported as a consequence of importing the `randomForest` function, but it's not clear that this is happening. Similarly, `@importMethodsFrom randomForest predict.randomForest` seems to work, even though R throws a warning that it couldn't find the method.

I'd welcome any thoughts on this!

------------------------------------------------------------------------

<sub><sup>The featured image for this post is from [pixabay](https://pixabay.com/photos/boxes-cardboard-gift-box-3404606/), and is used under the [Simplified Pixabay License](https://pixabay.com/service/license/).</sup></sub>

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

