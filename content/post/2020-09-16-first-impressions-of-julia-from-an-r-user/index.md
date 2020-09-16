---
title: First Impressions of Julia from an R User
author: ~
date: '2020-09-16'
slug: first-impressions-of-julia-from-an-r-user
tags:
    - julia
images: ["/img/julia.png"]
output: hugodown::md_document
rmd_hash: 557986af17c96074

---

It's no secret that I love R and begrudgingly use Python. But there's a another option for data science, and it promises the speed of C with the ease of use of R/Python. That language is Julia, and it's a *delight* to use. I took some time to learn the basics, and I'm sharing my impressions here.

Julia is not the most popular language in the world
---------------------------------------------------

Before I go on, there's one thing I want to stress here: Julia is not as popular as Python or R for doing stuff with data. It doesn't have the vast library of packages/modules that the veteran languages have built up over decades.

If this is a deal-breaker, then don't worry about Julia. If you want to use the languages with the most packages, or what looks best on your resume, then Python or R are better options. I'm not disparaging you either; these are good reasons.

But if you --- like me --- find that writing code to do stuff with data is *fun*, then it's well worth checking out Julia. I just wanted to get that common objection out of the way first.

Multiple dispatch
-----------------

People are often surprised to discover that R uses a lot of object-oriented programming. R objects store their classes as vectors, and can be accessed (and modified) with the `class` function:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'># R</span>
<span class='k'>a_tibble</span> <span class='o'>&lt;-</span> <span class='k'>tibble</span>::<span class='nf'><a href='https://tibble.tidyverse.org/reference/tibble.html'>tibble</a></span>(x = <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='m'>1</span>, <span class='m'>2</span>, <span class='m'>3</span>), y = <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='m'>4</span>, <span class='m'>5</span>, <span class='m'>6</span>))
<span class='nf'><a href='https://rdrr.io/r/base/class.html'>class</a></span>(<span class='k'>a_tibble</span>)

<span class='c'>#&gt; [1] "tbl_df"     "tbl"        "data.frame"</span>
</code></pre>

</div>

In R, the main implementation of object-oriented programming is through a system called *S3*. When I call a *generic function*, like `print`, R looks at the class of the first argument to determine which print *method* to use. If I `print` a data frame, then `print.data.frame` is used. If I print a linear model, then `print.lm` is used. And there are a lot of `print` methods:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'># R</span>
<span class='k'>sloop</span>::<span class='nf'><a href='https://sloop.r-lib.org/reference/s3_methods_class.html'>s3_methods_generic</a></span>(<span class='s'>"print"</span>)

<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 322 x 4</span></span>
<span class='c'>#&gt;    generic class       visible source             </span>
<span class='c'>#&gt;    <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>   </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>       </span><span style='color: #949494;font-style: italic;'>&lt;lgl&gt;</span><span>   </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>              </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 1</span><span> print   acf         FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 2</span><span> print   AES         FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 3</span><span> print   all_vars    FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 4</span><span> print   anova       FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 5</span><span> print   ansi_string FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 6</span><span> print   ansi_style  FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 7</span><span> print   any_vars    FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 8</span><span> print   aov         FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 9</span><span> print   aovlist     FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>10</span><span> print   ar          FALSE   registered S3method</span></span>
<span class='c'>#&gt; <span style='color: #949494;'># … with 312 more rows</span></span>
</code></pre>

</div>

This process of figuring out which method to use is called *dispatch*. S3 is a *single dispatch* system: only the classes of the first argument to the function are used to determine which method to call[^1]. Julia takes it a step further with *multiple dispatch*. And it works on *types*, not classes.

A simple example of multiple dispatch: animals
----------------------------------------------

Here's a simple example of multiple dispatch[^2]. I'll create an abstract type in Julia, called `Animal`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'># Julia
abstract type Animal end
</code></pre>

</div>

I'll now create two *subtypes* of animal: `Cat` and `Dog`. These will be each be a `struct`, which is a type composed of other types. In this case, each of the two new types will have a `Name` of type `String`, and Age of type `Int`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>struct Cat <: Animal
    Name::String 
    Age::Int
end

struct Dog <: Animal
    Name::String 
    Age::Int
end
</code></pre>

</div>

Now I'll define an `interaction` function which will output a string describing the interaction of two animals. Actually, I'll define 4 *methods* for this function. The method that's called will depend upon the types of *both* arguments:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>interaction(x::Cat, y::Cat) = "meow"


#> interaction (generic function with 1 method)

interaction(x::Dog, y::Dog) = "sniff"


#> interaction (generic function with 2 methods)

interaction(x::Cat, y::Dog) = "growl"


#> interaction (generic function with 3 methods)

interaction(x::Dog, y::Cat) = interaction(y, x)


#> interaction (generic function with 4 methods)
</code></pre>

</div>

In any other language, it would look like I'm defining a function and then overwriting it three times. But with Julia, functions are *unique up to name and type signature*. [`interaction(x::Cat, y::Cat)`](https://rdrr.io/r/base/interaction.html) has a type signature of `(Cat, Cat)` and [`interaction(x::Dog, y::Dog)`](https://rdrr.io/r/base/interaction.html) has a type signature of `(Dog, Dog)`. So instead of overwriting the function I simply add a new *generic* each time.

I'll define some cats and dogs based on those I know around my neighbourhood, such as the friendly golden retriever *Hudson* who always says good morning to me, or the stylish mini-whippet *Phoebe* who has a new outfit every time I see her. The semicolon here tells Julia to suppress the output:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>luna = Cat("Luna", 1);
pip = Cat("Pip", 5);
hudson = Dog("Hudson", 4);
phoebe = Dog("Phoebe", 1);
</code></pre>

</div>

And now lets see how these animals would interact:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>interaction(luna, pip)


#> "meow"

interaction(pip, luna)


#> "meow"

interaction(hudson, phoebe)


#> "sniff"

interaction(luna, phoebe)


#> "growl"
</code></pre>

</div>

Just as expected! These animals have different interactions based on their types.

Of course, I could accomplish the same thing with single dispatch and some if-else statements. But if I do that and I later want to extend the interactions to cover other animals, I have to go back and change those if-else statements. With Julia, it's just a matter of defining new functions.

Going up the type hierarchy
---------------------------

Earlier I defined an `Animal` type, which is a supertype of `Cat` and `Dog`. Julia will always use *the most specific method it can find*. If one doesn't exist for the exact types, then it will consider supertypes. I can demonstrate this by creating a generic with type signature `(Animal, Animal)`, to be used when no more specific function can be found:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>struct Gazelle <: Animal
    Name::String 
    Age::Int
end;

bob = Gazelle("Bob", 2);
interaction(x::Animal, y::Animal) = "flee";
interaction(hudson, bob)


#> "flee"
</code></pre>

</div>

I haven't defined a method like [`interaction(x::Dog, y::Gazelle)`](https://rdrr.io/r/base/interaction.html), so Julia goes up the type hierarchy to find [`interaction(x::Animal, y::Animal)`](https://rdrr.io/r/base/interaction.html) instead.

Multiple dispatch is a core concept of Julia, and one of the main reasons that it's so much faster than R or Python. Julia can compile fast functions for each type signature. And there are **a lot** of type signatures to consider. On my machine I count 184 methods for the [`+`](https://rdrr.io/r/base/Arithmetic.html) operator!

The power of macros
-------------------

I've become so used to R's metaprogramming features that I think I would struggle with any language that doesn't let me treat code as data to be manipulated. Julia delivers in the form of macros.

I'll give an example. In most languages, the `or` logical operator is short-circuited: If the first argument is true, then the second argument isn't evaluated. This behaviour exists in R with its [`||`](https://rdrr.io/r/base/Logic.html) short-circuited operator. If the first argument to [`||`](https://rdrr.io/r/base/Logic.html) is `TRUE`, then R doesn't evaluate the second argument. I can even make the second argument something that throws an error and R won't complain, as long as the first argument is `TRUE`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'># R</span>
<span class='nf'><a href='https://rdrr.io/r/base/stop.html'>stop</a></span>(<span class='s'>"Oh no!"</span>) <span class='o'>||</span> <span class='kc'>TRUE</span>

<span class='c'>#&gt; Error in eval(expr, envir, enclos): Oh no!</span>

<span class='kc'>TRUE</span> <span class='o'>||</span> <span class='nf'><a href='https://rdrr.io/r/base/stop.html'>stop</a></span>(<span class='s'>"Oh no!"</span>)

<span class='c'>#&gt; [1] TRUE</span>
</code></pre>

</div>

Suppose I wanted to create a *backwards-or* function, `bor`, that does the same thing but evaluates the second argument first. That is, I want a function `bor(x, y)` that acts just like [`||`](https://rdrr.io/r/base/Logic.html), but doesn't evaluate `x` is `y` is `TRUE`. This is pretty easy in R, and I don't even have to take advantage of metaprogramming, since R is lazily-evaluated:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'># R</span>
<span class='k'>bor</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>, <span class='k'>y</span>) <span class='k'>y</span> <span class='o'>||</span> <span class='k'>x</span>

<span class='nf'>bor</span>(<span class='kc'>TRUE</span>, <span class='nf'><a href='https://rdrr.io/r/base/stop.html'>stop</a></span>(<span class='s'>"Oh no!"</span>))

<span class='c'>#&gt; Error in bor(TRUE, stop("Oh no!")): Oh no!</span>

<span class='nf'>bor</span>(<span class='nf'><a href='https://rdrr.io/r/base/stop.html'>stop</a></span>(<span class='s'>"Oh no!"</span>), <span class='kc'>TRUE</span>)

<span class='c'>#&gt; [1] TRUE</span>
</code></pre>

</div>

Julia code is evaluated eagerly, so this won't work:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'># Julia
bor(x, y) = y || x
bor(error("Oh no!"), true)

# ERROR: Oh no!
# Stacktrace:
#  [1] error(::String) at ./error.jl:33
#  [2] top-level scope at REPL[38]:1
#  [3] include_string(::Function, ::Module, ::String, ::String) at ./loading.jl:1088
</code></pre>

</div>

A macro, however, lets me move code around *before it is evaluated*. Macros start with the [`@`](https://rdrr.io/r/base/slotOp.html) symbol:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>macro bor(a, b) 
    return :($b || $a)
end;
@bor(error("Oh no!"), true)


#> true
</code></pre>

</div>

The [`:`](https://rdrr.io/r/base/Colon.html) and [`$`](https://rdrr.io/r/base/Extract.html) symbols are the metaprogramming power here. The [`:`](https://rdrr.io/r/base/Colon.html) prefix converts to a symbol or expression, whereas [`$`](https://rdrr.io/r/base/Extract.html) evaluates or *interpolates* the expression. This is somewhat analogous to base R's `quote` and `eval` functions.

These two symbols can even be combined to perform what in R is sometimes called *quasiquotation*, where some things are quoted but others are explicitly evaluated:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>a = 1;
:($a + b)


#> :(1 + b)
</code></pre>

</div>

Reading in CSV data
-------------------

Now that I've laid down some core concepts of Julia, I'll share some of my experiences with using the language for the first time.

The first thing that impressed me was that Julia comes with its own package-management system: a package called `Pkg`. I tried to load the `DataFrames` package when it wasn't installed and Julia gave me the explicit command for installing it. Excellent!

Reading CSVs into a data frame works exactly like you would expect. It's pretty darn fast, though; I was able to load in [a 2GB CSV of StackExchange data](https://www.kaggle.com/stackoverflow/stacksample) in under 5 seconds, and my machine isn't very powerful.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>using DataFrames
using CSV

questions = CSV.read("Questions.csv")


#> 1264216×7 DataFrame. Omitted printing of 4 columns
#> │ Row     │ Id       │ OwnerUserId │ CreationDate         │
#> │         │ Int64    │ String      │ String               │
#> ├─────────┼──────────┼─────────────┼──────────────────────┤
#> │ 1       │ 80       │ 26          │ 2008-08-01T13:57:07Z │
#> │ 2       │ 90       │ 58          │ 2008-08-01T14:41:24Z │
#> │ 3       │ 120      │ 83          │ 2008-08-01T15:50:08Z │
#> │ 4       │ 180      │ 2089740     │ 2008-08-01T18:42:19Z │
#> │ 5       │ 260      │ 91          │ 2008-08-01T23:22:08Z │
#> │ 6       │ 330      │ 63          │ 2008-08-02T02:51:36Z │
#> │ 7       │ 470      │ 71          │ 2008-08-02T15:11:47Z │
#> ⋮
#> │ 1264209 │ 40143150 │ 5496690     │ 2016-10-19T23:31:41Z │
#> │ 1264210 │ 40143170 │ 2010246     │ 2016-10-19T23:33:42Z │
#> │ 1264211 │ 40143190 │ 333403      │ 2016-10-19T23:36:01Z │
#> │ 1264212 │ 40143210 │ 5610777     │ 2016-10-19T23:38:01Z │
#> │ 1264213 │ 40143300 │ 3791161     │ 2016-10-19T23:48:09Z │
#> │ 1264214 │ 40143340 │ 7028647     │ 2016-10-19T23:52:50Z │
#> │ 1264215 │ 40143360 │ 871677      │ 2016-10-19T23:55:24Z │
#> │ 1264216 │ 40143380 │ 6823982     │ 2016-10-19T23:57:31Z │
</code></pre>

</div>

I like how data frames print in Julia, with the type below the column name. Something that's missing here is a list of columns which have been omitted from printing, similar to the behaviour of the `tibble` package in R. And the data frame truncation is a little aggressive; sometimes columns are not printed even though there's room.

The `CSV.read` function uses multiple threads by default. I couldn't get this to work on my machine, and I had to restrict it to one thread. [I raised an issue on the GitHub page](https://github.com/JuliaData/CSV.jl/issues/721), and a maintainer came along to explain what was going on and implement a fix! What more can you ask for?

Data frames
-----------

Basic data frame functions are very similar to those in R:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>nrow(questions)


#> 1264216

ncol(questions)


#> 7

head(questions)


#> 6×7 DataFrame. Omitted printing of 3 columns
#> │ Row │ Id    │ OwnerUserId │ CreationDate         │ ClosedDate           │
#> │     │ Int64 │ String      │ String               │ String               │
#> ├─────┼───────┼─────────────┼──────────────────────┼──────────────────────┤
#> │ 1   │ 80    │ 26          │ 2008-08-01T13:57:07Z │ NA                   │
#> │ 2   │ 90    │ 58          │ 2008-08-01T14:41:24Z │ 2012-12-26T03:45:49Z │
#> │ 3   │ 120   │ 83          │ 2008-08-01T15:50:08Z │ NA                   │
#> │ 4   │ 180   │ 2089740     │ 2008-08-01T18:42:19Z │ NA                   │
#> │ 5   │ 260   │ 91          │ 2008-08-01T23:22:08Z │ NA                   │
#> │ 6   │ 330   │ 63          │ 2008-08-02T02:51:36Z │ NA                   │
</code></pre>

</div>

The `describe` function, analogous to R's `summary` function\`, is also quite nice. It presents a bit more information than the R equivalent, and it returns another data frame:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>describe(questions)


#> 7×8 DataFrame. Omitted printing of 6 columns
#> │ Row │ variable     │ mean      │
#> │     │ Symbol       │ Union…    │
#> ├─────┼──────────────┼───────────┤
#> │ 1   │ Id           │ 2.13275e7 │
#> │ 2   │ OwnerUserId  │           │
#> │ 3   │ CreationDate │           │
#> │ 4   │ ClosedDate   │           │
#> │ 5   │ Score        │ 1.78154   │
#> │ 6   │ Title        │           │
#> │ 7   │ Body         │           │
</code></pre>

</div>

And I can retrieve an individual column (as an array) with either `questions.Score` or `questions["Score"]`.

Piping
------

Julia supports piping. Thank goodness, too, because the `tidyverse` has spoilt me.

There's a native pipe `|>` which supposedly puts the value on the left as the first argument to the function on the right, but I found it a bit finnicky. The `Pipe` package improves this substantially by allowing the use of a `_` placeholder, for example, `@pipe 4 |> sqrt(_)`. This also opens up the possibility of piping into an argument other than the first. The only downside here is that a chain of piped functions must begin with the `@pipe` macro.

It would be neat if this `@pipe` macro were incorporated into base Julia, but on more than one occasion I've seen serious discussions in Julia for removing the base `|>` operator altogether. I hope that it stays, because a chain of piped functions is a beautiful sight.

Data manipulation
-----------------

I had a bit of trouble with `DataFrames` syntax. The easiest way I could find to manipulate data was to modify-in-place with a series of reassignments. I'll give an example. My `questions` data frame has a `Score` column. Suppose I want to scale it by 100, and then select all scores above 50 (this is some fairly arbitrary data manipulation). I then want to `describe` the data:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>questions2 = copy(questions);
questions2.Score = questions2.Score * 100;
questions2 = questions2[questions2.Score .> 50, :];
describe(questions2)


#> 7×8 DataFrame. Omitted printing of 6 columns
#> │ Row │ variable     │ mean      │
#> │     │ Symbol       │ Union…    │
#> ├─────┼──────────────┼───────────┤
#> │ 1   │ Id           │ 1.84611e7 │
#> │ 2   │ OwnerUserId  │           │
#> │ 3   │ CreationDate │           │
#> │ 4   │ ClosedDate   │           │
#> │ 5   │ Score        │ 403.745   │
#> │ 6   │ Title        │           │
#> │ 7   │ Body         │           │
</code></pre>

</div>

I had a much easier time with the `DataFramesMeta` package. This provides is an excellent, pipe-friendly package that implements some `dplyr`-like functionality, using macros:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>using Pipe
using DataFramesMeta

@pipe questions |> 
  @transform(_, Score = 100 * :Score) |>
  @where(_, :Score .> 50) |>
  describe(_)


#> 7×8 DataFrame. Omitted printing of 6 columns
#> │ Row │ variable     │ mean      │
#> │     │ Symbol       │ Union…    │
#> ├─────┼──────────────┼───────────┤
#> │ 1   │ Id           │ 1.84611e7 │
#> │ 2   │ OwnerUserId  │           │
#> │ 3   │ CreationDate │           │
#> │ 4   │ ClosedDate   │           │
#> │ 5   │ Score        │ 403.745   │
#> │ 6   │ Title        │           │
#> │ 7   │ Body         │           │
</code></pre>

</div>

Syntactic conventions
---------------------

In the above chain, I used `.>` to filter for values greater than 50. Julia functions and operators implement some very handy syntactic conventions that make life easier, and this is one of them. Vectorised operations are prefixed (or sometimes suffixed) with a dot:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'>x = ["a", "b", "c"]; y = ["a", "e", "c"];

x == y


#> false

x .== y


#> 3-element BitArray{1}:
#>  1
#>  0
#>  1
</code></pre>

</div>

(2020-09-16 correction: [Ari Katz](https://twitter.com/AriKatz20/status/1306018515426652162) points out that the dot is not a convention but an actual feature of the language that vectorises operators and functions in a fast and memory-efficient way. [See this post for more details](https://julialang.org/blog/2017/01/moredots/).)

Another convention is that functions that modify in place use an exclamation mark. For example, `df = sort(df)` is equivalent to `sort!(df)`. This often trips me up in Python, so I felt genuine relief to find that in Julia I don't have to guess whether or not a function will modify an argument in-place.

The real killer feature of Julia
--------------------------------

I've glossed over subjects like speed and compilation because these are areas which I'm not confident discussing. The rough idea is that Julia is *fast*, and the compiled code is often very similar to that of C. But a really powerful consequence of this is that *a user doesn't need to learn another language to become a contributor*.

If I want to write a new package/module for R/Python, and my use-case requires speedy code, then I'm pretty much obliged to drop down to C/C++. I have the original learning curve for the language I actually want to use, followed by a second learning curve for the lower language. With Julia it's just... Julia. All Julia. [This means that you can have a machine learning library that's 100% Julia code](https://fluxml.ai/).

Whenever I read the source code of an R/Python package and I see a reference to a file that ends with ".c" or ".h" I panic a little. Julia's killer feature is removing that panic moment. *Knowing Julia is enough to use Julia*.

Just give this language a go
============================

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
<span class='c'>#&gt;  date     2020-09-16                  </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; ─ Packages ───────────────────────────────────────────────────────────────────</span>
<span class='c'>#&gt;  package     * version    date       lib source                            </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports     1.1.9      2020-08-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  blob          1.2.1      2020-01-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  broom         0.7.0      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.4      2020-09-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cellranger    1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  colorspace    1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DBI           1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dbplyr        1.4.4      2020-05-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.1.0.9000 2020-09-15 [1] Github (r-lib/downlit@e420a84)    </span>
<span class='c'>#&gt;  dplyr       * 1.0.2      2020-08-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forcats     * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.5.0      2020-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics      0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggplot2     * 3.3.2.9000 2020-08-07 [1] Github (tidyverse/ggplot2@6d91349)</span>
<span class='c'>#&gt;  glue          1.4.2      2020-08-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gtable        0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  haven         2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.5.0      2020-06-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httr          1.4.2      2020-07-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-09-15 [1] Github (r-lib/hugodown@e4c6737)   </span>
<span class='c'>#&gt;  jsonlite      1.7.0      2020-06-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  JuliaCall     0.17.1     2019-11-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr         1.29       2020-06-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice       0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lubridate     1.7.9      2020-06-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Matrix        1.2-18     2019-11-27 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  modelr        0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  munsell       0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pillar        1.4.6      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild      1.1.0      2020-07-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.1.0      2020-05-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.4      2020-09-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.4      2020-08-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr       * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.5      2020-07-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr       * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readxl        1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reprex        0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reticulate    1.16       2020-05-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.7      2020-07-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.3.5      2020-09-15 [1] Github (rstudio/rmarkdown@949c7e3)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rstudioapi    0.11       2020-02-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rvest         0.3.5      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  scales        1.1.1      2020-05-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sloop         1.0.1      2019-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.5.3      2020-09-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr     * 1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble      * 3.0.3      2020-07-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyr       * 1.1.1      2020-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect    1.1.0      2020-05-11 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyverse   * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  utf8          1.1.4      2018-05-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs         0.3.4      2020-08-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.17       2020-09-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xml2          1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span>
</code></pre>

</div>

The Julia logo at the top of this image is the intellectual property of Stefan Karpinski, [who allows its use for non-commercial purposes](https://discourse.julialang.org/t/trademark-guidelines-fair-use-policy-for-julia-name-logo/3404/4).

[^1]: The S4 system is capable of multiple dispatch.

[^2]: This example was discussed in a StackOverflow post that I can no longer find.

