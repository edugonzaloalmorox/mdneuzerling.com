---
title: My data science job hunt
author: ''
date: '2019-09-08'
slug: my-data-science-job-hunt
tags:
  - R
  - industry
images: ["/img/job_outcomes.png"]
featuredalt: "job_outcomes"
output: hugodown::md_document
rmd_hash: dd8060b6eecc4a9a

---

If you listen to university advertisements for data science masters degrees, you'd believe that data scientists are so in-demand that they can walk into any company, state their salary, and start work straight away.

Not quite.

Interviewing for data science positions is tough, and job-seekers face some bad behaviour from recruiters and hiring managers. Many companies understand that they need to do *something* with data, but they don't know what. They'll say they want machine learning when they really want a few dashboards. I've fallen for it.

I'm going to put some advice here for anyone about to face the same job market. This is lifted from my own experience, when I was looking for a job a while back.

A few notes about where I was at when I was hunting for this job, in case your circumstances are different: This wasn't my first job, and I understand that fresh graduates can't afford to be as selective as I was. I was specifically looking for something with a machine learning focus. And keep in mind that everything here is written from an Australian perspective.

Advice for job-seekers
======================

### Verify the position description

Simply put, make sure that the job that was advertised is the job that you're interviewing for.

Companies understand that they need to do *something* with data. Machine learning, R, Python, etc. are trendy right now, so sometimes they put these terms into their job requirements without really understanding why. You need to cut through this.

I was once grilled in a phone interview for 20 minutes over my knowledge of random forests and modelling in R. After all that I asked how R or machine learning would be used in the role. Not at all! It turns out the company wanted a candidate with the *capacity* to train a model, but they didn't think it was important that those skills were actually *used*.

Ask some simple questions to test if the position description is genuine. If the advertisement mentions R/Python, ask how R/Python is *currently* used in the team. If the advertisement talks about "advanced analytics" or "machine learning", ask what machine learning models are *currently* in production.

### Focus on what the team is doing now, not their aspirations

Aspirations are good---you wouldn't want to work for a team without them. But while you're waiting for your new team to meet those aspirations your skills are stagnating. This is especially true when talking about machine learning.

Introducing the first machine learning model to an organisation is a huge task. It takes time, and during that time you may not be doing the job you were hired to do. If the implementation of machine learning fails or if there's a restructure and you're moved to a different team, those aspirations won't mean anything.

Make sure that your skills and goals align with the team as it exists now. If your next role must include machine learning, ask about machine learning models currently in use. Listen for phrases like "we're getting into" and "we're hoping to start doing". Don't let them sell you a dream.

There's an exception here if the team you're joining is being spun up solely to focus on machine learning. Otherwise, watch out for the word "transformation".

### Make sure the team can scope analytics work

Analytics teams are inundated with ad hoc requests, and these don't always produce something of substantial value. Some people want cost-benefit analyses, a dashboard to track a metric, or a new report to send up the chain. It takes a talented data professional supported by a strong people leader to sort through these requests and decide what does and doesn't have value.

A bad team will treat this as a prioritisation problem---every request has to be honoured, it's just a matter of working out when. A good team will ask the right questions to determine if there's any value to the task, and **reject** the task if it's low-value. You want to make sure the team you're going to work for is capable of this.

You won't know for sure until you start working there, but here are some things to think about in the interview:

-   How does the team value a piece of analytics work? What questions do they ask their stakeholders to determine this?
-   When a team receives a piece of ad hoc work, where does it go? Is there a backlog, or some sort of sprint planning?
-   Ask the team to estimate what proportion of their work is spent on *long-term* projects.
-   How does the team push back on ad hoc work from a superior?

### Watch out for combination jobs

Job advertisements for "Data Scientist/Data Engineer" or "Data Scientist/Software Developer" stick out as red flags. These are indicators that a company doesn't know what they want in a candidate, so they're hoping to hire a single person to do "all things data".

Obviously there's an exception here for small companies for whom specialisation is a luxury. But any moderately sized company serious about data should be building a team of complementary skills, rather than trying to hire an "all-in-one" candidate.

A word of advice to companies out there who think they need to take this approach to hiring: work out which part of the job is more important, and move the other part to the body of the advertisement. Rather than a "Data Scientist/Software Developer", advertise for a Data Scientist, but point out that some software development experience would be viewed favourably. Bonus points if you can explain why those skills matter for the role!

I can't imagine that there are too many people out there who can confidently bill themselves as experienced data scientists and experienced software developers. I hope they're paid well.

### Respect yourself

Some companies forget that recruitment is a two-sided process. Faced with more candidates than time, they can implement hiring practices that range from pointless to demeaning, or even downright illegal. I experienced:

-   Pre-recorded video interviews, in which I was asked to record my answer to a question and send it in to be reviewed later.
-   One-hour handwritten exams, in which I was asked to write code and even specify a logistic regression from memory.
-   Questions about my "family situation".

**In each of these situations I walked away from the role**. But I was in a position in which I could walk away. If you've got rent to pay then you may have to subject yourself to bad hiring practices, and you shouldn't be shamed for that.

Some advice to employers: handwritten code tests are only acceptable if handwritten code is a big part of the role. Handwritten code should never be a big part of the role, so handwritten code tests are never acceptable.

There are some great companies out there
========================================

Don't think that it's all bad. Some companies out there are doing truly amazing stuff with data. Some of the projects I heard were innovative, interesting, and not evil!

The good jobs are out there. After all, I've got one now!

The alluvial graph
==================

The graph at the top of this post is real data from my job hunt. You can track each application from its source to its outcome. "Ghosted" means that I received no response from the company. I strongly recommend some sort of tracking tool for your own job hunt---it's therapeutic.

If you'd like to reproduce the graph above for your own job hunt, the code is below, and the (censored) data is available [here](/data/job_outcomes.csv).

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='http://tidyverse.tidyverse.org'>tidyverse</a></span>)
<span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='http://corybrunson.github.io/ggalluvial'>ggalluvial</a></span>)

<span class='c'># Colours by Dr. Katie Lotterhos</span>
<span class='c'># http://dr-k-lo.blogspot.com/2013/07/a-color-blind-friendly-palette-for-r.html</span>

<span class='s'>"job_outcomes.csv"</span> <span class='o'>%&gt;%</span> 
    <span class='k'>read_csv</span> <span class='o'>%&gt;%</span>
    <span class='nf'>mutate</span>(final_outcome = <span class='nf'>coalesce</span>(<span class='k'>outcome</span>, <span class='k'>`2nd stage`</span>, <span class='k'>`1st stage`</span>)) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/pkg/ggalluvial/man/ggalluvial-deprecated.html'>to_lodes</a></span>(key = <span class='s'>"contact"</span>, axes = <span class='m'>2</span><span class='o'>:</span><span class='m'>5</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>ggplot</span>(<span class='nf'>aes</span>(x = <span class='k'>contact</span>, stratum = <span class='k'>stratum</span>,
                  alluvium = <span class='k'>alluvium</span>, label = <span class='k'>stratum</span>)) <span class='o'>+</span> 
    <span class='nf'><a href='https://rdrr.io/pkg/ggalluvial/man/geom_alluvium.html'>geom_alluvium</a></span>(<span class='nf'>aes</span>(fill = <span class='k'>final_outcome</span>), color = <span class='s'>"darkgrey"</span>, na.rm = <span class='kc'>TRUE</span>) <span class='o'>+</span>
    <span class='nf'><a href='https://rdrr.io/pkg/ggalluvial/man/geom_stratum.html'>geom_stratum</a></span>(na.rm = <span class='kc'>TRUE</span>) <span class='o'>+</span>
    <span class='nf'>geom_text</span>(stat = <span class='s'>"stratum"</span>, na.rm = <span class='kc'>TRUE</span>, size = <span class='m'>12</span> <span class='o'>*</span> <span class='m'>0.352778</span>) <span class='o'>+</span> <span class='c'># convert pt to mm</span>
    <span class='nf'>theme</span>(
        axis.text.y = <span class='nf'>element_blank</span>(),
        axis.ticks.y = <span class='nf'>element_blank</span>(),
        text = <span class='nf'>element_text</span>(size = <span class='m'>16</span>)
    ) <span class='o'>+</span>
    <span class='nf'>xlab</span>(<span class='kr'>NULL</span>) <span class='o'>+</span>
    <span class='nf'>labs</span>(fill = <span class='s'>"final outcome"</span>) <span class='o'>+</span> <span class='c'># legend title </span>
    <span class='nf'>scale_fill_manual</span>(values = <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(
        <span class='s'>"ghosted"</span> = <span class='s'>"#F0E442"</span>,
        <span class='s'>"no role"</span> = <span class='s'>"#CC79A7"</span>,
        <span class='s'>"withdrew"</span> = <span class='s'>"#0072B2"</span>,
        <span class='s'>"rejected"</span> = <span class='s'>"#D55E00"</span>,
        <span class='s'>"offer"</span> = <span class='s'>"#009E73"</span>
    )) </code></pre>

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

