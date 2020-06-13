---
title: 'useR: Recipes for data processing'
author: ''
date: '2018-07-10'
# weight: 1
slug: user-recipes-for-data-processing
categories: []
tags: [R, conference]
images: ["/img/useR/tutorial_two.png"]
featuredalt: "useR2018 Tutorial Two"
output: hugodown::md_document
rmd_hash: f99c5d0cafbb1adb

---

These are my notes for the tutorial given by [Max Kuhn](https://twitter.com/topepos) on the afternoon of the first day of the UseR 2018 conference.

Full confession here: I was having trouble deciding between this tutorial and another one, and eventually decided on the other one. But then I accidentally came to the wrong room and I took it as a sign that it was time to learn more about preprocessing.

Also, the `recipes` package is *adorable*.

<div class="highlight">

<!--html_preserve-->
{{% tweet "1016541132057075712" %}}<!--/html_preserve-->

</div>

I'm going to follow along with [Max's slides](https://github.com/topepo/user2018), making some comments along the way.

Required packages:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/utils/install.packages.html'>install.packages</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"AmesHousing"</span>, <span class='s'>"broom"</span>, <span class='s'>"kknn"</span>, <span class='s'>"recipes"</span>, <span class='s'>"rsample"</span>,
                   <span class='s'>"tidyverse"</span>, <span class='s'>"yardstick"</span>, <span class='s'>"caret"</span>))</code></pre>

</div>

The data set we'll use is the AMES IA housing data. This includes sale price (our target) along with 81 predictors, such as location, house components (eg. swimming pool), number of bedrooms, and so on. The raw data can be found at <https://ww2.amstat.org/publications/jse/v19n3/decock/AmesHousing.txt> but we will be using the processed version found in the `AmesHousing` package.

Reasons for modifying the data
------------------------------

Sometimes you need to *do stuff* to your data before you can use it. Moreover, you're often dealing with data that's split into train/test sets. In this case you need to work out what to do with your data based solely on the training set and then apply that---without changing your method---to the test set. If you're dealing with $K$-fold cross-validation, then you've got $K$ training sets and $K$ test sets, and so you need to repeat this $K$ times.

A good example is missing value imputation, where you have some missing data in your train/test sets and you need to fill them in via some imputation method. I'm no expert on the topic (but I hope to be after the missing value imputation tutorial tomorrow!) but I've seen this done wrong before in StackExchange answers and in Kaggle solutions: the imputation is done *before* the data is split into train/test. This is called *data leakage*, and models assessed using the test set will appear more accurate than they are, because they've already had a sneak preview of the data.

So the mindset is clear: don't touch the test set until the last possible moment. The `recipes` package follows this mindset. First you create a `recipe`, which is a blueprint for how you will process your data. At this point, no data has been modified. Then you `prep` the recipe using your training set, which is where the actual processing is defined and all the parameters worked out. Finally, you can `bake` the training set, test set, or any other data set with similar columns, and in this step the actual modification takes place.

Missing value **imputation** isn't the only reason to process data, though. Processing can involve:

-   **Centering** and **scaling** the predictors. Some models (K-NN, SBMs, PLS, neural networks) require that the predictor variables have the same units.
-   Applying **filters** or **PCA signal extraction** to deal with correlation between predictors.
-   **Encoding data**, such as turning factors into Boolean dummy variables, or turning dates into days of the week.
-   Developing new features (ie. **feature engineering**).

The `ames` data
---------------

We load the data with the `make_ames` function from the `AmesHousing` package.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>ames</span> <span class='o'>&lt;-</span> <span class='k'>AmesHousing</span>::<span class='nf'><a href='https://rdrr.io/pkg/AmesHousing/man/make_ames.html'>make_ames</a></span>()
<span class='k'>ames</span> <span class='o'>%&gt;%</span> <span class='k'>str</span>
<span class='c'>#&gt; tibble [2,930 × 81] (S3: tbl_df/tbl/data.frame)</span>
<span class='c'>#&gt;  $ MS_SubClass       : Factor w/ 16 levels "One_Story_1946_and_Newer_All_Styles",..: 1 1 1 1 6 6 12 12 12 6 ...</span>
<span class='c'>#&gt;  $ MS_Zoning         : Factor w/ 7 levels "Floating_Village_Residential",..: 3 2 3 3 3 3 3 3 3 3 ...</span>
<span class='c'>#&gt;  $ Lot_Frontage      : num [1:2930] 141 80 81 93 74 78 41 43 39 60 ...</span>
<span class='c'>#&gt;  $ Lot_Area          : int [1:2930] 31770 11622 14267 11160 13830 9978 4920 5005 5389 7500 ...</span>
<span class='c'>#&gt;  $ Street            : Factor w/ 2 levels "Grvl","Pave": 2 2 2 2 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Alley             : Factor w/ 3 levels "Gravel","No_Alley_Access",..: 2 2 2 2 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Lot_Shape         : Factor w/ 4 levels "Regular","Slightly_Irregular",..: 2 1 2 1 2 2 1 2 2 1 ...</span>
<span class='c'>#&gt;  $ Land_Contour      : Factor w/ 4 levels "Bnk","HLS","Low",..: 4 4 4 4 4 4 4 2 4 4 ...</span>
<span class='c'>#&gt;  $ Utilities         : Factor w/ 3 levels "AllPub","NoSeWa",..: 1 1 1 1 1 1 1 1 1 1 ...</span>
<span class='c'>#&gt;  $ Lot_Config        : Factor w/ 5 levels "Corner","CulDSac",..: 1 5 1 1 5 5 5 5 5 5 ...</span>
<span class='c'>#&gt;  $ Land_Slope        : Factor w/ 3 levels "Gtl","Mod","Sev": 1 1 1 1 1 1 1 1 1 1 ...</span>
<span class='c'>#&gt;  $ Neighborhood      : Factor w/ 28 levels "North_Ames","College_Creek",..: 1 1 1 1 7 7 17 17 17 7 ...</span>
<span class='c'>#&gt;  $ Condition_1       : Factor w/ 9 levels "Artery","Feedr",..: 3 2 3 3 3 3 3 3 3 3 ...</span>
<span class='c'>#&gt;  $ Condition_2       : Factor w/ 8 levels "Artery","Feedr",..: 3 3 3 3 3 3 3 3 3 3 ...</span>
<span class='c'>#&gt;  $ Bldg_Type         : Factor w/ 5 levels "OneFam","TwoFmCon",..: 1 1 1 1 1 1 5 5 5 1 ...</span>
<span class='c'>#&gt;  $ House_Style       : Factor w/ 8 levels "One_and_Half_Fin",..: 3 3 3 3 8 8 3 3 3 8 ...</span>
<span class='c'>#&gt;  $ Overall_Qual      : Factor w/ 10 levels "Very_Poor","Poor",..: 6 5 6 7 5 6 8 8 8 7 ...</span>
<span class='c'>#&gt;  $ Overall_Cond      : Factor w/ 10 levels "Very_Poor","Poor",..: 5 6 6 5 5 6 5 5 5 5 ...</span>
<span class='c'>#&gt;  $ Year_Built        : int [1:2930] 1960 1961 1958 1968 1997 1998 2001 1992 1995 1999 ...</span>
<span class='c'>#&gt;  $ Year_Remod_Add    : int [1:2930] 1960 1961 1958 1968 1998 1998 2001 1992 1996 1999 ...</span>
<span class='c'>#&gt;  $ Roof_Style        : Factor w/ 6 levels "Flat","Gable",..: 4 2 4 4 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Roof_Matl         : Factor w/ 8 levels "ClyTile","CompShg",..: 2 2 2 2 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Exterior_1st      : Factor w/ 16 levels "AsbShng","AsphShn",..: 4 14 15 4 14 14 6 7 6 14 ...</span>
<span class='c'>#&gt;  $ Exterior_2nd      : Factor w/ 17 levels "AsbShng","AsphShn",..: 11 15 16 4 15 15 6 7 6 15 ...</span>
<span class='c'>#&gt;  $ Mas_Vnr_Type      : Factor w/ 5 levels "BrkCmn","BrkFace",..: 5 4 2 4 4 2 4 4 4 4 ...</span>
<span class='c'>#&gt;  $ Mas_Vnr_Area      : num [1:2930] 112 0 108 0 0 20 0 0 0 0 ...</span>
<span class='c'>#&gt;  $ Exter_Qual        : Factor w/ 4 levels "Excellent","Fair",..: 4 4 4 3 4 4 3 3 3 4 ...</span>
<span class='c'>#&gt;  $ Exter_Cond        : Factor w/ 5 levels "Excellent","Fair",..: 5 5 5 5 5 5 5 5 5 5 ...</span>
<span class='c'>#&gt;  $ Foundation        : Factor w/ 6 levels "BrkTil","CBlock",..: 2 2 2 2 3 3 3 3 3 3 ...</span>
<span class='c'>#&gt;  $ Bsmt_Qual         : Factor w/ 6 levels "Excellent","Fair",..: 6 6 6 6 3 6 3 3 3 6 ...</span>
<span class='c'>#&gt;  $ Bsmt_Cond         : Factor w/ 6 levels "Excellent","Fair",..: 3 6 6 6 6 6 6 6 6 6 ...</span>
<span class='c'>#&gt;  $ Bsmt_Exposure     : Factor w/ 5 levels "Av","Gd","Mn",..: 2 4 4 4 4 4 3 4 4 4 ...</span>
<span class='c'>#&gt;  $ BsmtFin_Type_1    : Factor w/ 7 levels "ALQ","BLQ","GLQ",..: 2 6 1 1 3 3 3 1 3 7 ...</span>
<span class='c'>#&gt;  $ BsmtFin_SF_1      : num [1:2930] 2 6 1 1 3 3 3 1 3 7 ...</span>
<span class='c'>#&gt;  $ BsmtFin_Type_2    : Factor w/ 7 levels "ALQ","BLQ","GLQ",..: 7 4 7 7 7 7 7 7 7 7 ...</span>
<span class='c'>#&gt;  $ BsmtFin_SF_2      : num [1:2930] 0 144 0 0 0 0 0 0 0 0 ...</span>
<span class='c'>#&gt;  $ Bsmt_Unf_SF       : num [1:2930] 441 270 406 1045 137 ...</span>
<span class='c'>#&gt;  $ Total_Bsmt_SF     : num [1:2930] 1080 882 1329 2110 928 ...</span>
<span class='c'>#&gt;  $ Heating           : Factor w/ 6 levels "Floor","GasA",..: 2 2 2 2 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Heating_QC        : Factor w/ 5 levels "Excellent","Fair",..: 2 5 5 1 3 1 1 1 1 3 ...</span>
<span class='c'>#&gt;  $ Central_Air       : Factor w/ 2 levels "N","Y": 2 2 2 2 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Electrical        : Factor w/ 6 levels "FuseA","FuseF",..: 5 5 5 5 5 5 5 5 5 5 ...</span>
<span class='c'>#&gt;  $ First_Flr_SF      : int [1:2930] 1656 896 1329 2110 928 926 1338 1280 1616 1028 ...</span>
<span class='c'>#&gt;  $ Second_Flr_SF     : int [1:2930] 0 0 0 0 701 678 0 0 0 776 ...</span>
<span class='c'>#&gt;  $ Low_Qual_Fin_SF   : int [1:2930] 0 0 0 0 0 0 0 0 0 0 ...</span>
<span class='c'>#&gt;  $ Gr_Liv_Area       : int [1:2930] 1656 896 1329 2110 1629 1604 1338 1280 1616 1804 ...</span>
<span class='c'>#&gt;  $ Bsmt_Full_Bath    : num [1:2930] 1 0 0 1 0 0 1 0 1 0 ...</span>
<span class='c'>#&gt;  $ Bsmt_Half_Bath    : num [1:2930] 0 0 0 0 0 0 0 0 0 0 ...</span>
<span class='c'>#&gt;  $ Full_Bath         : int [1:2930] 1 1 1 2 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Half_Bath         : int [1:2930] 0 0 1 1 1 1 0 0 0 1 ...</span>
<span class='c'>#&gt;  $ Bedroom_AbvGr     : int [1:2930] 3 2 3 3 3 3 2 2 2 3 ...</span>
<span class='c'>#&gt;  $ Kitchen_AbvGr     : int [1:2930] 1 1 1 1 1 1 1 1 1 1 ...</span>
<span class='c'>#&gt;  $ Kitchen_Qual      : Factor w/ 5 levels "Excellent","Fair",..: 5 5 3 1 5 3 3 3 3 3 ...</span>
<span class='c'>#&gt;  $ TotRms_AbvGrd     : int [1:2930] 7 5 6 8 6 7 6 5 5 7 ...</span>
<span class='c'>#&gt;  $ Functional        : Factor w/ 8 levels "Maj1","Maj2",..: 8 8 8 8 8 8 8 8 8 8 ...</span>
<span class='c'>#&gt;  $ Fireplaces        : int [1:2930] 2 0 0 2 1 1 0 0 1 1 ...</span>
<span class='c'>#&gt;  $ Fireplace_Qu      : Factor w/ 6 levels "Excellent","Fair",..: 3 4 4 6 6 3 4 4 6 6 ...</span>
<span class='c'>#&gt;  $ Garage_Type       : Factor w/ 7 levels "Attchd","Basment",..: 1 1 1 1 1 1 1 1 1 1 ...</span>
<span class='c'>#&gt;  $ Garage_Finish     : Factor w/ 4 levels "Fin","No_Garage",..: 1 4 4 1 1 1 1 3 3 1 ...</span>
<span class='c'>#&gt;  $ Garage_Cars       : num [1:2930] 2 1 1 2 2 2 2 2 2 2 ...</span>
<span class='c'>#&gt;  $ Garage_Area       : num [1:2930] 528 730 312 522 482 470 582 506 608 442 ...</span>
<span class='c'>#&gt;  $ Garage_Qual       : Factor w/ 6 levels "Excellent","Fair",..: 6 6 6 6 6 6 6 6 6 6 ...</span>
<span class='c'>#&gt;  $ Garage_Cond       : Factor w/ 6 levels "Excellent","Fair",..: 6 6 6 6 6 6 6 6 6 6 ...</span>
<span class='c'>#&gt;  $ Paved_Drive       : Factor w/ 3 levels "Dirt_Gravel",..: 2 3 3 3 3 3 3 3 3 3 ...</span>
<span class='c'>#&gt;  $ Wood_Deck_SF      : int [1:2930] 210 140 393 0 212 360 0 0 237 140 ...</span>
<span class='c'>#&gt;  $ Open_Porch_SF     : int [1:2930] 62 0 36 0 34 36 0 82 152 60 ...</span>
<span class='c'>#&gt;  $ Enclosed_Porch    : int [1:2930] 0 0 0 0 0 0 170 0 0 0 ...</span>
<span class='c'>#&gt;  $ Three_season_porch: int [1:2930] 0 0 0 0 0 0 0 0 0 0 ...</span>
<span class='c'>#&gt;  $ Screen_Porch      : int [1:2930] 0 120 0 0 0 0 0 144 0 0 ...</span>
<span class='c'>#&gt;  $ Pool_Area         : int [1:2930] 0 0 0 0 0 0 0 0 0 0 ...</span>
<span class='c'>#&gt;  $ Pool_QC           : Factor w/ 5 levels "Excellent","Fair",..: 4 4 4 4 4 4 4 4 4 4 ...</span>
<span class='c'>#&gt;  $ Fence             : Factor w/ 5 levels "Good_Privacy",..: 5 3 5 5 3 5 5 5 5 5 ...</span>
<span class='c'>#&gt;  $ Misc_Feature      : Factor w/ 6 levels "Elev","Gar2",..: 3 3 2 3 3 3 3 3 3 3 ...</span>
<span class='c'>#&gt;  $ Misc_Val          : int [1:2930] 0 0 12500 0 0 0 0 0 0 0 ...</span>
<span class='c'>#&gt;  $ Mo_Sold           : int [1:2930] 5 6 6 4 3 6 4 1 3 6 ...</span>
<span class='c'>#&gt;  $ Year_Sold         : int [1:2930] 2010 2010 2010 2010 2010 2010 2010 2010 2010 2010 ...</span>
<span class='c'>#&gt;  $ Sale_Type         : Factor w/ 10 levels "COD","Con","ConLD",..: 10 10 10 10 10 10 10 10 10 10 ...</span>
<span class='c'>#&gt;  $ Sale_Condition    : Factor w/ 6 levels "Abnorml","AdjLand",..: 5 5 5 5 5 5 5 5 5 5 ...</span>
<span class='c'>#&gt;  $ Sale_Price        : int [1:2930] 215000 105000 172000 244000 189900 195500 213500 191500 236500 189000 ...</span>
<span class='c'>#&gt;  $ Longitude         : num [1:2930] -93.6 -93.6 -93.6 -93.6 -93.6 ...</span>
<span class='c'>#&gt;  $ Latitude          : num [1:2930] 42.1 42.1 42.1 42.1 42.1 ...</span></code></pre>

</div>

Now we will split the data into test and train. We'll reserve 25% of of the data for testing.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='https://tidymodels.github.io/rsample'>rsample</a></span>)
<span class='nf'><a href='https://rdrr.io/r/base/Random.html'>set.seed</a></span>(<span class='m'>4595</span>)
<span class='k'>data_split</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/pkg/rsample/man/initial_split.html'>initial_split</a></span>(<span class='k'>ames</span>, strata = <span class='s'>"Sale_Price"</span>, p = <span class='m'>0.75</span>)
<span class='k'>ames_train</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/pkg/rsample/man/initial_split.html'>training</a></span>(<span class='k'>data_split</span>)
<span class='k'>ames_test</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/pkg/rsample/man/initial_split.html'>testing</a></span>(<span class='k'>data_split</span>)</code></pre>

</div>

A simple log-transform
----------------------

The first of Max's examples is a really simple log transform of `Sale_Price`. Suppose we use the formula `log10(Sale_Price) ~ Longitude + Latitude`. The steps are:

1.  Assign `Sale_Price` to the outcome.
2.  Assign `Longitude` and `Latittude` as predictors.
3.  Log transform the outcome.

The way to define this in `recipes` is as follows:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>mod_rec</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/recipe.html'>recipe</a></span>(<span class='k'>Sale_Price</span> <span class='o'>~</span> <span class='k'>Longitude</span> <span class='o'>+</span> <span class='k'>Latitude</span>, data = <span class='k'>ames_train</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/step_log.html'>step_log</a></span>(<span class='k'>Sale_Price</span>, base = <span class='m'>10</span>)</code></pre>

</div>

Infrequently occurring levels
-----------------------------

We usually encode factors as Boolean dummy variables, with R often taking care of this in the background. If there are `C` levels of the factor, only `C - 1` dummy variables are required. But what if you have very few values for a particular level? For example, the `Neighborhood` predictor in our `ames` data:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>ames</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggplot.html'>ggplot</a></span>(<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='k'>Neighborhood</span>)) <span class='o'>+</span>
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_bar.html'>geom_bar</a></span>(fill = <span class='s'>"#6d1e3b"</span>, colour = <span class='s'>"white"</span>) <span class='o'>+</span> <span class='c'># I don't like the default grey</span>
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/coord_flip.html'>coord_flip</a></span>()
</code></pre>
<img src="figs/ames_locations-1.png" width="700px" style="display: block; margin: auto;" />

</div>

In fact, there's only one data point with a `Neighborhood` of Landmark. This is called a "zero-variance predictor". There are two main approaches here:

1.  remove any data points with infrequently occurring values, or
2.  group all of the infrequently occurring values into an "Other" level.

This is a job for the `recipes` package, and Max takes us through the example.

We can take care of the infrequently occurring levels here using the `step_other` function. In this case, we "other" any level that occurs fewer than 5% of the time. We can then create dummy variables for all factor variables with `step_dummy`:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>mod_rec</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/recipe.html'>recipe</a></span>(<span class='k'>Sale_Price</span> <span class='o'>~</span> <span class='k'>Longitude</span> <span class='o'>+</span> <span class='k'>Latitude</span> <span class='o'>+</span> <span class='k'>Neighborhood</span>, 
                  data = <span class='k'>ames_train</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/step_log.html'>step_log</a></span>(<span class='k'>Sale_Price</span>, base = <span class='m'>10</span>) <span class='o'>%&gt;%</span> <span class='c'># The log-transform from earlier</span>
    <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/step_other.html'>step_other</a></span>(<span class='k'>Neighborhood</span>, threshold = <span class='m'>0.05</span>) <span class='o'>%&gt;%</span>
    <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/step_dummy.html'>step_dummy</a></span>(<span class='nf'><a href='https://rdrr.io/pkg/recipes/man/has_role.html'>all_nominal</a></span>())</code></pre>

</div>

The `recipes` process
---------------------

Recipes work in a three-step process: `recipe` --&gt; `prepare` --&gt; `bake`/`juice`. We can think of this as: define --&gt; estimate --&gt; apply. `juice` only applies to the original data set defined in the recipe, the idea at the core of `bake` is that it can be applied to an *arbitrary* data set.

First we `prep` the data using the recipe in Max's example:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>mod_rec_trained</span> <span class='o'>&lt;-</span> <span class='k'>mod_rec</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/prep.html'>prep</a></span>(training = <span class='k'>ames_train</span>, retain = <span class='kc'>TRUE</span>)
<span class='k'>mod_rec_trained</span>
<span class='c'>#&gt; Data Recipe</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Inputs:</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt;       role #variables</span>
<span class='c'>#&gt;    outcome          1</span>
<span class='c'>#&gt;  predictor          3</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Training data contained 2199 data points and no missing data.</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Operations:</span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; Log transformation on Sale_Price [trained]</span>
<span class='c'>#&gt; Collapsing factor levels for Neighborhood [trained]</span>
<span class='c'>#&gt; Dummy variables from Neighborhood [trained]</span></code></pre>

</div>

We can now `bake` the recipe, applying it to the test set we defined earlier:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>ames_test_dummies</span> <span class='o'>&lt;-</span> <span class='k'>mod_rec_trained</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/pkg/recipes/man/bake.html'>bake</a></span>(new_data = <span class='k'>ames_test</span>)
<span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>ames_test_dummies</span>)
<span class='c'>#&gt;  [1] "Longitude"                       "Latitude"                       </span>
<span class='c'>#&gt;  [3] "Sale_Price"                      "Neighborhood_College_Creek"     </span>
<span class='c'>#&gt;  [5] "Neighborhood_Old_Town"           "Neighborhood_Edwards"           </span>
<span class='c'>#&gt;  [7] "Neighborhood_Somerset"           "Neighborhood_Northridge_Heights"</span>
<span class='c'>#&gt;  [9] "Neighborhood_Gilbert"            "Neighborhood_Sawyer"            </span>
<span class='c'>#&gt; [11] "Neighborhood_other"</span></code></pre>

</div>

Other uses
----------

I have to admit that the rest got away from me a little bit, because I'm not overly familiar with all of the transformations/methods that were used (what is a Yeo-Johnson Power Transformation?!).

However, there's a tonne of cool stuff in the slides that I'll be coming back to later, I'm sure. Max used `recipes` and `rsample` to:

-   deal with interactions between predictors,
-   apply processing to all of the folds of a 10-fold cross-validation,
-   train 10 linear models on that same 10-fold cross-validation,
-   assess and plot the performance of those linear models, and
-   train and asses 10 nearest-neighbour models on the 10-fold cross-validation.

I know I'll be using this `recipes` package *a lot*.

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
<span class='c'>#&gt;  package      * version    date       lib source                            </span>
<span class='c'>#&gt;  AmesHousing    0.0.3      2017-12-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  assertthat     0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  backports      1.1.7      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  blogdown       0.19       2020-05-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  broom          0.5.6      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr          3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  caret        * 6.0-86     2020-03-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cellranger     1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  class          7.3-17     2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli            2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  codetools      0.2-16     2018-12-24 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  colorspace     1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon         1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  data.table     1.12.8     2019-12-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DBI            1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dbplyr         1.4.3      2020-04-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc           1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools       2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dials          0.0.6      2020-04-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DiceDesign     1.8-1      2019-07-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest         0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit        0.0.0.9000 2020-06-12 [1] Github (r-lib/downlit@87fb1af)    </span>
<span class='c'>#&gt;  dplyr        * 0.8.5      2020-03-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis       0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate       0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi          0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  farver         2.0.3      2020-01-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forcats      * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  foreach        1.5.0      2020-03-30 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs             1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  furrr          0.1.0      2018-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  future         1.17.0     2020-04-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics       0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggplot2      * 3.3.0      2020-03-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  globals        0.12.5     2019-12-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue           1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gower          0.2.1      2019-05-14 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  GPfit          1.0-8      2019-02-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gtable         0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  haven          2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms            0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools      0.4.0      2019-10-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httr           1.4.1      2019-08-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown       0.0.0.9000 2020-06-12 [1] Github (r-lib/hugodown@6812ada)   </span>
<span class='c'>#&gt;  ipred          0.9-9      2019-04-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  iterators      1.0.12     2019-07-26 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  jsonlite       1.6.1      2020-02-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr          1.28       2020-02-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  labeling       0.3        2014-08-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice      * 0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lava           1.6.7      2020-03-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lhs            1.0.2      2020-04-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle      0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  listenv        0.8.0      2019-12-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lubridate      1.7.8      2020-04-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr       1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  MASS           7.3-51.6   2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Matrix         1.2-18     2019-11-27 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise        1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  ModelMetrics   1.2.2.2    2020-03-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  modelr         0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  munsell        0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  nlme           3.1-145    2020-03-04 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  nnet           7.3-14     2020-04-26 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  parsnip        0.1.0      2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pillar         1.4.4      2020-05-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild       1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig      2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload        1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  plyr           1.8.6      2020-03-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits    1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pROC           1.16.2     2020-03-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx       3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prodlim        2019.11.13 2019-11-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps             1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr        * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6             2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp           1.0.4.6    2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr        * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readxl         1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  recipes      * 0.1.10     2020-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes        2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reprex         0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reshape2       1.4.4      2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang          0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown      2.2.3      2020-06-12 [1] Github (rstudio/rmarkdown@4ee96c8)</span>
<span class='c'>#&gt;  rpart          4.1-15     2019-04-12 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rprojroot      1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rsample      * 0.0.6      2020-03-31 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rstudioapi     0.11       2020-02-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rvest          0.3.5      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  scales         1.1.0      2019-11-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo    1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi        1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr      * 1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  survival       3.1-12     2020-04-10 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat       2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble       * 3.0.1      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyr        * 1.0.2      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect     1.0.0      2020-01-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyverse    * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  timeDate       3043.102   2018-02-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis        1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs          0.3.1      2020-06-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr          2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  workflows      0.1.1      2020-03-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun           0.14       2020-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xml2           1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml           2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

