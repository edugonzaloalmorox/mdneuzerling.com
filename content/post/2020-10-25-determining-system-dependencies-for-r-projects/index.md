---
title: Determining system dependencies for R projects
author: ~
date: '2020-10-25'
slug: determining-system-dependencies-for-r-projects
tags:
    - R
images: ["/img/dependencies.jpg"]
output: hugodown::md_document
rmd_hash: 9def893bb5e36e9a

---

Locking down R package dependencies and versions is a solved problem, thanks to the easy-to-use `renv` package. System dependencies --- those Linux packages that need to be installed to make certain R packages work --- are a bit harder to manage.

Option 1: Hard-coding
---------------------

The easiest option is to hard-code the system dependencies. I did this recently when [I was creating a Dockerfile for a very simple Plumber API](https://github.com/mdneuzerling/plumber-on-k8s/blob/e05ebd4a067ec0fd262ec04681b8ad101391e110/Dockerfile):

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>RUN apt-get update -qq && apt-get -y --no-install-recommends install \
    make \
    libsodium-dev \
    libicu-dev \
    libcurl4-openssl-dev \
    libssl-dev
</code></pre>

</div>

My Dockerfile used only three R packages and so its system dependencies were not complicated. There are two ways of determining which packages to install:

1.  (The bad way) Try to `build` the Dockerfile and use the errors to determine which dependencies are missing, or
2.  (The good way) Use [The RStudio Package Manager](https://packagemanager.rstudio.com/client/#/).

The RStudio Package Manager (RSPM) has had a huge impact on my R workflow. It just makes life easier. In this case, [it tells me the system dependencies for each R package, as well as the installation commands](https://packagemanager.rstudio.com/client/#/repos/1/packages/plumber). System dependencies vary between Linux distributions and releases, and RSPM takes this into account.

Hardcoding system dependencies into Dockerfiles or CI/CD pipelines makes sense for small, throwaway projects, but isn't a great idea for ongoing and dynamic projects. A better option is to automatically determine these dependencies automatically.

Option 2: From package DESCRIPTIONs
-----------------------------------

There are some great options for determining system dependencies automatically from package DESCRIPTION files. These files contain lists of dependencies for the package, so all that's needed is an established repository to translate those R dependencies to system dependencies.

[RSPM has a public API](https://packagemanager.rstudio.com/__api__/swagger/index.html), and that has a few endpoints for querying system dependencies. [The `remotes` package offers the `system_requirements` function](https://rdrr.io/cran/remotes/man/system_requirements.html), which queries the RSPM API for the system dependencies of a package. The package can be on CRAN, or it can be a package under local development; in this case, the DESCRIPTION file is used.

An important use-case for this is in creating continuous integration pipelines for a package in development. Every time the package is updated a fresh environment is used for testing, so system dependencies need to be installed each time. The [r-lib actions repository](https://github.com/r-lib/actions) has an example of a [standard package check in Github Actions](https://github.com/r-lib/actions/blob/673b3c925483f67fa939c31748562af36bb4cde2/examples/check-standard.yaml#L58) that does this:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>- name: Install system dependencies
  if: runner.os == 'Linux'
  run: |
    while read -r cmd
    do
      eval sudo $cmd
    done < <(Rscript -e 'writeLines(remotes::system_requirements("ubuntu", "20.04"))')
</code></pre>

</div>

[An earlier version of this workflow](https://github.com/r-lib/actions/blob/df2ff6518076b804295296769e68d858c38088ea/examples/check-standard.yaml#L54) used [the `sysreqs` package](https://www.google.com/search?channel=fs&client=ubuntu&q=sysreqs+r+package), which calls on <https://sysreqs.r-hub.io/> to perform this translation:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>- name: Install system dependencies
  if: runner.os == 'Linux'
  env:
    RHUB_PLATFORM: linux-x86_64-ubuntu-gcc
  run: |
    Rscript -e "remotes::install_github('r-hub/sysreqs')"
    sysreqs=$(Rscript -e "cat(sysreqs::sysreq_commands('DESCRIPTION'))")
    sudo -s eval "$sysreqs"
</code></pre>

</div>

Most of the work in this space has been done by Jim Hester, whose contributions to Github Actions for R have made my life much, much easier.

Option 3: From `renv` lock files
--------------------------------

While `remotes::system_requirements` function is great for package development, it doesn't cover every R project. The emerging standard for managing R package dependencies is `renv`. Given this, and given `renv`'s capacity to automatically detect package dependencies, it makes sense to explore linking `renv` lock files to system dependencies.

Before I go on, I'll just say that I would be *very surprised* if this hasn't been done before, or someone isn't already looking at this.

[The RSPM API](https://packagemanager.rstudio.com/__api__/swagger/index.html) contains an endpoint for querying system dependencies with a list of packages, rather than a DESCRIPTION file. Here's an example query:

    http://packagemanager.rstudio.com/__api__/repos/1/sysreqs?all=false&pkgname=plumber&pkgname=rmarkdown&distribution=ubuntu&release=20.04

Despite what the Swagger page says, the package names need to be specified each with `pkgname=`, rather than being separated by commas.

The result is a JSON that needs to be parsed into something usable. [I've created a package that does just this](https://github.com/mdneuzerling/getsysreqs). It's a very low-effort package, so please don't use it for anything serious. Or better yet, don't use it at all. But it does show that the RSPM API supports this use-case:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='kr'><a href='https://rdrr.io/r/base/library.html'>library</a></span><span class='o'>(</span><span class='nv'><a href='https://github.com/mdneuzerling/getsysreqs'>getsysreqs</a></span><span class='o'>)</span>

<span class='nf'><a href='https://rdrr.io/pkg/getsysreqs/man/get_sysreqs.html'>get_sysreqs</a></span><span class='o'>(</span>
  <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span><span class='o'>(</span><span class='s'>"plumber"</span>, <span class='s'>"rmarkdown"</span><span class='o'>)</span>,
  distribution <span class='o'>=</span> <span class='s'>"ubuntu"</span>,
  release <span class='o'>=</span> <span class='s'>"20.04"</span>
<span class='o'>)</span>

<span class='c'>#&gt; [1] "libsodium-dev"        "libcurl4-openssl-dev" "libssl-dev"          </span>
<span class='c'>#&gt; [4] "make"                 "libicu-dev"           "pandoc"</span>
</code></pre>

</div>

With a little more JSON-parsing, it's possible to extract the R package dependencies from an `renv` lock file. Here's an example from a more complicated project:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/pkg/getsysreqs/man/get_sysreqs.html'>get_sysreqs</a></span><span class='o'>(</span>
  <span class='s'>"renv.lock"</span>,
  distribution <span class='o'>=</span> <span class='s'>"ubuntu"</span>,
  release <span class='o'>=</span> <span class='s'>"20.04"</span>
<span class='o'>)</span>

<span class='c'>#&gt;  [1] "libcurl4-openssl-dev" "libssl-dev"           "libxml2-dev"         </span>
<span class='c'>#&gt;  [4] "libgit2-dev"          "libssh2-1-dev"        "zlib1g-dev"          </span>
<span class='c'>#&gt;  [7] "make"                 "git"                  "libicu-dev"          </span>
<span class='c'>#&gt; [10] "pandoc"               "libglpk-dev"          "libgmp3-dev"</span>
</code></pre>

</div>

And with only a little bit of string manipulation, it's possible to generate install commands:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/pkg/getsysreqs/man/apt_get_install.html'>apt_get_install</a></span><span class='o'>(</span>
  <span class='s'>"renv.lock"</span>,
  distribution <span class='o'>=</span> <span class='s'>"ubuntu"</span>,
  release <span class='o'>=</span> <span class='s'>"20.04"</span>
<span class='o'>)</span>

<span class='c'>#&gt; [1] "apt-get update -qq &amp;&amp; apt-get -y --no-install-recommends install libcurl4-openssl-dev libssl-dev libxml2-dev libssh2-1-dev zlib1g-dev make git libicu-dev pandoc libglpk-dev libgmp3-dev"</span>
</code></pre>

</div>

This isn't perfect:

1.  Currently this only accepts CRAN dependencies. The RSPM API returns an error when a non-existent package is in the request. An alternative would be to query every package separately and ignore the errors for non-existent packages, but I'm cautious about querying the API too frequently.
2.  Prefixing every dependency with `apt-get install` is naïve. System dependencies may have commands that need to be run before or after installation (Java, always Java). Fortunately, the RSPM API also tracks these.
3.  Not every Linux distribution uses `apt`.

------------------------------------------------------------------------

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>devtools</span><span class='nf'>::</span><span class='nf'><a href='https://rdrr.io/pkg/sessioninfo/man/session_info.html'>session_info</a></span><span class='o'>(</span><span class='o'>)</span>

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
<span class='c'>#&gt;  date     2020-10-25                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib</span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1]</span>
<span class='c'>#&gt;  backports     1.1.10     2020-09-15 [1]</span>
<span class='c'>#&gt;  callr         3.4.4      2020-09-07 [1]</span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1]</span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1]</span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1]</span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1]</span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1]</span>
<span class='c'>#&gt;  downlit       0.2.0      2020-10-03 [1]</span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1]</span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1]</span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1]</span>
<span class='c'>#&gt;  fs            1.5.0      2020-07-31 [1]</span>
<span class='c'>#&gt;  getsysreqs  * 0.0.0.9000 2020-10-25 [1]</span>
<span class='c'>#&gt;  glue          1.4.2      2020-08-27 [1]</span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1]</span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-10-03 [1]</span>
<span class='c'>#&gt;  knitr         1.30       2020-09-22 [1]</span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1]</span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1]</span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1]</span>
<span class='c'>#&gt;  pkgbuild      1.1.0      2020-07-13 [1]</span>
<span class='c'>#&gt;  pkgload       1.1.0      2020-05-29 [1]</span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1]</span>
<span class='c'>#&gt;  processx      3.4.4      2020-09-03 [1]</span>
<span class='c'>#&gt;  ps            1.3.4      2020-08-11 [1]</span>
<span class='c'>#&gt;  purrr         0.3.4      2020-04-17 [1]</span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1]</span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1]</span>
<span class='c'>#&gt;  rlang         0.4.7      2020-07-09 [1]</span>
<span class='c'>#&gt;  rmarkdown     2.4.1      2020-10-03 [1]</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1]</span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1]</span>
<span class='c'>#&gt;  stringi       1.5.3      2020-09-09 [1]</span>
<span class='c'>#&gt;  stringr       1.4.0      2019-02-10 [1]</span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1]</span>
<span class='c'>#&gt;  usethis       1.9.0.9000 2020-10-10 [1]</span>
<span class='c'>#&gt;  vctrs         0.3.4      2020-08-29 [1]</span>
<span class='c'>#&gt;  withr         2.3.0      2020-09-22 [1]</span>
<span class='c'>#&gt;  xfun          0.18       2020-09-29 [1]</span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1]</span>
<span class='c'>#&gt;  source                                  </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  Github (r-lib/downlit@df73cf3)          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  Github (mdneuzerling/getsysreqs@197b5f1)</span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  Github (r-lib/hugodown@fa43e45)         </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  Github (hadley/memoise@4aefd9f)         </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  Github (rstudio/rmarkdown@29aad5e)      </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  Github (r-lib/usethis@195ef14)          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt;  CRAN (R 4.0.0)                          </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span>
</code></pre>

</div>

The image at the top of this page is in the public domain, [and was downloaded from Pexels](https://www.pexels.com/photo/person-in-black-leather-boots-sitting-on-brown-cardboard-boxes-4553277/).

