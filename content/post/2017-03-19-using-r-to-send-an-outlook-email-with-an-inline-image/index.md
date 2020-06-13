---
title: Using R to send an Outlook email with an inline image
author: ~
date: '2017-03-19'
slug: using-r-to-send-an-outlook-email-with-an-inline-image
categories: []
tags: [R]
description: ''
images: ["/img/sending_an_email_with_rdcomclient.png"]
featuredpath: 'img'
output: hugodown::md_document
rmd_hash: c2bf6750fbd8423d

---

If you work in a corporate environment, there's a good chance you're using Microsoft Office. I wanted to set up a way to email tables and plots from R using Outlook. Sending an email is simple enough with the <a href="http://www.omegahat.net/RDCOMClient/">RDCOMClient</a> library, but inserting a plot inline---rather than as an attachment---took a little bit of working out. I'm sharing my code here in case anyone else wants to do something similar. The trick is to save your plot as an image with a temporary file, attach it to the email, and then insert it inline using a cid (Content-ID).

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='http://ggplot2.tidyverse.org'>ggplot2</a></span>)

<span class='c'># Create a simple scatterplot with ggplo2</span>
<span class='k'>SimplePlot</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggplot.html'>ggplot</a></span>(<span class='k'>mtcars</span>, <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x=<span class='k'>wt</span>, y=<span class='k'>mpg</span>)) <span class='o'>+</span> <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_point.html'>geom_point</a></span>()
<span class='c'># Create a temporary file path for the image that we will attach to our email</span>
<span class='k'>SimplePlot.file</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/tempfile.html'>tempfile</a></span>(fileext = <span class='s'>".png"</span>)
<span class='c'># Save the ggplot we just created as an image with the temporary file path</span>
<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggsave.html'>ggsave</a></span>(plot = <span class='k'>SimplePlot</span>, file = <span class='k'>SimplePlot.file</span>,
        device = <span class='s'>"png"</span>, width = <span class='m'>4</span>, height = <span class='m'>4</span>)

<span class='c'># Create an Outlook object, a new email, and set the parameters.</span>
<span class='k'>Outlook</span> <span class='o'>&lt;-</span> <span class='k'>RDCOMClient</span>::<span class='nf'>COMCreate</span>(<span class='s'>"Outlook.Application"</span>)
<span class='k'>Email</span> <span class='o'>&lt;-</span> <span class='k'>Outlook</span><span class='o'>$</span><span class='nf'>CreateItem</span>(<span class='m'>0</span>)
<span class='k'>Email</span>[[<span class='s'>"To"</span>]] <span class='o'>&lt;-</span> <span class='s'>"johnsmith@example.com"</span>
<span class='k'>Email</span>[[<span class='s'>"subject"</span>]] <span class='o'>&lt;-</span> <span class='s'>"A simple scatterplot"</span>
<span class='c'># Some text before we insert our plot</span>
<span class='k'>Body</span> <span class='o'>&lt;-</span> <span class='s'>"&lt;p&gt;Your scatterplot is here:&lt;/p&gt;"</span>

<span class='c'># First add the temporary file as an attachment.</span>
<span class='k'>Email</span>[[<span class='s'>"Attachments"</span>]]<span class='o'>$</span><span class='nf'>Add</span>(<span class='k'>SimplePlot.file</span>)
<span class='c'># Refer to the attachment with a cid</span>
<span class='c'># "basename" returns the file name without the directory.</span>
<span class='k'>SimplePlot.inline</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>( <span class='s'>"&lt;img src='cid:"</span>,
        <span class='nf'><a href='https://rdrr.io/r/base/basename.html'>basename</a></span>(<span class='k'>SimplePlot.file</span>),
        <span class='s'>"' width = '400' height = '400'&gt;"</span>)
<span class='c'># Put the text and plot together in the body of the email.</span>
<span class='k'>Email</span>[[<span class='s'>"HTMLBody"</span>]] <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>(<span class='k'>Body</span>, <span class='k'>SimplePlot.inline</span>)

<span class='c'># Either display the email in Outlook or send it straight away.</span>
<span class='c'># Comment out either line.</span>
<span class='k'>Email</span><span class='o'>$</span><span class='nf'>Display</span>()
<span class='c'>#Email$Send()</span>

<span class='c'># Delete the temporary file used to attach images.</span>
<span class='nf'><a href='https://rdrr.io/r/base/unlink.html'>unlink</a></span>(<span class='k'>SimplePlot.file</span>)</code></pre>

</div>

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

