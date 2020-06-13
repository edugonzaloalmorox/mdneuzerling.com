---
title: 'useR: The Week in Review'
author: ''
date: '2018-07-13'
slug: user-the-week-in-review
categories: []
tags: [R, conference]
images: ["/img/useR/week_in_review.png"]
featuredalt: "useR2018 Week in Review"
output: hugodown::md_document
rmd_hash: ad077c06664f76d6

---

That's it for \#useR2018. After 6 keynotes, 132 parallel sessions, many more lightning talks and posters, and an all-important conference dinner, we've reached the end of the week.

This was my first proper conference since 2015. I had almost forgotten how it felt to be surrounded by hundreds of people who are just as passionate (if not more) about your tiny area of specialised knowledge than you are.

I took notes for the three tutorials I went to, but I wanted to take a moment to review the week as a whole, including the talks that stood out to me. You can find my tutorial notes below:

-   [Tutorial one: Getting Started with R and Docker](/post/user-getting-started-with-r-and-docker/)
-   [Tutorial two: Recipes for Data Processing](/post/user-recipes-for-data-processing/)
-   [Tutorial three: Missing Values Imputation](/post/user-missing-values-imputation/)

All talks and tutorials were recorded, so keep an eye out for them on the [useR2018 site](https://user2018.r-project.org/). The \#rstats community is active on Twitter, so check out the [\#useR2018](https://twitter.com/search?q=%23useR2018) hashtag as well.

![The famous \#hexwall, with [Adam Gruer](https://twitter.com/AdamGruer)](img/hexwall.jpg)

A quick personal note
---------------------

I'd like to declare my own biggest success and biggest failure of the conference:

-   **Biggest personal win**: I posted notes from each of the three tutorials I went to! This forced me to learn more about PCA, which is a big win.
-   **Biggest personal not-win**: I didn't present anything. I told myself this was because I had nothing to present, but I'm not so sure that's true.

Talk highlights
---------------

-   [Steph de Silva](https://twitter.com/StephdeSilva) spoke of R as not just a language but a *community*. And in this community you go from seeing R as something you use to seeing R as something you share. The R subculture(s) have real power to contribute in a world where data affects decisions.
-   [Rob Hyndman](https://twitter.com/robjhyndman)'s new `fable` package looks super easy to use. It's a tidyverse-compatible replacement for his extremely popular `forecast` package. He calls it "fable" because "fables aren't true but they tell you something useful about reality, just like a forecast."
-   [Thomas Lin Pedersen](https://twitter.com/thomasp85) is rewriting the `gganimate` package and it looks *so cool*. He described visualisation as existing on a spectrum between static, interactive, and animated. Traditional media (eg. newspapers) use static visualisation and modern journalism websites use interactive visualisation, but animated visualisation is often found in social media.

<div class="highlight">

<!--html_preserve-->
{{% tweet "1014132180853903360" %}}<!--/html_preserve-->

</div>

-   [Katie Sasso](https://twitter.com/KatieSasso) introduced **standalone Shiny applications** using Electron. I am so keen to try these out! Imagine being able to distribute a Shiny app to someone without them needing to so much as install R.
-   [Nicholas Tierney](https://twitter.com/nj_tierney)'s `maxcovr` package makes it easier to solve the [maximal coverage location problem](https://en.wikipedia.org/wiki/Maximum_coverage_problem) in R. His choice of example was apt. Brisbane offers free public wifi in and around the CBD, and the `maxcovr` package can be used to identify optimal placemennt of new routers to improver the coverage population and area.
-   [Roger D. Peng](https://twitter.com/rdpeng) spoke about the teaching R. I loved the quote from John Chambers on S (R's predecessor): "We wanted users to begin in an interactive environment, where they did not consciously think of themselves as programming... they should be able to slide gradually into programming." This is the R value proposition in a nutshell for me: you don't *have* to jump into the developer side of things, but if you want to start going down that path it's a gradual transition.

<div class="highlight">

<!--html_preserve-->
{{% tweet "1017552963861037056" %}}<!--/html_preserve-->

</div>

-   [Jenny Bryan](https://twitter.com/JennyBryan) spoke about code smells and feels. Whenever I read something cool and useful about R I look at the author and there's a good chance it's Jenny. I like that the advice in her talk is more "use this in moderation" rather than the prescriptive "Don't do this".
-   [Danielle Navarro](https://twitter.com/djnavarro) shared her experience in teaching R to psychology students. This one resonated, especially with her emphasis on student fear. Student fear stops learning before it can begin!
-   [Martin Mächler](https://twitter.com/MMaechler) of the R Core team discussed an often-neglected topic: numerical precision. It was a chance to get into the guts of R. He also gave the following bizarre example:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/unique.html'>unique</a></span>((<span class='m'>1</span><span class='o'>:</span><span class='m'>10</span>)<span class='o'>/</span><span class='m'>10</span> <span class='o'>-</span> (<span class='m'>0</span><span class='o'>:</span><span class='m'>9</span>)<span class='o'>/</span><span class='m'>10</span>)
<span class='c'>#&gt; [1] 0.1 0.1 0.1 0.1</span></code></pre>

</div>

> "10.0 times 0.1 is hardly ever 1.0" - *The Elements of Programming Style* by Brian W. Kernighan and P. J. Plauger

Wrapping up
-----------

Thank you to the organisers and to everyone who contributed to the conference.

I met a tonne of people here and I can't mention everyone. Thank you to the following people for existing and for making my \#useR2018 experience extra-special: [Adam Gruer](https://twitter.com/AdamGruer), [Dale Maschette](https://twitter.com/Dale_Masch), [Emily Kothe](https://twitter.com/emilyandthelime), [John Ormerod](https://twitter.com/john_t_ormerod), [Steph de Silva](https://twitter.com/StephdeSilva), [Charles T. Gray](https://twitter.com/cantabile), and [Ben Harrap](https://twitter.com/BHarrap).

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
<span class='c'>#&gt;  blogdown      0.19       2020-05-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  broom         0.5.6      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cellranger    1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  colorspace    1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DBI           1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dbplyr        1.4.3      2020-04-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-06-12 [1] Github (r-lib/downlit@87fb1af)    </span>
<span class='c'>#&gt;  dplyr       * 0.8.5      2020-03-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forcats     * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics      0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggplot2     * 3.3.0      2020-03-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gtable        0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  haven         2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.4.0      2019-10-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httr          1.4.1      2019-08-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-06-12 [1] Github (r-lib/hugodown@6812ada)   </span>
<span class='c'>#&gt;  jsonlite      1.6.1      2020-02-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr         1.28       2020-02-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice       0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lubridate     1.7.8      2020-04-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  modelr        0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  munsell       0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  nlme          3.1-145    2020-03-04 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pillar        1.4.4      2020-05-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild      1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr       * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.4.6    2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr       * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readxl        1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reprex        0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.2.3      2020-06-12 [1] Github (rstudio/rmarkdown@4ee96c8)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rstudioapi    0.11       2020-02-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rvest         0.3.5      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  scales        1.1.0      2019-11-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr     * 1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble      * 3.0.1      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyr       * 1.0.2      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect    1.0.0      2020-01-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyverse   * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs         0.3.1      2020-06-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.14       2020-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xml2          1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

