---
title: R on AWS Lambda with Containers
author: ~
date: '2020-12-06'
slug: r-on-aws-lambda-with-containers
tags:
    - r
    - cloud
images: ["/img/successful-test.png"]
output: hugodown::md_document
rmd_hash: f298890dd700205c

---

[AWS has announced support for container images](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/) for their serverless computing platform *Lambda*. AWS doesn't provide an R runtime for Lambda, and this was the excuse I needed to finally try to make one.

An R runtime means that I can take advantage of AWS Lambda to put my R functions in the cloud. I don't have to worry about provisioning servers or spinning up containers --- the function itself is the star. And from the perspective of the service calling Lambda, it doesn't matter what language that function is written in.

Also, someone told me that you can't use R on Lambda, and I took that *personally*.

I don't have to learn Lambda layers
-----------------------------------

"Container support" is potentially confusing here. To clarify, we can't take any container and expect Lambda to work with it. The container needs to provide a Lambda *runtime*, or use one of the available runtimes, in order to have Lambda communicate with the functions. Runtimes are provided for a handful of languages, but not for R.

I'm not the first person to put an R function on Lambda. [Previous attempts used Lambda *layers*](https://medium.com/bakdata/running-r-on-aws-lambda-9d40643551a6). But with container support I can disregard that layer stuff and use Dockerfiles, which is a concept I already have some experience with. And by writing the runtime in R itself I can share a single R session between subsequent requests, cutting down on execution time.

My goal here is to host a function written entirely in R --- in this case, a simple `parity` function that determines if an integer is odd or even. I stick this in a container, along with a Lambda runtime written entirely in R, and then I'm able to invoke the function on AWS.

I'll talk through the process below, but if you're the kind of person who likes to read the last page of a book first then [you can take a look at my git repository](https://github.com/mdneuzerling/r-on-lambda).

How to make R and Lambda talk to each other
-------------------------------------------

AWS provides [some documentation for creating a custom runtime](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html#runtimes-custom-build), and it's pretty good. The rough idea is that the Lambda *event* which initiates the function invocation sits at a HTTP endpoint. My R runtime needs to constantly query that endpoint. The eventual response has a body that contains the arguments that my R function needs. The R runtime has to run the function with those arguments and then send the results to a specific HTTP endpoint. Afterwards it checks the event endpoint again.

I'll need the `httr` package for sending requests to HTTP endpoints, and the `jsonlite` package to convert the response body from a JSON to an R list, and the function result from an R list to a JSON. It's all JSONS. That's why I build my `parity` function to return a list. The `jsonlite` package will take a result like [`list(parity = "even")`](https://rdrr.io/r/base/list.html) and turn it into `{"parity": "even"}` which non-R services can understand.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nv'>parity</span> <span class='o'>&lt;-</span> <span class='kr'>function</span><span class='o'>(</span><span class='nv'>number</span><span class='o'>)</span> <span class='o'>{</span>
  <span class='nf'><a href='https://rdrr.io/r/base/list.html'>list</a></span><span class='o'>(</span>parity <span class='o'>=</span> <span class='kr'>if</span> <span class='o'>(</span><span class='nf'><a href='https://rdrr.io/r/base/integer.html'>as.integer</a></span><span class='o'>(</span><span class='nv'>number</span><span class='o'>)</span> <span class='o'>%%</span> <span class='m'>2</span> <span class='o'>==</span> <span class='m'>0</span><span class='o'>)</span> <span class='s'>"even"</span> <span class='kr'>else</span> <span class='s'>"odd"</span><span class='o'>)</span>
<span class='o'>}</span>
</code></pre>

</div>

My code does the following:

1.  Load all necessary environment variables and determine the Lambda endpoints
2.  Determine the source file and function from the *handler*
3.  Source the file containing the code and check that the function is available
4.  Listen for events until there's a response
5.  Pull the request ID and other information from the response headers
6.  Parse the body of the request into an R list
7.  Call the function with the body as its arguments
8.  Send the result to the endpoint for that specific event
9.  Listen for more events

Environment variables and headers
---------------------------------

AWS Lambda sets a few environment variables that my code needs to be able to capture. The first is `LAMBDA_TASK_ROOT`, which is the path to the working directory for the function. In the Dockerfile, all of the R code will be copied here, where the runtime will look for it.

There's also the `_HANDLER`, which is a string of the form "file.function". I put the code for my `parity` function in a file called `functions.R`, so my handler will be "functions.parity"; I make my runtime automatically append the ".R" extension. I can set the handler either as the `CMD` of the Dockerfile or through the AWS Lambda console (which takes precedence). Afterwards, it is made available as an environment variable to my runtime.

The `AWS_LAMBDA_RUNTIME_API` is used to piece together the different HTTP endpoints needed to communicate with Lambda:

-   The next invocation endpoint is used to get the next event.
-   The initialisation error endpoint is where errors should be sent if there was a problem setting up the runtime.
-   The invocation response endpoint is unique to each event. It's where a successful function result should be sent.
-   The invocation error endpoint is where errors should be sent if there was a problem during function execution. It is also unique to each event.

Every event that comes through has a request ID header, named "lambda-runtime-aws-request-id"[^1]. This uniquely identifies the event, and is used to construct the event-specific HTTP endpoints.

Finally there's also a "lambda-runtime-trace-id" header. The AWS guide suggest setting this as the value of the `_X_AMZN_TRACE_ID` environment ID. Curiously, that seems to be the only action required. I was expecting to have to pass this header on in the response, but apparently not. It's used as part of AWS's *X-Ray SDK*.

Turning JSON into something R can understand
--------------------------------------------

The body of the `event`, which is the response from the next invocation endpoint, contains the arguments that my function needs. If the body is empty then there are no arguments and my function *should* accept no arguments in this case. I interpret the body as an empty list. Otherwise, I use the `jsonlite` package to parse the JSON body into an R list. This is a particularly sensitive area of the runtime; JSON parsing is a fragile process.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nv'>unparsed_content</span> <span class='o'>&lt;-</span> <span class='nf'>httr</span><span class='nf'>::</span><span class='nf'><a href='https://httr.r-lib.org/reference/content.html'>content</a></span><span class='o'>(</span><span class='nv'>event</span>, <span class='s'>"text"</span>, encoding <span class='o'>=</span> <span class='s'>"UTF-8"</span><span class='o'>)</span>
<span class='nv'>event_content</span> <span class='o'>&lt;-</span> <span class='kr'>if</span> <span class='o'>(</span><span class='nv'>unparsed_content</span> <span class='o'>==</span> <span class='s'>""</span><span class='o'>)</span> <span class='o'>{</span>
  <span class='nf'><a href='https://rdrr.io/r/base/list.html'>list</a></span><span class='o'>(</span><span class='o'>)</span>
<span class='o'>}</span> <span class='kr'>else</span> <span class='o'>{</span>
  <span class='nf'>jsonlite</span><span class='nf'>::</span><span class='nf'><a href='https://rdrr.io/pkg/jsonlite/man/fromJSON.html'>fromJSON</a></span><span class='o'>(</span><span class='nv'>unparsed_content</span><span class='o'>)</span>
<span class='o'>}</span>
</code></pre>

</div>

From this point I can call the function with this list of arguments:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/do.call.html'>do.call</a></span><span class='o'>(</span><span class='nv'>function_name</span>, <span class='nv'>event_content</span><span class='o'>)</span>
</code></pre>

</div>

The runtime sends the result to the appropriate HTTP endpoint and listens for the next event. And that's the runtime done.

Stick it in a container
-----------------------

The Dockerfile starts with the AWS base image for Lambda[^2] that contains the bits and pieces needed to host the function. I install R as if it were a CentOS image, and remove the installer afterwards to save a little space. There are some path issues here: I need to append the location of the R binaries to the system PATH, and manually specify the CRAN repository when installing R packages.

In order to run my runtime, I need to provide the container with a *bootstrap*. This bootstrap isn't particularly complicated: it's an executable script that changes the working directory to the value of the `LAMBDA_TASK_ROOT` environment variable and runs the `runtime.R` file:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>#!/bin/sh
cd $LAMBDA_TASK_ROOT
Rscript runtime.R
</code></pre>

</div>

I think such a small and simple script doesn't need to be a file, so I hardcode it within the Dockerfile itself. Here's the Dockerfile I end up with:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>FROM public.ecr.aws/lambda/provided

ENV R_VERSION=4.0.3

RUN yum -y install wget

RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && wget https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
  && yum -y install R-${R_VERSION}-1-1.x86_64.rpm \
  && rm R-${R_VERSION}-1-1.x86_64.rpm

ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

# System requirements for R packages
RUN yum -y install openssl-devel

RUN Rscript -e "install.packages(c('httr', 'jsonlite', 'logger'), repos = 'https://cloud.r-project.org/')"

COPY runtime.R functions.R ${LAMBDA_TASK_ROOT}/
RUN chmod 755 -R ${LAMBDA_TASK_ROOT}/

RUN printf '#!/bin/sh\ncd $LAMBDA_TASK_ROOT\nRscript runtime.R' > /var/runtime/bootstrap \
  && chmod +x /var/runtime/bootstrap
</code></pre>

</div>

I haven't set any entrypoint or command for this container. The default entrypoint for the parent image is a shell script for AWS Lambda, and I don't want to interfere with that. The command is the handler for the function. I could hardcode that here as with `CMD ["functions.parity"]`, but instead I configure it later within the AWS Lambda management console.

Test the function locally
-------------------------

The Lambda base image lets me test my function locally by running the container and then querying a HTTP endpoint. I start by navigating to the project directory and building the image:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>docker build -t mdneuzerling/r-on-lambda .
</code></pre>

</div>

I run the image by providing it with the handler as the command. Recall that I want to use the `parity` function from the `functions.R` file:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>docker run -p 9000:8080 mdneuzerling/r-on-lambda "functions.parity"
</code></pre>

</div>

In a separate shell I query the endpoint:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" \
-d '{"number": 5}'
</code></pre>

</div>

I receive the response `{"parity":"odd"}` which --- for the number 5 --- is correct[^3]. The STDOUT of the main window contains the log entries. There are some messages and warnings here that I choose to ignore:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>time="2020-12-05T21:56:04.914" level=info msg="exec '/var/runtime/bootstrap' (cwd=/var/task, handler=)"
time="2020-12-05T21:56:46.953" level=info msg="extensionsDisabledByLayer(/opt/disable-extensions-jwigqn8j) -> stat /opt/disable-extensions-jwigqn8j: no such file or directory"
time="2020-12-05T21:56:46.953" level=warning msg="Cannot list external agents" error="open /opt/extensions: no such file or directory"
START RequestId: ff9ed881-8874-48f6-b67f-6b271e9afd3c Version: $LATEST
logger: As the "glue" R package is not installed, using "sprintf" as the default log message formatter instead of "glue".
INFO [2020-12-05 21:56:47] Handler found: functions.parity
INFO [2020-12-05 21:56:47] Using function parity from functions.R
INFO [2020-12-05 21:56:47] Querying for events
END RequestId: ff9ed881-8874-48f6-b67f-6b271e9afd3c
REPORT RequestId: ff9ed881-8874-48f6-b67f-6b271e9afd3c  Init Duration: 0.43 ms  Duration: 332.66 ms Billed Duration: 400 ms Memory Size: 3008 MB    Max Memory Used: 3008 MB
</code></pre>

</div>

Push the image to AWS
---------------------

The container image needs to be available on AWS in order for Lambda to use it. That is, the image needs to be hosted on AWS's [*Elastic Container Registry*](https://aws.amazon.com/ecr/). [The AWS announcement of container support provides some good instructions for pushing an image](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/), but I'll briefly cover it here.

Container support isn't available for every region yet, so I switch to the *us-east-1* region using the AWS CLI:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>aws configure set region us-east-1
</code></pre>

</div>

Then, following the instructions from the announcement, I create a repository for my image.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>aws ecr create-repository --repository-name r-on-lambda --image-scanning-configuration scanOnPush=true
</code></pre>

</div>

This command gives me information about the repository, including a URI. In my case, the URI takes on the form "{AWS account number}.dkr.ecr.us-east-1.amazonaws.com". The next step involves re-tagging my image to include this URI, and then pushing the image to ECR:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>docker tag mdneuzerling/r-on-lambda:latest {URI}/r-on-lambda:latest
aws ecr get-login-password | docker login --username AWS --password-stdin {URI}
docker push {URI}/r-on-lambda:latest
</code></pre>

</div>

Set up a Lambda function
------------------------

From the AWS Management Console I change my region to "us-east-1". On the Lambda page I create a new function, and I see the new option to use a container image. I select the container I just uploaded and click "Create Function".

![](create-function.png)

It takes a few seconds before I see the function configuration page. I need to make one change here. I didn't set a `CMD` in my Dockerfile, so I need to edit the image configuration to specify the handler. I want to use the `parity` function from the `functions.R` source file, so I override the `CMD` to "functions.parity".

![](image-configuration.png)

Now I'll configure a test to check that my function is working. The "Test" button, towards the top-right of the console, prompts me define a test JSON payload:

![](configure-test-event.png)

Afterwards, I click the "Test" button again and see the results:

![](successful-test.png)

The function is working! As a final check I'll invoke the function through the AWS CLI:

    aws lambda invoke --function-name parity --invocation-type RequestResponse --payload '{"number": 8}' /tmp/response.json

And, sure enough, the `response.json` file contains the expected `{"parity":"even"}` result.

The performance isn't fantastic. Each invocation takes about 120ms. The initalisation time is 7 seconds, reduced to 2.3 seconds if I increase the available memory to the maximum of 10GB. This seems slow to me, but then again I don't have a good baseline for container-based Lambda functions. The initialisation penalty is only incurred if the function hasn't been called for a while --- for requests in quick succession the image is kept alive.

Logging is good
---------------

I had a lot of trouble getting this to work, and the main reason for that is that the errors that came from my code were often not the actual errors. I also had no way to step through the code. Logging really helped me with debugging. I've had a few people ask me to talk about logging, so I'll talk through it here.

Logs are records generated as the code runs that are saved to a file or otherwise captured to be stored after the program has finished. I might log the status of my program, the information it receives, or any errors or warnings that it encounters. There are a few packages that support logging and they all tend to follow the same conventions. I'm using the `logger` package by [Gergely Daróczi](https://twitter.com/daroczig?lang=en).

Logging has the potential to generate a lot of information, and a good way to simplify this is to take advantage of log *levels*. There are many levels, but the five common ones --- in increasing order of severity --- are: *debug*, *info*, *warn*, *error*, and *fatal*. By setting a *threshold* I can encourage my logger to ignore entries below a certain level. In my runtime I set the threshold to *info*, but if I'm encountering errors and I want more detail than I can lower this to *debug* so that all of the debug-level log entries come through.

Logs can be stored to files or simply printed to `STDOUT`. AWS's logging service, Cloudwatch, will capture the STDOUT logs. I didn't have to do anything to set this up, so I assume that it's automatic.

I'll give an example. I was having some trouble sourcing the file, and I wanted to make sure that my code was interpreting and splitting the handler. I used some *info*-level log entries to record the handler that the code discovers, and how it's split. If I'm debugging, I want to be more verbose about how I'm treating this information, so I also record that I'm about to check if the source file exists:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nv'>handler</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/Sys.getenv.html'>Sys.getenv</a></span><span class='o'>(</span><span class='s'>"_HANDLER"</span><span class='o'>)</span>
<span class='nf'>log_info</span><span class='o'>(</span><span class='s'>"Handler found:"</span>, <span class='nv'>handler</span><span class='o'>)</span>
<span class='nv'>handler_split</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/strsplit.html'>strsplit</a></span><span class='o'>(</span><span class='nv'>handler</span>, <span class='s'>"."</span>, fixed <span class='o'>=</span> <span class='kc'>TRUE</span><span class='o'>)</span><span class='o'>[[</span><span class='m'>1</span><span class='o'>]</span><span class='o'>]</span>
<span class='nv'>file_name</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span><span class='o'>(</span><span class='nv'>handler_split</span><span class='o'>[</span><span class='m'>1</span><span class='o'>]</span>, <span class='s'>".R"</span><span class='o'>)</span>
<span class='nv'>function_name</span> <span class='o'>&lt;-</span> <span class='nv'>handler_split</span><span class='o'>[</span><span class='m'>2</span><span class='o'>]</span>
<span class='nf'>log_info</span><span class='o'>(</span><span class='s'>"Using function"</span>, <span class='nv'>function_name</span>, <span class='s'>"from"</span>, <span class='nv'>file_name</span><span class='o'>)</span>
<span class='nf'>log_debug</span><span class='o'>(</span><span class='s'>"Checking if"</span>, <span class='nv'>file_name</span>, <span class='s'>"exists"</span><span class='o'>)</span>
<span class='c'># ...</span>
</code></pre>

</div>

It's easy to log too much, or log useless information. Good logging takes into account how the log entries might be used. In my case, the logging that AWS Lambda does automatically is usually sufficient, so I introduce minimal information with my log entries. But since I can't step through the runtime, I rely on the debug-level logging to resolve bugs.

A smarter option here might even be to use an environment variable to configure the log threshold, since that way I wouldn't need to rebuild the container image to debug.

Looking towards the `future`
----------------------------

I had a quick go at trying to introduce asynchronous programming using the `future` package. I didn't have much luck, because a new event wasn't available at the `next` endpoint before the current request was submitted. I suspect that there are some complexities to getting Lambda to run asynchronously with which I'm just not familiar.

But on the whole, I'm pretty happy with this! My runtime is generic enough that --- apart from the usual complexities of managing R dependencies --- I don't need to worry about changing it for each function. And managing R dependencies with Dockerfiles is a well-studied problem.

------------------------------------------------------------------------

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>devtools</span><span class='nf'>::</span><span class='nf'><a href='https://rdrr.io/pkg/sessioninfo/man/session_info.html'>session_info</a></span><span class='o'>(</span><span class='o'>)</span>

<span class='c'>#&gt; ─ Session info ───────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  setting  value                       </span>
<span class='c'>#&gt;  version  R version 4.0.2 (2020-06-22)</span>
<span class='c'>#&gt;  os       Ubuntu 20.04.1 LTS          </span>
<span class='c'>#&gt;  system   x86_64, linux-gnu           </span>
<span class='c'>#&gt;  ui       X11                         </span>
<span class='c'>#&gt;  language en_AU:en                    </span>
<span class='c'>#&gt;  collate  en_AU.UTF-8                 </span>
<span class='c'>#&gt;  ctype    en_AU.UTF-8                 </span>
<span class='c'>#&gt;  tz       Australia/Melbourne         </span>
<span class='c'>#&gt;  date     2020-12-06                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib source                            </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports     1.1.10     2020-09-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.4      2020-09-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.2.0      2020-10-03 [1] Github (r-lib/downlit@df73cf3)    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.5.0      2020-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.2      2020-08-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-10-03 [1] Github (r-lib/hugodown@fa43e45)   </span>
<span class='c'>#&gt;  knitr         1.30       2020-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  pkgbuild      1.1.0      2020-07-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.1.0      2020-05-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.4      2020-09-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.4      2020-08-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr         0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.7      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.4.1      2020-10-03 [1] Github (rstudio/rmarkdown@29aad5e)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.5.3      2020-09-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr       1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.9.0.9000 2020-10-10 [1] Github (r-lib/usethis@195ef14)    </span>
<span class='c'>#&gt;  vctrs         0.3.4      2020-08-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.3.0      2020-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.18       2020-09-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span>
</code></pre>

</div>

[^1]: HTTP header names are supposedly case-insensitive, and the `httr` package appears to return lower-case names.

[^2]: I may be using an image here that is soon to be deprecated. The Amazon Linux 2 image would be a safer option.

[^3]: Exercise left to reader.

