---
title: Bootstrapping R functions
author: ~
date: '2020-07-08'
slug: bootstrapping-r-functions
tags:
    - R
images: ["/img/crime-scene.jpeg"]
featuredalt: |
    Tape that reads "Crime Scene".
output: hugodown::md_document
rmd_hash: 083bb4446fa50b0d

---

Suppose I want a function that runs some setup code before it runs the first time. Maybe I'm using dplyr but I haven't properly declared all of my dplyr calls in my function, so I want to run [`library(dplyr)`](https://dplyr.tidyverse.org) before the actual function is run. Or maybe I want to install a package if it isn't already installed, or restore a `renv` file, or any other setup process. I only want this special code to run the first time my function is called. After that, the function that runs should be exactly as I declared it, with none of the setup code.

Here's what I do:

1.  Create a new function with the same signature as my target function.
2.  Capture my setup code, and evaluate it when my new bootstrapping function is called.
3.  When my bootstrapping function is being executed, make it redefine itself with my target function in the same environment.
4.  After the redefinition, call the function again, which is now the redefined function, which is now my target function.

And then, to make things even more bizarre, I wrap this process up in a function-generating function that does all of this for me, with an input of just a function and some setup code.

By the way, I'm not actually suggesting you do this. It's a *wild* idea. Functions redefining themselves is an uncomfortable concept. And the idea that a function is running complicated setup code that isn't even hinted at in the function name makes me uneasy as well. But you **can** do this. So here it is:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>bootstrapping_function</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>fn</span>, <span class='k'>setup</span>) {
  <span class='k'>setup</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/substitute.html'>substitute</a></span>(<span class='k'>setup</span>)
  <span class='k'>bootstrapping_function</span> <span class='o'>&lt;-</span> <span class='k'>fn</span> <span class='c'># Copy the function so we can keep its formals</span>
  <span class='nf'><a href='https://rdrr.io/r/base/body.html'>body</a></span>(<span class='k'>bootstrapping_function</span>) <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/substitute.html'>substitute</a></span>({
    <span class='c'># The name of the function that's currently being executed.</span>
    <span class='k'>this_function_name</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/character.html'>as.character</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/match.call.html'>match.call</a></span>()[[<span class='m'>1</span>]])

    <span class='c'># We want to redefine the function in the same environment in which its</span>
    <span class='c'># currently defined. This function crawls up the environment hierarchy</span>
    <span class='c'># until it finds an object with the right name. Possible improvement:</span>
    <span class='c'># ignore any objects with the right name if they aren't functions.</span>
    <span class='k'>which_environment</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>name</span>, <span class='k'>env</span> = <span class='nf'><a href='https://rdrr.io/r/base/sys.parent.html'>parent.frame</a></span>()) {
      <span class='c'># Adapted from http://adv-r.had.co.nz/Environments.html</span>
      <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/identical.html'>identical</a></span>(<span class='k'>env</span>, <span class='nf'><a href='https://rdrr.io/r/base/environment.html'>emptyenv</a></span>())) {
        <span class='nf'><a href='https://rdrr.io/r/base/stop.html'>stop</a></span>(<span class='s'>"Can't find "</span>, <span class='k'>name</span>, call. = <span class='kc'>FALSE</span>)
      } <span class='kr'>else</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/exists.html'>exists</a></span>(<span class='k'>name</span>, envir = <span class='k'>env</span>, inherits = <span class='kc'>FALSE</span>)) {
        <span class='k'>env</span>
      } <span class='kr'>else</span> {
        <span class='nf'>which_environment</span>(<span class='k'>name</span>, <span class='nf'><a href='https://rdrr.io/r/base/environment.html'>parent.env</a></span>(<span class='k'>env</span>))
      }
    }
    <span class='k'>this_function_env</span> <span class='o'>&lt;-</span> <span class='nf'>which_environment</span>(<span class='k'>this_function_name</span>)

    <span class='c'># Recover the arguments that are being provided to this function at</span>
    <span class='c'># run-time, as a list. This lets us execute the function again after it's</span>
    <span class='c'># been redefined.</span>
    <span class='k'>get_args</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>() {
      <span class='c'># Adapted from https://stackoverflow.com/a/47955845/8456369</span>
      <span class='k'>parent_formals</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/formals.html'>formals</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/sys.parent.html'>sys.function</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/sys.parent.html'>sys.parent</a></span>(n = <span class='m'>1</span>)))
      <span class='k'>fnames</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>parent_formals</span>)
      <span class='k'>without_ellipses</span> <span class='o'>&lt;-</span> <span class='k'>fnames</span>[<span class='k'>fnames</span> != <span class='s'>"..."</span>]
      <span class='k'>args</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/eval.html'>evalq</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/list.html'>as.list</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/environment.html'>environment</a></span>()), envir = <span class='nf'><a href='https://rdrr.io/r/base/sys.parent.html'>parent.frame</a></span>())
      <span class='kr'>if</span> (<span class='s'>"..."</span> <span class='o'>%in%</span> <span class='k'>fnames</span>) {
        <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='k'>args</span>[<span class='k'>without_ellipses</span>], <span class='nf'><a href='https://rdrr.io/r/base/eval.html'>evalq</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/list.html'>list</a></span>(<span class='k'>...</span>), envir = <span class='nf'><a href='https://rdrr.io/r/base/sys.parent.html'>parent.frame</a></span>()))
      } <span class='kr'>else</span> {
        <span class='k'>args</span>[<span class='k'>without_ellipses</span>]
      }
    }

    <span class='k'>fn_location</span> <span class='o'>&lt;-</span> <span class='nf'>which_environment</span>(<span class='k'>this_function_name</span>)
    <span class='nf'><a href='https://rdrr.io/r/base/eval.html'>eval</a></span>(<span class='k'>setup</span>, <span class='nf'><a href='https://rdrr.io/r/base/sys.parent.html'>parent.frame</a></span>(<span class='m'>2</span>)) <span class='c'># evaluate in caller_env</span>
    <span class='nf'><a href='https://rdrr.io/r/base/assign.html'>assign</a></span>(<span class='k'>this_function_name</span>, <span class='k'>fn</span>, <span class='k'>this_function_env</span>) <span class='c'># here's the redefinition</span>
    <span class='nf'><a href='https://rdrr.io/r/base/do.call.html'>do.call</a></span>( <span class='c'># call the function again with the same arguments</span>
      <span class='k'>this_function_name</span>,
      args = <span class='nf'>get_args</span>(),
      envir = <span class='nf'><a href='https://rdrr.io/r/base/sys.parent.html'>parent.frame</a></span>(<span class='m'>2</span>)
    )
  })
  <span class='k'>bootstrapping_function</span>
}</code></pre>

</div>

I haven't thrown a lot of test cases at this code yet, but here's a simple example: take a data frame and add 1 to every numeric column. I've written the code with dplyr, but I've used `mutate_if` instead of [`dplyr::mutate_if`](https://dplyr.tidyverse.org/reference/mutate_all.html). I'll need to call [`library(dplyr)`](https://dplyr.tidyverse.org) before I run this function. I'll put an extra [`message()`](https://rdrr.io/r/base/message.html) in the setup code to make it clear that I'm actually running the setup.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>add_1_to_all_numeric_columns</span> <span class='o'>&lt;-</span> <span class='nf'>bootstrapping_function</span>(
  <span class='nf'>function</span>(<span class='k'>df</span>) <span class='nf'><a href='https://dplyr.tidyverse.org/reference/mutate_all.html'>mutate_if</a></span>(<span class='k'>df</span>, <span class='k'>is.numeric</span>, <span class='o'>~</span><span class='k'>.x</span> <span class='o'>+</span> <span class='m'>1</span>),
  setup = {
    <span class='nf'><a href='https://rdrr.io/r/base/message.html'>message</a></span>(<span class='s'>"Setting up the function to add 1 to all numeric columns"</span>)
    <span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='https://dplyr.tidyverse.org'>dplyr</a></span>)
  }
)</code></pre>

</div>

Let's run this monstrousity:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>add_1_to_all_numeric_columns</span>(<span class='k'>mtcars</span>)
<span class='c'>#&gt; Setting up the function to add 1 to all numeric columns</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Attaching package: 'dplyr'</span>
<span class='c'>#&gt; The following objects are masked from 'package:stats':</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt;     filter, lag</span>
<span class='c'>#&gt; The following objects are masked from 'package:base':</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt;     intersect, setdiff, setequal, union</span>
<span class='c'>#&gt;     mpg cyl  disp  hp drat    wt  qsec vs am gear carb</span>
<span class='c'>#&gt; 1  22.0   7 161.0 111 4.90 3.620 17.46  1  2    5    5</span>
<span class='c'>#&gt; 2  22.0   7 161.0 111 4.90 3.875 18.02  1  2    5    5</span>
<span class='c'>#&gt; 3  23.8   5 109.0  94 4.85 3.320 19.61  2  2    5    2</span>
<span class='c'>#&gt; 4  22.4   7 259.0 111 4.08 4.215 20.44  2  1    4    2</span>
<span class='c'>#&gt; 5  19.7   9 361.0 176 4.15 4.440 18.02  1  1    4    3</span>
<span class='c'>#&gt; 6  19.1   7 226.0 106 3.76 4.460 21.22  2  1    4    2</span>
<span class='c'>#&gt; 7  15.3   9 361.0 246 4.21 4.570 16.84  1  1    4    5</span>
<span class='c'>#&gt; 8  25.4   5 147.7  63 4.69 4.190 21.00  2  1    5    3</span>
<span class='c'>#&gt; 9  23.8   5 141.8  96 4.92 4.150 23.90  2  1    5    3</span>
<span class='c'>#&gt; 10 20.2   7 168.6 124 4.92 4.440 19.30  2  1    5    5</span>
<span class='c'>#&gt; 11 18.8   7 168.6 124 4.92 4.440 19.90  2  1    5    5</span>
<span class='c'>#&gt; 12 17.4   9 276.8 181 4.07 5.070 18.40  1  1    4    4</span>
<span class='c'>#&gt; 13 18.3   9 276.8 181 4.07 4.730 18.60  1  1    4    4</span>
<span class='c'>#&gt; 14 16.2   9 276.8 181 4.07 4.780 19.00  1  1    4    4</span>
<span class='c'>#&gt; 15 11.4   9 473.0 206 3.93 6.250 18.98  1  1    4    5</span>
<span class='c'>#&gt; 16 11.4   9 461.0 216 4.00 6.424 18.82  1  1    4    5</span>
<span class='c'>#&gt; 17 15.7   9 441.0 231 4.23 6.345 18.42  1  1    4    5</span>
<span class='c'>#&gt; 18 33.4   5  79.7  67 5.08 3.200 20.47  2  2    5    2</span>
<span class='c'>#&gt; 19 31.4   5  76.7  53 5.93 2.615 19.52  2  2    5    3</span>
<span class='c'>#&gt; 20 34.9   5  72.1  66 5.22 2.835 20.90  2  2    5    2</span>
<span class='c'>#&gt; 21 22.5   5 121.1  98 4.70 3.465 21.01  2  1    4    2</span>
<span class='c'>#&gt; 22 16.5   9 319.0 151 3.76 4.520 17.87  1  1    4    3</span>
<span class='c'>#&gt; 23 16.2   9 305.0 151 4.15 4.435 18.30  1  1    4    3</span>
<span class='c'>#&gt; 24 14.3   9 351.0 246 4.73 4.840 16.41  1  1    4    5</span>
<span class='c'>#&gt; 25 20.2   9 401.0 176 4.08 4.845 18.05  1  1    4    3</span>
<span class='c'>#&gt; 26 28.3   5  80.0  67 5.08 2.935 19.90  2  2    5    2</span>
<span class='c'>#&gt; 27 27.0   5 121.3  92 5.43 3.140 17.70  1  2    6    3</span>
<span class='c'>#&gt; 28 31.4   5  96.1 114 4.77 2.513 17.90  2  2    6    3</span>
<span class='c'>#&gt; 29 16.8   9 352.0 265 5.22 4.170 15.50  1  2    6    5</span>
<span class='c'>#&gt; 30 20.7   7 146.0 176 4.62 3.770 16.50  1  2    6    7</span>
<span class='c'>#&gt; 31 16.0   9 302.0 336 4.54 4.570 15.60  1  2    6    9</span>
<span class='c'>#&gt; 32 22.4   5 122.0 110 5.11 3.780 19.60  2  2    5    3</span></code></pre>

</div>

Sure enough, the function has been redefined:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>add_1_to_all_numeric_columns</span>
<span class='c'>#&gt; function(df) mutate_if(df, is.numeric, ~.x + 1)</span>
<span class='c'>#&gt; &lt;bytecode: 0x560cecc8b0c0&gt;</span>
<span class='c'>#&gt; &lt;environment: 0x560cecc493f8&gt;</span></code></pre>

</div>

And now, if I run it a second time, there's no setup:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>add_1_to_all_numeric_columns</span>(<span class='k'>mtcars</span>)
<span class='c'>#&gt;     mpg cyl  disp  hp drat    wt  qsec vs am gear carb</span>
<span class='c'>#&gt; 1  22.0   7 161.0 111 4.90 3.620 17.46  1  2    5    5</span>
<span class='c'>#&gt; 2  22.0   7 161.0 111 4.90 3.875 18.02  1  2    5    5</span>
<span class='c'>#&gt; 3  23.8   5 109.0  94 4.85 3.320 19.61  2  2    5    2</span>
<span class='c'>#&gt; 4  22.4   7 259.0 111 4.08 4.215 20.44  2  1    4    2</span>
<span class='c'>#&gt; 5  19.7   9 361.0 176 4.15 4.440 18.02  1  1    4    3</span>
<span class='c'>#&gt; 6  19.1   7 226.0 106 3.76 4.460 21.22  2  1    4    2</span>
<span class='c'>#&gt; 7  15.3   9 361.0 246 4.21 4.570 16.84  1  1    4    5</span>
<span class='c'>#&gt; 8  25.4   5 147.7  63 4.69 4.190 21.00  2  1    5    3</span>
<span class='c'>#&gt; 9  23.8   5 141.8  96 4.92 4.150 23.90  2  1    5    3</span>
<span class='c'>#&gt; 10 20.2   7 168.6 124 4.92 4.440 19.30  2  1    5    5</span>
<span class='c'>#&gt; 11 18.8   7 168.6 124 4.92 4.440 19.90  2  1    5    5</span>
<span class='c'>#&gt; 12 17.4   9 276.8 181 4.07 5.070 18.40  1  1    4    4</span>
<span class='c'>#&gt; 13 18.3   9 276.8 181 4.07 4.730 18.60  1  1    4    4</span>
<span class='c'>#&gt; 14 16.2   9 276.8 181 4.07 4.780 19.00  1  1    4    4</span>
<span class='c'>#&gt; 15 11.4   9 473.0 206 3.93 6.250 18.98  1  1    4    5</span>
<span class='c'>#&gt; 16 11.4   9 461.0 216 4.00 6.424 18.82  1  1    4    5</span>
<span class='c'>#&gt; 17 15.7   9 441.0 231 4.23 6.345 18.42  1  1    4    5</span>
<span class='c'>#&gt; 18 33.4   5  79.7  67 5.08 3.200 20.47  2  2    5    2</span>
<span class='c'>#&gt; 19 31.4   5  76.7  53 5.93 2.615 19.52  2  2    5    3</span>
<span class='c'>#&gt; 20 34.9   5  72.1  66 5.22 2.835 20.90  2  2    5    2</span>
<span class='c'>#&gt; 21 22.5   5 121.1  98 4.70 3.465 21.01  2  1    4    2</span>
<span class='c'>#&gt; 22 16.5   9 319.0 151 3.76 4.520 17.87  1  1    4    3</span>
<span class='c'>#&gt; 23 16.2   9 305.0 151 4.15 4.435 18.30  1  1    4    3</span>
<span class='c'>#&gt; 24 14.3   9 351.0 246 4.73 4.840 16.41  1  1    4    5</span>
<span class='c'>#&gt; 25 20.2   9 401.0 176 4.08 4.845 18.05  1  1    4    3</span>
<span class='c'>#&gt; 26 28.3   5  80.0  67 5.08 2.935 19.90  2  2    5    2</span>
<span class='c'>#&gt; 27 27.0   5 121.3  92 5.43 3.140 17.70  1  2    6    3</span>
<span class='c'>#&gt; 28 31.4   5  96.1 114 4.77 2.513 17.90  2  2    6    3</span>
<span class='c'>#&gt; 29 16.8   9 352.0 265 5.22 4.170 15.50  1  2    6    5</span>
<span class='c'>#&gt; 30 20.7   7 146.0 176 4.62 3.770 16.50  1  2    6    7</span>
<span class='c'>#&gt; 31 16.0   9 302.0 336 4.54 4.570 15.60  1  2    6    9</span>
<span class='c'>#&gt; 32 22.4   5 122.0 110 5.11 3.780 19.60  2  2    5    3</span></code></pre>

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
<span class='c'>#&gt;  date     2020-07-07                  </span>
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
<span class='c'>#&gt;  dplyr       * 1.0.0      2020-05-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics      0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-06-20 [1] Github (r-lib/hugodown@f7df565)   </span>
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
<span class='c'>#&gt;  purrr         0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.3.1      2020-06-20 [1] Github (rstudio/rmarkdown@b53a85a)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr       1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble        3.0.1      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect    1.1.0      2020-05-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
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

[The image at the top of this page is in the public domain](https://www.pexels.com/photo/crime-scene-do-not-cross-signage-923681/).

