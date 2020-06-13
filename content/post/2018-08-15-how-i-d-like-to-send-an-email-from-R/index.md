---
title: How I'd like to send an email from R
author: ''
date: '2018-08-15'
slug: how-i-d-like-to-send-an-email-from-R
categories: []
tags:
  - R
images: ["/img/pipes.jpeg"]
featuredalt: "pipes"
output: hugodown::md_document
rmd_hash: d1668828e25cdf84

---

When I found myself using R in a corporate environment, my workflow went like this:

1.  Connect to databases
2.  Do stuff to data
3.  **Email** results

Yes, there exist options for presenting results that are a bit more modern than the old-fashioned email---R Markdown, Shiny, or even Slack, for example. But email is embedded in corporate culture and will be around for a long time to come.

I want to set down how I think a `send_email` function should work in R.

But we can already send emails in R
-----------------------------------

Just sending an email is nothing new. There's the [`sendmailR`](https://cran.r-project.org/web/packages/sendmailR/index.html) and [`mailR`](https://cran.r-project.org/web/packages/mailR/index.html) packages, for example. These use the SMTP protocol. Then there's the `gmailr` package, which connects to gmail's REST API to send (and receive) mail. I've played around with doing the same for Outlook (`outlookr`, anyone?), which also covers the Office365 environment found almost ubiquitously in older corporate environments.

My first attempt to improving my workflow used none of that. I used [Duncan Temple Lang 's `RDCOMClient`](https://github.com/omegahat/RDCOMClient) (also available on [GitHub](https://github.com/omegahat/RDCOMClient)) to connect to a locally installed copy of Microsoft Outlook. This package allows R to connect to the DCOM architecture. You can think of DCOM as an API for communicating with Microsoft Office in Windows environments.

I'll talk about the benefits and drawbacks of DCOM later, but the main appeal for me is that I can connect R to the Outlook application installed on my (Windows) computer, and let Outlook handle all of that super tricky authentication nonsense. This was the appeal for me---no passwords or OAuth keys, because that stuff is all too *hard*.

For my use case, I wanted to send things like reports and alerts. That meant sending ggplots and data frames, not as attachments but *in the body of the email*. With a lot of help from StackExchange, I worked out how to do this with `RDCOMClient`. I wanted to do more than just *send an email in R*. I wanted emailing from within R to feel like a natural extension of the language.

The prototype: `RDCOMOutlook`
-----------------------------

I've been playing around with `RDCOMClient` [for a while](/post/using-r-to-send-an-outlook-email-with-an-inline-image/). It was even responsible for my first StackExchange answer. But all of stuff I had learnt was scattered across a dozen stray R scripts. So I spent a week turning everything I had done with `RDCOMClient` into a package called `RDCOMOutlook`, available on [GitHub](https://github.com/mdneuzerling/RDCOMOutlook).

I want to be clear here: this package is a proof-of-concept, and I have no plans to develop it any futher. I'm not submitting it to CRAN, especially since `RDCOMClient` itself is no longer available on CRAN. But developing the package helped me realise what I wanted a `send_email` function to look like.

Actually, in `RDCOMOutlook` it's called `prepare_email`. You can do this thing with DCOM where you get the email to pop up on the user's screen without immediately sending. I thought that was cool, and I made it the default behaviour, with a `send` argument as an option.

The prototype: `prepare_email`
------------------------------

Here's the head of the `prepare_email` function in `RDCOMOutlook`:

    prepare_email <- function(
        embeddings = NULL,
        body = "",
        to = "",
        cc = "",
        subject = "",
        attachments = NULL,
        css = "",
        send = FALSE,
        data_file_format = "csv",
        image_file_format = "png"
    )

You can see some expected stuff in there. Emails have bodies, subjects, recipients and (optionally) cc'd recipients and attachments. These arguments are natural and expected. These are HTML emails, so you can even use some custom CSS (I used this to put some company colours into my reports). None of the arguments are required; running `prepare_email()` causes a blank Outlook composition window to pop up on the user's screen.

But `embeddings`, `data_file_format` and `image_file_format` are a bit weirder. And `embeddings` is the *first* argument. The first argument in an R function is in a privileged position, because that's the default target for the pipe (`%>%`).

Here's what happens when you give object `obj` to the `embeddings` argument:

1.  If `obj` is a ggplot, it will be embedded into the **body** of the email as a resonably sized image.
2.  If `obj` is a data frame or tibble, it will be converted into a HTML table and embedded into the body of the email.
3.  If `obj` is a file path pointing to an image file, it will be embedded into the body of the email.
4.  If `obj` is a file path pointing to a file that isn't an image, it will be passed to the `attachments` argument.
5.  Failing all of that, an error is thrown: `obj is not a ggplot, data frame,  tibble or valid file path. Check that the file exists.`

A benefit of `DCOM` is that you can get the user's email signature as defined in Outlook. So I put the embedding between the provided `body` and the signature.

The `attachments` argument follows similar logic, except it will attach a plot or data frame/tibble. This is where the file format arguments come into play. I like `data_file_format`---you might want to send an Excel file, for example. But I think we can do without the `image_file_format` argument. Does anyone really care if their image is a jpeg or a png?

What happens in the background?
-------------------------------

To embed or attach a ggplot, we need to save it as a file in a temporary location. We attach the file and---if we're embedding it---refer to the file name in an HTML tag using a *content identifider (cid)*. This tells the email client that it needs to show the attachment in the body of the email.

When I first tried to do this I got some warped ggplots. You need to specify image dimensions in HTML, but that means *getting* the image dimensions. The `readbitmap` package is crucial here, since it lets me inspect the most commonly used image formats.

At one point, I was inspecting file headers to try to guess the image format!

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>file_header</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/readBin.html'>readBin</a></span>(<span class='k'>file_path</span>, <span class='s'>"raw"</span>, n = <span class='m'>8</span>)

<span class='c'># Reference headers</span>
<span class='k'>png_header</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/raw.html'>as.raw</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/strtoi.html'>strtoi</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"89"</span>, <span class='s'>"50"</span>, <span class='s'>"4e"</span>, <span class='s'>"47"</span>, <span class='s'>"0d"</span>, <span class='s'>"0a"</span>, <span class='s'>"1a"</span>, <span class='s'>"0a"</span>), <span class='m'>16</span>))
<span class='k'>jpg_header</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/raw.html'>as.raw</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/strtoi.html'>strtoi</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"FF"</span>, <span class='s'>"D8"</span>), <span class='m'>16</span>))
<span class='k'>bmp_header</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/raw.html'>as.raw</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/strtoi.html'>strtoi</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"42"</span>, <span class='s'>"4D"</span>), <span class='m'>16</span>))
<span class='k'>gif_header</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/raw.html'>as.raw</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/strtoi.html'>strtoi</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"47"</span>, <span class='s'>"49"</span>, <span class='s'>"46"</span>), <span class='m'>16</span>))

<span class='k'>format</span> <span class='o'>&lt;-</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/identical.html'>identical</a></span>(<span class='k'>file_header</span>, <span class='k'>png_header</span>)) {
    <span class='s'>"png"</span>
} <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/identical.html'>identical</a></span>(<span class='k'>file_header</span>[<span class='m'>1</span><span class='o'>:</span><span class='m'>2</span>], <span class='k'>jpg_header</span>)) {
    <span class='s'>"jpg"</span>
} <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/identical.html'>identical</a></span>(<span class='k'>file_header</span>[<span class='m'>1</span><span class='o'>:</span><span class='m'>2</span>], <span class='k'>bmp_header</span>)) {
    <span class='s'>"bmp"</span>
} <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/identical.html'>identical</a></span>(<span class='k'>file_header</span>[<span class='m'>1</span><span class='o'>:</span><span class='m'>3</span>], <span class='k'>gif_header</span>)) {
    <span class='s'>"gif"</span>
} <span class='kr'>else</span> {
    <span class='s'>"unknown"</span>
}</code></pre>

</div>

<!-- Tweet about yak shaving -->

The images then have to be scaled down to a reasonable maximum size (I used 800 pixels in either dimension), while preserving the image ratio.

There's also the matter of turning stuff into a list in R. I can run lists through `purrr` functions to embed/attach multiple files. But am I the only one who finds this really hard? Check out this hideous helper function I used:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>make_list</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) {
    <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/NULL.html'>is.null</a></span>(<span class='k'>x</span>)) {
        <span class='k'>x</span>
    } <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'>is.ggplot</span>(<span class='k'>x</span>)) { <span class='c'># ggplots are lists</span>
        <span class='nf'><a href='https://rdrr.io/r/base/list.html'>list</a></span>(<span class='k'>x</span>)
    } <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/as.data.frame.html'>is.data.frame</a></span>(<span class='k'>x</span>)) {
        <span class='nf'><a href='https://rdrr.io/r/base/list.html'>list</a></span>(<span class='k'>x</span>)  
    } <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/list.html'>is.list</a></span>(<span class='k'>x</span>)) {
        <span class='k'>x</span>
    } <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/vector.html'>is.vector</a></span>(<span class='k'>x</span>)) {
        <span class='nf'><a href='https://rdrr.io/r/base/list.html'>as.list</a></span>(<span class='k'>x</span>)
    } <span class='kr'>else</span> {
        <span class='nf'><a href='https://rdrr.io/r/base/list.html'>list</a></span>(<span class='k'>x</span>) <span class='c'># single item case</span>
    }
}</code></pre>

</div>

Lists are also important here because lists can have *names*, and we need those for embeddings and attachments. If the user puts only `obj` into the embeddings or attachments argument, `prepare_email` will attach, for example, `obj.png`. With a list of embeddings or attachments, it will use the names in the list. If these aren't available, or if the object is named `.` (as would be the case if it is coming from a pipe), sensible dummy names are used. File names aren't visible for embeddings, but we do need to ensure that they don't conflict, or else the cid tags will get confused.

The ideal `send_email` function
-------------------------------

As I said, I don't have any plans to develop this package any further. `RDCOMOutlook` is great for my situation, but it's not a modern answer. For one thing, it only works on Windows, and only with Outlook. DCOM itself is old and the documentation is non-existent; there were times here where I was literally *guessing* function names.

But most of the hard stuff is just juggling list names and image dimensions. That doesn't use DCOM. So why can't I take what I've done and stick in some other way of sending emails? So maybe the new function, `send_email`, will have something like a `connection` argument?

Without DCOM I do lose that nifty ability to make an email pop up on the screen instead of sending it. That's why I have to drop the `prepare_email` function name. I might also lose the ability to pick up the user's signature.

Here's a possible way to move away from DCOM:

1.  Focus on getting the prototype to work with SMTP. I imagine this covers the majority of use cases.
2.  Bring in compatibility with `gmailr`.
3.  Using `gmailr` as a guide, create `outlookr` and bring it into the fold.

I've actually had a fair bit of luck accessing the Outlook API using the wonderful `httr` package. I can authenticate and download email attachments. But Turning all of that into a proper package with good credential handling would be a challenge.

Bonus goal: searching emails
----------------------------

I built something else for the `RDCOMOutlook` prototype: the ability to search for emails and download attachments. The results are displayed in a nice, pretty tibble:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>RDCOMOutlook</span>::<span class='nf'>search_emails</span>(<span class='s'>"test"</span>) <span class='o'>%&gt;%</span> <span class='nf'>select</span>(<span class='k'>subject</span>, <span class='k'>received</span>, <span class='k'>attachments</span>)</code></pre>

</div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'>#&gt; <span style='color: #949494;'># A tibble: 3 x 3</span></span>
<span class='c'>#&gt;   subject                         received            attachments   </span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>                           </span><span style='color: #949494;font-style: italic;'>&lt;dttm&gt;</span><span>              </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>         </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> This is a test email            2018-06-12 </span><span style='color: #949494;'>16:42:42</span><span> </span><span style='color: #949494;'>""</span><span>            </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> Another test                    2018-06-12 </span><span style='color: #949494;'>17:36:08</span><span> </span><span style='color: #949494;'>""</span><span>            </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> A test email with an attachment 2018-06-12 </span><span style='color: #949494;'>17:36:36</span><span> </span><span style='color: #949494;'>"</span><span>shiborgi.jpg</span><span style='color: #949494;'>"</span></span></code></pre>

</div>

The problem here is that the `AdvancedSearch` method of DCOM is *asynchronous*; that is, the search will continue to run in the background while R continues with the next statement. There is an `AdvancedSearchComplete` *event*, I wasn't able to work out how to handle DCOM events. There is a package, called `RDCOMEvents`, that sounds suitable for this.

But I was able to download attachments from an Office365 email account using the Outlook REST API. I believe that `gmailr` can do the same. So I can probably recreate this without DCOM. This is a stretch goal, and probably a distraction, but it does seem like nice functionality to have.

Sources
-------

The header image at the top of this page is modified from an image in the [public domain](https://www.pexels.com/photo/gray-steel-tubes-586019/).

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
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.4.0      2019-10-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-06-12 [1] Github (r-lib/hugodown@6812ada)   </span>
<span class='c'>#&gt;  knitr         1.28       2020-02-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  pillar        1.4.4      2020-05-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild      1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.4.6    2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr         1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.2.3      2020-06-12 [1] Github (rstudio/rmarkdown@4ee96c8)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr       1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble        3.0.1      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  utf8          1.1.4      2018-05-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs         0.3.1      2020-06-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.14       2020-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

