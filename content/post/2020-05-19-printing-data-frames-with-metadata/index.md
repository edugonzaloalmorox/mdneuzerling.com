---
title: Printing data frames with metadata
author: ~
date: '2020-05-19'
slug: printing-data-frames-with-metadata
tags:
    - R
images: ["/img/flinders-departures.png"]
featuredalt: "A tibble of train departures from Flinders Street station"
output: hugodown::md_document
rmd_hash: 5d8f9bd540fd9e35

---

I'm creating an R API wrapper around my state's public transport service. To make life easier for the users, the responses from the API calls are parsed and returned as tibbles/data frames. To make life easier for me, I need to keep track of the API call behind each tibble. I do this by using the [`tibble::new_tibble()`](https://tibble.tidyverse.org/reference/new_tibble.html) function to attach metadata to the tibble as attributes, and creating a custom `print` method to make the metadata visible.

First, the raw response from the API call is structured as a list:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>response</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/list.html'>list</a></span>(
    request = <span class='k'>request_url_without_auth</span>,
    retrieved = <span class='nf'><a href='https://rdrr.io/r/base/format.html'>format</a></span>(
      <span class='nf'><a href='https://rdrr.io/r/base/Sys.time.html'>Sys.time</a></span>(),
      format = <span class='s'>"%Y-%m-%d %H:%M:%OS %Z"</span>,
      tz = <span class='s'>"Australia/Melbourne"</span>
    ),
    status_code = <span class='k'>status_code</span>,
    content = <span class='k'>content</span>
)</code></pre>

</div>

Some other function will take the content in this list, process it, and create a `parsed` tibble. We hand this off to the [`tibble::new_tibble()`](https://tibble.tidyverse.org/reference/new_tibble.html) function. Along with the new class name --- "ptvapi" --- we also attach the `response` metadata as attributes to the new tibble.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>tibble</span>::<span class='nf'><a href='https://tibble.tidyverse.org/reference/new_tibble.html'>new_tibble</a></span>(
    <span class='k'>parsed</span>,
    nrow = <span class='nf'><a href='https://rdrr.io/r/base/nrow.html'>nrow</a></span>(<span class='k'>parsed</span>),
    class = <span class='s'>"ptvapi"</span>,
    request = <span class='k'>response</span><span class='o'>$</span><span class='k'>request</span>,
    retrieved = <span class='k'>response</span><span class='o'>$</span><span class='k'>retrieved</span>,
    status_code = <span class='k'>response</span><span class='o'>$</span><span class='k'>status_code</span>,
    content = <span class='k'>response</span><span class='o'>$</span><span class='k'>content</span>
  )</code></pre>

</div>

Let's say we have a tibble `flinders_departures` created through this process. `flinders_departures` will have the following classes, in order: "ptvapi", "tbl\_df", "tbl", and "data.frame".

For those who are unfamiliar to S3, some functions in R --- like [`print()`](https://rdrr.io/r/base/print.html), [`summary()`](https://rdrr.io/r/base/summary.html) and [`predict()`](https://rdrr.io/r/stats/predict.html) --- are *generics*. When we call a generic, R will look through the classes of the argument to find the right *method* to call. When we call [`print(flinders_departures)`](https://rdrr.io/r/base/print.html) (or, equivalently, enter `flinders_departures` at the console) R will first look for the `print.ptvapi()` method. If it can't find that, it will move on to `print.tbl_df()`, and so on, until it tries [`print.default()`](https://rdrr.io/r/base/print.default.html).

If I were to let R go through this method I would print `flinders_departures` without printing the metadata. So I created a simple way of printing out those attributes:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>print.ptvapi</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) {
  <span class='kr'>if</span> (<span class='o'>!</span><span class='nf'><a href='https://rdrr.io/r/base/NULL.html'>is.null</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/attr.html'>attr</a></span>(<span class='k'>x</span>, <span class='s'>"request"</span>))) {
    <span class='nf'><a href='https://rdrr.io/r/base/cat.html'>cat</a></span>(<span class='s'>"Request:"</span>, <span class='nf'><a href='https://rdrr.io/r/base/attr.html'>attr</a></span>(<span class='k'>x</span>, <span class='s'>"request"</span>), <span class='s'>"\n"</span>)
  }
  <span class='kr'>if</span> (<span class='o'>!</span><span class='nf'><a href='https://rdrr.io/r/base/NULL.html'>is.null</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/attr.html'>attr</a></span>(<span class='k'>x</span>, <span class='s'>"retrieved"</span>))) {
    <span class='nf'><a href='https://rdrr.io/r/base/cat.html'>cat</a></span>(<span class='s'>"Retrieved:"</span>, <span class='nf'><a href='https://rdrr.io/r/base/attr.html'>attr</a></span>(<span class='k'>x</span>, <span class='s'>"retrieved"</span>), <span class='s'>"\n"</span>)
  }
  <span class='kr'>if</span> (<span class='o'>!</span><span class='nf'><a href='https://rdrr.io/r/base/NULL.html'>is.null</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/attr.html'>attr</a></span>(<span class='k'>x</span>, <span class='s'>"status_code"</span>))) {
    <span class='nf'><a href='https://rdrr.io/r/base/cat.html'>cat</a></span>(<span class='s'>"Status code:"</span>, <span class='nf'><a href='https://rdrr.io/r/base/attr.html'>attr</a></span>(<span class='k'>x</span>, <span class='s'>"status_code"</span>), <span class='s'>"\n"</span>)
  }
  <span class='nf'><a href='https://rdrr.io/r/base/UseMethod.html'>NextMethod</a></span>()
}</code></pre>

</div>

This method will print out the attributes if they exist. [`NextMethod()`](https://rdrr.io/r/base/UseMethod.html) will then make R go down the class chain, until it prints like a regular tibble. This is great for debugging. The response of the API call is (more or less) determined by the three attributes I specifically print. So it makes life much easier for me to be able relate the parsed tibble to the API response.

    > flinders_departures
    Request: http://timetableapi.ptv.vic.gov.au/v3/departures/route_type/0/stop/1071?max_results=5&date_utc=2020-05-18T12:14:10&include_cancelled=false 
    Retrieved: 2020-05-18 22:14:11 AEST 
    Status code: 200 
    # A tibble: 75 x 11
       direction_id stop_id route_id run_id platform_number at_platform departure_seque…
              <int>   <int>    <int>  <int> <chr>           <lgl>                  <int>
     1            5    1071        6 952531 9               FALSE                      0
     2            2    1071        3 953881 5               FALSE                      0
     3           13    1071       14 954655 4               FALSE                      0
     4            6    1071        7 950675 2               FALSE                      0
     5            9    1071        5 949763 1               FALSE                      0
     6           16    1071       17 954539 9               FALSE                      0
     7           11    1071       12 988175 13              FALSE                      0
     8           10    1071       11 952689 6               FALSE                      0
     9            8    1071        9 951849 3               FALSE                      0
    10           14    1071       15 953653 4               FALSE                      0
    # … with 65 more rows, and 4 more variables: scheduled_departure <dttm>,
    #   estimated_departure <dttm>, flags <chr>, disruption_ids <list>

Most importantly, because I haven't defined any methods like `mutate.ptvapi()`, every generic other than [`print()`](https://rdrr.io/r/base/print.html) will treat this tibble as a tibble. So all of my data manipulation functions will ignore the metadata I've attached to this tibble.

A quick heads up: it's not guaranteed that every function will preserve attributes. So after manipulation, the "ptvapi" class may be lost, along with the metadata. That's fine for my purpose, but maybe not for yours.

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
<span class='c'>#&gt;  date     2020-06-14                  </span>
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
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-06-12 [1] Github (r-lib/downlit@87fb1af)    </span>
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

