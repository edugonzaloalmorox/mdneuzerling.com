---
title: Sourcing Data from S3 with Drake
author: ~
date: '2020-08-23'
slug: sourcing-data-from-s3-with-drake
tags:
    - R
images: ["/img/drake-etag.png"]
output: hugodown::md_document
rmd_hash: d2d2b287e25aef3a

---

[`drake` is a package for orchestrating R workflows](https://docs.ropensci.org/drake/). Suppose I have some data in S3 that I want to pull into R through a `drake` plan. In this post I'll use the S3 object's *ETag* to make `drake` only re-download the data if it's changed.

This covers the scenario in which the object name in S3 stays the same. If I had, say, data being uploaded each day with an object name suffixed with the date, then I wouldn't bother checking for any changes.

Connecting to S3
----------------

Both [the `aws.s3` package](https://github.com/cloudyr/aws.s3) and [the `PAWS` package](https://paws-r.github.io/) will connect to S3 from R. I've used both of these packages, and there's nothing wrong with them, but I always find myself going back to wrapping AWS CLI commands. I'm not saying this is the *best* way to use AWS from within R, but it works, although I haven't tested this on anything other than Linux.

By this point I've run `aws configure` in a terminal to make sure that I can actually connect to AWS. I've also created an S3 bucket.

There are two ways to connect to S3 from the AWS CLI. `s3` commands are more high-level than `s3api` commands, but I'll need to use both here.

Uploading some data
-------------------

I'll start by uploading some CSV data to my bucket using an `s3` command, so that I have something to source in my `drake` plan. What I really like about the `s3` commands is that I don't have to mess around with any multi-part uploads, as the AWS CLI takes care of all that complexity for me.

I'll create a function that forms and executes the command. My command needs to be of the form `aws s3 cp $SOURCE $TARGET`. The `$SOURCE` or `$TARGET` variables can be either local files or objects on S3, with objects prefixed with "s3://\$BUCKET". My function will take a data frame and, using the name of that data frame, determine the path of the object on S3. A more sophisticated function would be more flexible about how I'm storing the data, but this will do for my demonstration.

Note the use of `shQuote` here, a base function that quotes a string to be passed to a shell.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>upload_data_to_s3_bucket_as_csv</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>data</span>, <span class='k'>bucket</span>) {
  <span class='k'>object_name</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/deparse.html'>deparse</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/substitute.html'>substitute</a></span>(<span class='k'>data</span>)), <span class='s'>".csv"</span>)
  <span class='k'>temp_file</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/tempfile.html'>tempfile</a></span>()
  <span class='c'># delete this temp file afterwards, even if this function errors</span>
  <span class='nf'><a href='https://rdrr.io/r/base/on.exit.html'>on.exit</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/unlink.html'>unlink</a></span>(<span class='k'>temp_file</span>)) 
  <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/write_delim.html'>write_csv</a></span>(<span class='k'>data</span>, <span class='k'>temp_file</span>)
  <span class='k'>quoted_file_path</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/shQuote.html'>shQuote</a></span>(<span class='k'>temp_file</span>)
  <span class='k'>quoted_object_path</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/shQuote.html'>shQuote</a></span>(<span class='k'>glue</span>::<span class='nf'><a href='https://glue.tidyverse.org/reference/glue.html'>glue</a></span>(<span class='s'>"s3://{bucket}/{object_name}"</span>))
  <span class='nf'><a href='https://rdrr.io/r/base/system.html'>system</a></span>(<span class='k'>glue</span>::<span class='nf'><a href='https://glue.tidyverse.org/reference/glue.html'>glue</a></span>(<span class='s'>"aws s3 cp {quoted_file_path} {quoted_object_path}"</span>))
}</code></pre>

</div>

Getting object metadata
-----------------------

The ETag is a hash that changes when the object changes[^1]. It's a short string like "de3b6f4731f18de03e51a5fea8102c93". No matter how big an object is, the ETag stays the same size, and is quick to retrieve. This means that we can check the ETag every time a `drake` plan is made without spending too much time, and only re-download the actual data if `drake` detects a change in this value.

I need to use a lower-level `s3api` command here. The `head-object` command retrieves object metadata. I convert that metadata from JSON, extract the ETag, and remove the stray quotation marks around it.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>get_etag</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>object</span>, <span class='k'>bucket</span>) {
  <span class='k'>response</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/system.html'>system</a></span>(
    <span class='k'>glue</span>::<span class='nf'><a href='https://glue.tidyverse.org/reference/glue.html'>glue</a></span>(<span class='s'>"aws s3api head-object --bucket {bucket} --key {object}"</span>),
    intern = <span class='kc'>TRUE</span>
  )
  <span class='k'>raw_etag</span> <span class='o'>&lt;-</span> <span class='k'>jsonlite</span>::<span class='nf'><a href='https://jeroen.cran.dev/jsonlite/reference/fromJSON.html'>fromJSON</a></span>(<span class='k'>response</span>)<span class='o'>$</span><span class='k'>ETag</span>
  <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\""</span>, <span class='s'>""</span>, <span class='k'>raw_etag</span>)
}</code></pre>

</div>

Downloading from S3
-------------------

I'll once again use an `s3` command to download data from an S3. This function is very similar to the upload function, with the source and target reversed.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>download_and_parse_csv_from_s3_bucket</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>object</span>, <span class='k'>bucket</span>) {
  <span class='k'>temp_file</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/tempfile.html'>tempfile</a></span>()
  <span class='c'># delete this temp file afterwards, even if this function errors</span>
  <span class='nf'><a href='https://rdrr.io/r/base/on.exit.html'>on.exit</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/unlink.html'>unlink</a></span>(<span class='k'>temp_file</span>)) 
  <span class='k'>quoted_file_path</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/shQuote.html'>shQuote</a></span>(<span class='k'>temp_file</span>)
  <span class='k'>quoted_object_path</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/shQuote.html'>shQuote</a></span>(<span class='k'>glue</span>::<span class='nf'><a href='https://glue.tidyverse.org/reference/glue.html'>glue</a></span>(<span class='s'>"s3://{bucket}/{object}"</span>))
  <span class='nf'><a href='https://rdrr.io/r/base/system.html'>system</a></span>(<span class='k'>glue</span>::<span class='nf'><a href='https://glue.tidyverse.org/reference/glue.html'>glue</a></span>(<span class='s'>"aws s3 cp {quoted_object_path} {quoted_file_path}"</span>))
  <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/read_delim.html'>read_csv</a></span>(<span class='k'>temp_file</span>)
}</code></pre>

</div>

Generating some random data
---------------------------

I'll need some data to upload to my bucket and then retrieve. Here's my go-to function for generating a data frame of random bits, adapated from [this StackOverflow answer](https://stackoverflow.com/a/19352289/8456369):

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>generate_random_data</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>nrow</span> = <span class='m'>1000</span>, <span class='k'>ncol</span> = <span class='m'>10</span>) {
  <span class='nf'><a href='https://rdrr.io/r/base/data.frame.html'>data.frame</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/lapply.html'>replicate</a></span>(<span class='k'>ncol</span>, <span class='nf'><a href='https://rdrr.io/r/base/sample.html'>sample</a></span>(<span class='m'>0</span><span class='o'>:</span><span class='m'>1</span>, <span class='k'>nrow</span>, rep = <span class='kc'>TRUE</span>)))
}</code></pre>

</div>

Now I'll upload some random data to my bucket. I've created a bucket "ocelittle", which is the unofficial name of ocelot kittens. This has nothing to do with AWS; I just needed a unique name for the bucket.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>some_random_data</span> <span class='o'>&lt;-</span> <span class='nf'>generate_random_data</span>()
<span class='nf'>upload_data_to_s3_bucket_as_csv</span>(<span class='k'>some_random_data</span>, bucket = <span class='s'>"ocelittle"</span>)
<span class='nf'>get_etag</span>(<span class='s'>"some_random_data.csv"</span>, bucket = <span class='s'>"ocelittle"</span>)
<span class='c'>#&gt; [1] "104b796e58ef578339253f1f04673388"</span></code></pre>

</div>

Method 1: A separate target for the ETag
----------------------------------------

There are two equally valid ways to structure the `drake` plan to check the ETag. They're effectively equivalent, but there's some slight variation in how the targets are displayed when I run [`drake::vis_drake_graph`](https://docs.ropensci.org/drake/reference/vis_drake_graph.html).

In this first method, I'll create a separate target for the ETag so that it appears in my `drake` plan visualisations, as in the plot at the top of this page. Pay close attention to the conditions for each trigger:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>s3_plan</span> <span class='o'>&lt;-</span> <span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/drake_plan.html'>drake_plan</a></span>(
  etag = <span class='nf'><a href='https://docs.ropensci.org/drake/reference/target.html'>target</a></span>(
    <span class='nf'>get_etag</span>(<span class='s'>"some_random_data.csv"</span>, <span class='s'>"ocelittle"</span>),
    trigger = <span class='nf'><a href='https://docs.ropensci.org/drake/reference/trigger.html'>trigger</a></span>(condition = <span class='kc'>TRUE</span>)
  ),
  data = <span class='nf'><a href='https://docs.ropensci.org/drake/reference/target.html'>target</a></span>(
    <span class='nf'>download_and_parse_csv_from_s3_bucket</span>(<span class='s'>"some_random_data.csv"</span>, <span class='s'>"ocelittle"</span>),
    trigger = <span class='nf'><a href='https://docs.ropensci.org/drake/reference/trigger.html'>trigger</a></span>(change = <span class='k'>etag</span>)
  )
)</code></pre>

</div>

The condition for the `etag` target is `TRUE`, which means that this target will always run when I `make` the `drake` plan. The `data` target only runs when the value of the `etag` target has changed. When I `make` this plan for the first time, both targets are executed:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='k'>s3_plan</span>)
<span class='c'>#&gt; <span style='color: #00BB00;'>▶</span><span> target etag</span></span>
<span class='c'>#&gt; <span style='color: #00BB00;'>▶</span><span> target data</span></span>
<span class='c'>#&gt; Parsed with column specification:</span>
<span class='c'>#&gt; cols(</span>
<span class='c'>#&gt;   X1 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X2 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X3 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X4 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X5 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X6 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X7 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X8 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X9 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X10 = <span style='color: #00BB00;'>col_double()</span></span>
<span class='c'>#&gt; )</span></code></pre>

</div>

When I run the plan a second time, the `etag` target runs, as expected. But as the object's ETag hasn't changed, `drake` doesn't execute the `data` target.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='k'>s3_plan</span>)
<span class='c'>#&gt; <span style='color: #00BB00;'>▶</span><span> target etag</span></span></code></pre>

</div>

Now I'll generate some new random data, and overwrite the previous CSV:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>some_random_data</span> <span class='o'>&lt;-</span> <span class='nf'>generate_random_data</span>()
<span class='nf'>upload_data_to_s3_bucket_as_csv</span>(<span class='k'>some_random_data</span>, bucket = <span class='s'>"ocelittle"</span>)
<span class='nf'>get_etag</span>(<span class='s'>"some_random_data.csv"</span>, bucket = <span class='s'>"ocelittle"</span>)
<span class='c'>#&gt; [1] "5b978808807d201824757e7b703d8910"</span></code></pre>

</div>

`drake` detects the change and re-downloads the data:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='k'>s3_plan</span>)
<span class='c'>#&gt; <span style='color: #00BB00;'>▶</span><span> target etag</span></span>
<span class='c'>#&gt; <span style='color: #00BB00;'>▶</span><span> target data</span></span>
<span class='c'>#&gt; Parsed with column specification:</span>
<span class='c'>#&gt; cols(</span>
<span class='c'>#&gt;   X1 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X2 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X3 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X4 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X5 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X6 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X7 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X8 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X9 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X10 = <span style='color: #00BB00;'>col_double()</span></span>
<span class='c'>#&gt; )</span></code></pre>

</div>

Method 2: Embedding the ETag in the data target
-----------------------------------------------

Rather than having a separate target for the `etag`, I can use put the `get_etag` function directly into the `change` condition for the data download target. This won't show the ETag when I run `drake::drake_vis_graph`.

First, I'll clean the `drake` cache:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/clean.html'>clean</a></span>()</code></pre>

</div>

The `change` trigger accepts any R expression, so it accepts the `get_etag` function. This will run every time the plan is made.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>s3_plan_2</span> <span class='o'>&lt;-</span> <span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/drake_plan.html'>drake_plan</a></span>(
  data = <span class='nf'><a href='https://docs.ropensci.org/drake/reference/target.html'>target</a></span>(
    <span class='nf'>download_and_parse_csv_from_s3_bucket</span>(<span class='s'>"some_random_data.csv"</span>, <span class='s'>"ocelittle"</span>),
    trigger = <span class='nf'><a href='https://docs.ropensci.org/drake/reference/trigger.html'>trigger</a></span>(change = <span class='nf'>get_etag</span>(<span class='s'>"some_random_data.csv"</span>, <span class='s'>"ocelittle"</span>))
  )
)</code></pre>

</div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='k'>s3_plan_2</span>)
<span class='c'>#&gt; <span style='color: #00BB00;'>▶</span><span> target data</span></span>
<span class='c'>#&gt; Parsed with column specification:</span>
<span class='c'>#&gt; cols(</span>
<span class='c'>#&gt;   X1 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X2 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X3 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X4 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X5 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X6 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X7 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X8 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X9 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X10 = <span style='color: #00BB00;'>col_double()</span></span>
<span class='c'>#&gt; )</span></code></pre>

</div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='k'>s3_plan_2</span>)
<span class='c'>#&gt; <span style='color: #00BB00;'>✔</span><span> All targets are already up to date.</span></span></code></pre>

</div>

And now, just to check, I'll upload some new data and make sure that `drake` downloads it:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>some_random_data</span> <span class='o'>&lt;-</span> <span class='nf'>generate_random_data</span>()
<span class='nf'>upload_data_to_s3_bucket_as_csv</span>(<span class='k'>some_random_data</span>, bucket = <span class='s'>"ocelittle"</span>)
<span class='nf'>get_etag</span>(<span class='s'>"some_random_data.csv"</span>, bucket = <span class='s'>"ocelittle"</span>)
<span class='c'>#&gt; [1] "afce4300c7ea473c81b5a9f0f9712af3"</span></code></pre>

</div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>drake</span>::<span class='nf'><a href='https://docs.ropensci.org/drake/reference/make.html'>make</a></span>(<span class='k'>s3_plan_2</span>)
<span class='c'>#&gt; <span style='color: #00BB00;'>▶</span><span> target data</span></span>
<span class='c'>#&gt; Parsed with column specification:</span>
<span class='c'>#&gt; cols(</span>
<span class='c'>#&gt;   X1 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X2 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X3 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X4 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X5 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X6 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X7 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X8 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X9 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   X10 = <span style='color: #00BB00;'>col_double()</span></span>
<span class='c'>#&gt; )</span></code></pre>

</div>

Once again, `drake` detects the change and re-downloads the data.

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
<span class='c'>#&gt;  date     2020-08-23                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib source                            </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports     1.1.8      2020-06-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  base64url     1.4        2018-05-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-07-25 [1] Github (r-lib/downlit@ed969d0)    </span>
<span class='c'>#&gt;  drake       * 7.12.4     2020-07-30 [1] Github (ropensci/drake@20cd701)   </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  filelock      1.0.2      2018-10-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.5.0      2020-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  here          0.1        2017-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-08-13 [1] Github (r-lib/hugodown@2af491d)   </span>
<span class='c'>#&gt;  igraph        1.2.5      2020-03-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  jsonlite      1.7.0      2020-06-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr         1.29       2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice       0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Matrix        1.2-18     2019-11-27 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  pillar        1.4.6      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild      1.1.0      2020-07-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.1.0      2020-05-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.3      2020-07-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  progress      1.2.2      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.4      2020-08-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr         0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.5      2020-07-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr         1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reticulate    1.16       2020-05-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.7      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.3.3      2020-08-13 [1] Github (rstudio/rmarkdown@204aa41)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  storr         1.2.1      2018-10-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr       1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble        3.0.3      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect    1.1.0      2020-05-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  txtq          0.2.3      2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs         0.3.2      2020-07-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.16       2020-07-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

[^1]: [The ETag may or may not be an MD5 hash of the obejct data](https://docs.aws.amazon.com/AmazonS3/latest/API/RESTCommonResponseHeaders.html).

