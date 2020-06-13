---
title: 'useR: Missing values imputation'
author: ''
slug: 'user-missing-values-imputation'
date: '2018-07-11'
categories: []
tags: [R, conference]
images: ["/img/useR/tutorial_three.png"]
featuredalt: "useR2018 Tutorial Three"
output: hugodown::hugo_document
rmd_hash: 59b5904b74c0d079

---

These are my notes for the third and final tutorial of useR2018, and the tutorial I was looking forward to the most. I *struggle* with missing value imputation. It's one of those things which I kind of get the theory of, but fall over when trying to *do*. So I was keen to hear [Julie Joss](https://twitter.com/juliejossestat) and [Nick Tierney](https://twitter.com/nj_tierney) talk about their techniques and associated R packages.

<div class="highlight">

<!--html_preserve-->
{{% tweet "1015223952594128897" %}}<!--/html_preserve-->

</div>

I ran into a wall pretty early on here in that I wasn't very comfortable with Principal Component Analysis (PCA). I took the opportunity to learn a bit more about this common technique, and try to understand the intuition behind it.

The data and slides for Julie's and Nick's tutorial are available on [Nick's GitHub](https://github.com/njtierney/user2018-missing-data-tutorial).

Required packages:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/utils/install.packages.html'>install.packages</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"tidyverse"</span>, <span class='s'>"ggplot2"</span>, <span class='s'>"naniar"</span>, <span class='s'>"visdat"</span>, <span class='s'>"missMDA"</span>))</code></pre>

</div>

`Ozone` data set
----------------

The data in use today is the Ozone data set from Airbreizh, a French association that monitors air quality. We're only going to focus on the quantitative variables here, so we will drop the `WindDirection` variable.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>ozone</span> <span class='o'>&lt;-</span> <span class='nf'>read_csv</span>(<span class='s'>"ozoneNA.csv"</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='o'>-</span><span class='k'>X1</span>, <span class='o'>-</span><span class='k'>WindDirection</span>) <span class='c'># unnecessary row index</span>
<span class='c'>#&gt; Parsed with column specification:</span>
<span class='c'>#&gt; cols(</span>
<span class='c'>#&gt;   X1 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   maxO3 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   T9 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   T12 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   T15 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   Ne9 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   Ne12 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   Ne15 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   Vx9 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   Vx12 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   Vx15 = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   maxO3v = <span style='color: #00BB00;'>col_double()</span><span>,</span></span>
<span class='c'>#&gt;   WindDirection = <span style='color: #BB0000;'>col_character()</span></span>
<span class='c'>#&gt; )</span></code></pre>

</div>

Patterns of missing data
------------------------

The easiest way to deal with missing data is to delete it. But this ignores any pattern in the missing data, as well as any mechanism that leads to missing values. Some data sets can also contain a majority of values that have at least one missing value, and so deleting missing values would delete most of the data!

Missing values occur in three main patterns based on their relationship with the observed and even the unobserved variables of the data:

-   Missing Completely at Random (**MCAR**): probability of data being missing is independent of the observed and unobserved variables.
-   Missing at Random (**MAR**): probability is not independent of the observed values (ie. is not random) but the observed variables do not fully account for the pattern. In this case, there may be unobserved variables affecting the probability that the data will be missing.
-   Missing not at random (**MNAR**): probability of data being missing depends on the observed values of the data.

Visualising missing data
------------------------

*Multiple correspondence analysis* visualises data in such a way that relationships between missing values are often made apparent. One implementation of this is the `naniar` package:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='http://visdat.njtierney.com//reference/vis_miss.html'>vis_miss</a></span>(<span class='k'>ozone</span>)
</code></pre>
<img src="figs/missing_naniar-1.png" width="700px" style="display: block; margin: auto;" />

</div>

We can repeat the visualisation with an option to `cluster` the missing values, making it easier to spot patterns, if any.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='http://visdat.njtierney.com//reference/vis_miss.html'>vis_miss</a></span>(<span class='k'>ozone</span>, cluster = <span class='kc'>TRUE</span>)
</code></pre>
<img src="figs/missing_naniar_cluster-1.png" width="700px" style="display: block; margin: auto;" />

</div>

Dealing with missing values
---------------------------

Suppose we *don't* want to delete our missing data and pretend that everything is fine. Then we might look to *impute* the missing values. That is to say, we might want to look at the data we do have to determine what the missing values might have been.

One of the easiest methods of imputation is that of *mean imputation*. In this case, we replace all of the missing values by the mean of the present values of the given variable.

We could also define a model on the present values of the data to predict what the missing value might have been. A simple linear regression might suffice.

A more sophisticated method involves the use of Principal Component Analysis.

A refresher on PCA
------------------

I don't understand Principal Component Analysis (PCA). Believe me, I've tried.

The goal of PCA is to find the subspace that best represents the data. The outcome of PCA is a set of uncorrelated variables called *principal components*.

[This is a wonderful (but long) article on PCA](http://www.cs.otago.ac.nz/cosc453/student_tutorials/principal_components.pdf) (pdf). It's gentle without being patronising. I'll highlight some points in the article here, but it's well worth finding the time to read the article in full.

First of all, recall the definition of an *eigenvector*. You probably encountered this in your first or second year of university, and then promptly forgot it. In the example below, the column vector $(6, 4)^T$ is an eigenvector of the square matrix, because the result of the matrix multiplication is a scale multiple of $(6, 4)^T$. In other words, the square matrix makes the eigenvector *bigger*, but it doesn't change its *direction*. The scalar multiple is $4$, and that's the *eigenvalue* associated with the eigenvector.

$$
\left(\begin{array}{cc} 
2 & 3 \\
2 & 1
\end{array}\right) \times
\left(\begin{array}{c} 
6 \\
4
\end{array}\right) = 
\left(\begin{array}{c} 
24 \\
16
\end{array}\right) = 
4 \left(\begin{array}{c} 
6 \\
4
\end{array}\right)
$$ But how does this relate to stats? Well a data set gives rise to a *covariance matrix*, in which the $ij$th cell of the matrix is the covariance between the $i$th variable and the $j$th variable (the variance of each variable sits along the diagonal). This is a square matrix, so we can find some eigenvectors.

I don't remember a whole lot of the linear algebra I learnt a long time ago, so I had to be reminded of two quick theorems in play here. A covariance matrix is symmetric, so we can make use of the following:

-   Eigenvectors of real symmetric matrices are real
-   Eigenvectors of real symmetric matrices are orthogonal

<div class="highlight">

<!--html_preserve-->
{{% tweet "997147577173925888" %}}<!--/html_preserve-->

</div>

Let's go through an example. Take the classic `mtcars` data set, and draw a scatterplot between `wt` (weight) and `mpg` (miles per gallon). We're going to work on data that's been centered and rescaled so as to make the eigenvectors look right, as well as for other reasons that will become apparent soon.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>mtcars_scaled</span> <span class='o'>&lt;-</span> <span class='k'>mtcars</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>wt</span>, <span class='k'>mpg</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>mutate_all</span>(<span class='k'>scale</span>)
<span class='k'>mtcars_scaled</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggplot.html'>ggplot</a></span>(<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='k'>wt</span>, y = <span class='k'>mpg</span>)) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_point.html'>geom_point</a></span>() <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/coord_fixed.html'>coord_fixed</a></span>() <span class='c'># makes the plot square</span>
</code></pre>
<img src="figs/mtcars-1.png" width="700px" style="display: block; margin: auto;" />

</div>

Let's calculate the PCA eigenvectors. These are eigenvectors of the covariance matrix. Because we have two variables we have two eigenvectors (another property of symmetric matrices), which we'll call `PC1` and `PC2`. You don't need a install a package to calculate these, as we can use the preinstalled `prcomp` function.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>PC</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/stats/prcomp.html'>prcomp</a></span>(<span class='o'>~</span> <span class='k'>wt</span> <span class='o'>+</span> <span class='k'>mpg</span>, data = <span class='k'>mtcars_scaled</span>)
<span class='k'>PC</span>
<span class='c'>#&gt; Standard deviations (1, .., p=2):</span>
<span class='c'>#&gt; [1] 1.3666233 0.3637865</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Rotation (n x k) = (2 x 2):</span>
<span class='c'>#&gt;            PC1       PC2</span>
<span class='c'>#&gt; wt   0.7071068 0.7071068</span>
<span class='c'>#&gt; mpg -0.7071068 0.7071068</span></code></pre>

</div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>PC1</span> <span class='o'>&lt;-</span> <span class='k'>PC</span><span class='o'>$</span><span class='k'>rotation</span>[,<span class='m'>1</span>]
<span class='k'>PC2</span> <span class='o'>&lt;-</span> <span class='k'>PC</span><span class='o'>$</span><span class='k'>rotation</span>[,<span class='m'>2</span>]

<span class='k'>mtcars_scaled</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggplot.html'>ggplot</a></span>(<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='k'>wt</span>, y = <span class='k'>mpg</span>)) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_point.html'>geom_point</a></span>() <span class='o'>+</span>
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_segment.html'>geom_segment</a></span>(<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='m'>0</span>, xend = <span class='k'>PC1</span>[[<span class='s'>"wt"</span>]], y = <span class='m'>0</span>, yend = <span class='k'>PC1</span>[[<span class='s'>"mpg"</span>]]), arrow = <span class='nf'><a href='https://rdrr.io/r/grid/arrow.html'>arrow</a></span>(length = <span class='nf'><a href='https://rdrr.io/r/grid/unit.html'>unit</a></span>(<span class='m'>0.5</span>, <span class='s'>"cm"</span>)), col = <span class='s'>"red"</span>) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_segment.html'>geom_segment</a></span>(<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='m'>0</span>, xend = <span class='k'>PC2</span>[[<span class='s'>"wt"</span>]], y = <span class='m'>0</span>, yend = <span class='k'>PC2</span>[[<span class='s'>"mpg"</span>]]), arrow = <span class='nf'><a href='https://rdrr.io/r/grid/arrow.html'>arrow</a></span>(length = <span class='nf'><a href='https://rdrr.io/r/grid/unit.html'>unit</a></span>(<span class='m'>0.5</span>, <span class='s'>"cm"</span>)), col = <span class='s'>"red"</span>) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/coord_fixed.html'>coord_fixed</a></span>() <span class='c'># makes the plot square</span>
</code></pre>
<img src="figs/mtcars_pc-1.png" width="700px" style="display: block; margin: auto;" />

</div>

Look at those eigenvectors! The eigenvectors used in PCA are always normalised, so that the magnitude of the vectors are all $1$. That is, we have some mutually orthogonal unit vectors...it's a **change of basis**! Any point in the data set can be described by the original $x$ and $y$ axes, but it can also be described by a linear combination of our new PC eigenvectors!

So we haven't done anything to the data yet, apart from some basic scaling and centering. But every eigenvector has an associated eigenvalue. In this case, the higher the eigenvalue, the more the eigenvector is stretched by the (modified) covariance matrix. That is to say, the higher the eigenvalue, **the more variance explained by the eigenvector**. This is why we had to rescale the data so that each variable starts with a variance of $1$---if we didn't, the variables with higher variance, such as `mpg`, would appear artifically more important.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/summary.html'>summary</a></span>(<span class='k'>PC</span>)
<span class='c'>#&gt; Importance of components:</span>
<span class='c'>#&gt;                           PC1     PC2</span>
<span class='c'>#&gt; Standard deviation     1.3666 0.36379</span>
<span class='c'>#&gt; Proportion of Variance 0.9338 0.06617</span>
<span class='c'>#&gt; Cumulative Proportion  0.9338 1.00000</span></code></pre>

</div>

PCA's primary use is for dimension reduction. You can use the ranking of the eigenvalues to determine what eigenvectors contribute the most to the variance of the data. You'll drop a dimension by losing some of your information, but it will be the least valuable information.

PCA imputation
--------------

At this point I had re-learnt enough PCA to get by, Time to revisit the matter of missing data!

Here's how this works. First we need to choose a number of dimensions $S$ to keep at each step (more about this later).

1.  Start with mean imputation, which assigns the variable mean to every missing value.
2.  Apply PCA and keep $S$ dimensions.
3.  Re-impute the missing values with the new mean.
4.  Repeat steps 2 and 3 until the values converge.

The `missMDA` package handles this for us. First we need to work out how many dimensions we want to keep when doing our PCA. The `missMDA` package contains an `estim_ncpPCA` function that helps us determine the value of $S$ that minimises the **mean squared error of prediction (MSEP)**.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>nb</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/pkg/missMDA/man/estim_ncpPCA.html'>estim_ncpPCA</a></span>(<span class='k'>ozone</span>, method.cv = <span class='s'>"Kfold"</span>)</code></pre>

</div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggplot.html'>ggplot</a></span>(data = <span class='kr'>NULL</span>, <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='m'>0</span><span class='o'>:</span><span class='m'>5</span>, y = <span class='k'>nb</span><span class='o'>$</span><span class='k'>criterion</span>)) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_point.html'>geom_point</a></span>() <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_path.html'>geom_line</a></span>() <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/labs.html'>xlab</a></span>(<span class='s'>"nb dim"</span>) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/labs.html'>ylab</a></span>(<span class='s'>"MSEP"</span>)
</code></pre>
<img src="figs/ozone_PCA_plot-1.png" width="700px" style="display: block; margin: auto;" />

</div>

We can see that the MSEP is minimised when the $S$ is 2, a number we can also access with `nb$ncp`. We can now perform the actual PCA imputation. This doesn't work with tibbles, so I convert the data to a data frame before piping it into the impute function.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>ozone_comp</span> <span class='o'>&lt;-</span> <span class='k'>ozone</span> <span class='o'>%&gt;%</span> <span class='k'>as.data.frame</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/pkg/missMDA/man/imputePCA.html'>imputePCA</a></span>(ncp = <span class='k'>nb</span><span class='o'>$</span><span class='k'>ncp</span>)</code></pre>

</div>

Now let's compare the original data to the complete data. The `imputePCA` function returns a list, which we convert to a tibble. There are also some new columns containing fitted values, which we'll set aside for an easier comparison.

We'll also remove the `completedObs.` prefix of the variable names. The regex pattern used here, `".*(?<=\\.)"`, matches everything up to and including the last dot in the column names. I use this pattern \* a lot\*. Note that you'll need `perl = TRUE` to use the lookahead.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>ozone</span> <span class='o'>%&gt;%</span> <span class='k'>head</span>
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 6 x 11</span></span>
<span class='c'>#&gt;   maxO3    T9   T12   T15   Ne9  Ne12  Ne15    Vx9   Vx12   Vx15 maxO3v</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span>    87  15.6  18.5  </span><span style='color: #BB0000;'>NA</span><span>       4     4     8  0.695 -</span><span style='color: #BB0000;'>1.71</span><span>  -</span><span style='color: #BB0000;'>0.695</span><span>     84</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span>    82  </span><span style='color: #BB0000;'>NA</span><span>    </span><span style='color: #BB0000;'>NA</span><span>    </span><span style='color: #BB0000;'>NA</span><span>       5     5     7 -</span><span style='color: #BB0000;'>4.33</span><span>  -</span><span style='color: #BB0000;'>4</span><span>     -</span><span style='color: #BB0000;'>3</span><span>         87</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span>    92  15.3  17.6  19.5     2    </span><span style='color: #BB0000;'>NA</span><span>    </span><span style='color: #BB0000;'>NA</span><span>  2.95  </span><span style='color: #BB0000;'>NA</span><span>      0.521     82</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span>   114  16.2  19.7  </span><span style='color: #BB0000;'>NA</span><span>       1     1     0 </span><span style='color: #BB0000;'>NA</span><span>      0.347 -</span><span style='color: #BB0000;'>0.174</span><span>     92</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span>    94  </span><span style='color: #BB0000;'>NA</span><span>    20.5  20.4    </span><span style='color: #BB0000;'>NA</span><span>    </span><span style='color: #BB0000;'>NA</span><span>    </span><span style='color: #BB0000;'>NA</span><span> -</span><span style='color: #BB0000;'>0.5</span><span>   -</span><span style='color: #BB0000;'>2.95</span><span>  -</span><span style='color: #BB0000;'>4.33</span><span>     114</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>6</span><span>    80  17.7  19.8  18.3     6    </span><span style='color: #BB0000;'>NA</span><span>     7 -</span><span style='color: #BB0000;'>5.64</span><span>  -</span><span style='color: #BB0000;'>5</span><span>     -</span><span style='color: #BB0000;'>6</span><span>         94</span></span>
<span class='k'>ozone_comp</span> <span class='o'>%&gt;%</span> 
    <span class='k'>as.data.frame</span> <span class='o'>%&gt;%</span> <span class='c'># seems to need this intermediate step?</span>
    <span class='k'>as_tibble</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='nf'>contains</span>(<span class='s'>"complete"</span>)) <span class='o'>%&gt;%</span> 
    <span class='nf'>rename_all</span>(<span class='k'>gsub</span>, pattern = <span class='s'>".*(?&lt;=\\.)"</span>, replacement = <span class='s'>''</span>, perl = <span class='kc'>TRUE</span>) <span class='o'>%&gt;%</span>  
    <span class='k'>head</span>
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 6 x 11</span></span>
<span class='c'>#&gt;   maxO3    T9   T12   T15   Ne9  Ne12  Ne15    Vx9   Vx12   Vx15 maxO3v</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span>  </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span>    87  15.6  18.5  20.5  4     4     8     0.695 -</span><span style='color: #BB0000;'>1.71</span><span>  -</span><span style='color: #BB0000;'>0.695</span><span>     84</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span>    82  18.5  20.9  21.8  5     5     7    -</span><span style='color: #BB0000;'>4.33</span><span>  -</span><span style='color: #BB0000;'>4</span><span>     -</span><span style='color: #BB0000;'>3</span><span>         87</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span>    92  15.3  17.6  19.5  2     3.98  3.81  2.95   1.95   0.521     82</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span>   114  16.2  19.7  24.7  1     1     0     2.04   0.347 -</span><span style='color: #BB0000;'>0.174</span><span>     92</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span>    94  19.0  20.5  20.4  5.29  5.27  5.06 -</span><span style='color: #BB0000;'>0.5</span><span>   -</span><span style='color: #BB0000;'>2.95</span><span>  -</span><span style='color: #BB0000;'>4.33</span><span>     114</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>6</span><span>    80  17.7  19.8  18.3  6     7.02  7    -</span><span style='color: #BB0000;'>5.64</span><span>  -</span><span style='color: #BB0000;'>5</span><span>     -</span><span style='color: #BB0000;'>6</span><span>         94</span></span></code></pre>

</div>

I missed a lot
--------------

Because I was catching up on PCA, I missed a fair chunk of the tutorial. In particular, I missed a whole discussion on evaluating how well the missing data was imputed. I also missed some stuff on random forests, and I love random forests!

But I learnt a tonne, and I'm grateful for the opportunity to dig into two topics I usually struggle with: PCA and missing value imputation. Thank you to Julie and Nick for the tutorial.

Now, onward to the official launch of the \#useR2018!

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
<span class='c'>#&gt;  package       * version    date       lib source                            </span>
<span class='c'>#&gt;  assertthat      0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports       1.1.7      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  blogdown        0.19       2020-05-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  broom           0.5.6      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr           3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cellranger      1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli             2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cluster         2.1.0      2019-06-19 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  codetools       0.2-16     2018-12-24 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  colorspace      1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon          1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DBI             1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dbplyr          1.4.3      2020-04-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc            1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools        2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest          0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  doParallel      1.0.15     2019-08-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit         0.0.0.9000 2020-06-12 [1] Github (r-lib/downlit@87fb1af)    </span>
<span class='c'>#&gt;  dplyr         * 0.8.5      2020-03-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis        0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate        0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  FactoMineR      2.3        2020-02-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi           0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  farver          2.0.3      2020-01-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  flashClust      1.01-2     2012-08-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forcats       * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  foreach         1.5.0      2020-03-30 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs              1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics        0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggplot2       * 3.3.0      2020-03-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggrepel         0.8.2      2020-03-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue            1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gtable          0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  haven           2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms             0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools       0.4.0      2019-10-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httr            1.4.1      2019-08-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown        0.0.0.9000 2020-06-12 [1] Github (r-lib/hugodown@6812ada)   </span>
<span class='c'>#&gt;  iterators       1.0.12     2019-07-26 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  jsonlite        1.6.1      2020-02-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr           1.28       2020-02-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  labeling        0.3        2014-08-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice         0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  leaps           3.1        2020-01-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle       0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lubridate       1.7.8      2020-04-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr        1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  MASS            7.3-51.6   2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise         1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  mice            3.9.0      2020-05-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  missMDA       * 1.17       2020-05-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  modelr          0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  munsell         0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  mvtnorm         1.1-0      2020-02-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  naniar        * 0.5.1      2020-04-30 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  nlme            3.1-145    2020-03-04 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pillar          1.4.4      2020-05-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild        1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig       2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload         1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits     1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx        3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps              1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr         * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6              2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp            1.0.4.6    2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr         * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readxl          1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes         2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reprex          0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang           0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown       2.2.3      2020-06-12 [1] Github (rstudio/rmarkdown@4ee96c8)</span>
<span class='c'>#&gt;  rprojroot       1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rstudioapi      0.11       2020-02-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rvest           0.3.5      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  scales          1.1.0      2019-11-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  scatterplot3d   0.3-41     2018-03-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo     1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi         1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr       * 1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat        2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble        * 3.0.1      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyr         * 1.0.2      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect      1.0.0      2020-01-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyverse     * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis         1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  utf8            1.1.4      2018-05-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs           0.3.1      2020-06-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  visdat        * 0.5.3      2019-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr           2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun            0.14       2020-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xml2            1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml            2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

