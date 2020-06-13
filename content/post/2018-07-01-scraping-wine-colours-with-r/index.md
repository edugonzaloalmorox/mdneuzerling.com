---
title: Scraping wine colours with R
author: ''
date: '2018-07-01'
slug: scraping-wine-colours-with-r
tags:
    - R
    - scraping
images: ["/img/grapes.jpeg"]
featuredalt: "grapes"
output: hugodown::md_document
rmd_hash: 7af88538483c1530

---

My knowledge of wine covers three facts:

1.  I like red wine.
2.  I do not like white wine.
3.  I love wine *data*.

I came across a great collection of around 130,000 wine reviews, each a paragraph long, on [Kaggle](https://www.kaggle.com/zynicide/wine-reviews). This is juicy stuff, and I can't wait to dig into it with some text analysis, or maybe build some sort of markov chain or neural network that generates new wine reviews.

But I wanted to start with something simple---a little bit of feature engineering. There's around 700 different *varieties* (eg. merlot, riesling) in here, and I thought it would be easy to add on whether or not they were red, white or rosé.

It was not.

I won't show you all the failed attempts; I'll just focus on what worked in the end. This is the process:

1.  Scrape wine colour data from Wikipedia
2.  Join the colours with the wine varieties
3.  Fix errors and duplicates
4.  Improve the wine colour data, and repeat
5.  When all else fails, manually classify what remains.

Classifying wine into three simple categories is a tough ask, and I can hear the connoisseurs tutting at me. Some grapes can be red and white, and I'm told that there's such a thing as "orange" wine (and no, it's not made from oranges---I did ask). Dessert wines and sparkling wines can probably be classified as red or white, but really they're off doing their own thing. I acknowledge how aggressive this classification is, but I'm going to charge ahead anyway.

Quick look at the data
----------------------

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>knitr</span>::<span class='k'><a href='https://rdrr.io/pkg/knitr/man/opts_chunk.html'>opts_chunk</a></span><span class='o'>$</span><span class='nf'>set</span>(echo = <span class='kc'>TRUE</span>, cache = <span class='kc'>TRUE</span>)

<span class='nf'><a href='https://rdrr.io/r/base/Random.html'>set.seed</a></span>(<span class='m'>42275</span>) <span class='c'># Chosen by fair dice roll. Guaranteed to be random.</span>
 
<span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='http://tidyverse.tidyverse.org'>tidyverse</a></span>)
<span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='http://ggplot2.tidyverse.org'>ggplot2</a></span>) 
<span class='nf'><a href='https://rdrr.io/r/base/library.html'>library</a></span>(<span class='k'><a href='http://rvest.tidyverse.org'>rvest</a></span>)

<span class='k'>red_wine_colour</span> <span class='o'>&lt;-</span> <span class='s'>"#59121C"</span>
<span class='k'>white_wine_colour</span> <span class='o'>&lt;-</span> <span class='s'>"#EADB9F"</span>
<span class='k'>rose_wine_colour</span> <span class='o'>&lt;-</span> <span class='s'>"#F5C0A2"</span>

<span class='k'>wine</span> <span class='o'>&lt;-</span> <span class='s'>"wine_reviews.csv"</span> <span class='o'>%&gt;%</span> 
    <span class='k'>read_csv</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>mutate</span>(variety = <span class='k'>variety</span> <span class='o'>%&gt;%</span> <span class='k'>tolower</span>)

<span class='k'>wine</span> <span class='o'>%&gt;%</span> <span class='k'>str</span>
<span class='c'>#&gt; tibble [129,971 × 14] (S3: spec_tbl_df/tbl_df/tbl/data.frame)</span>
<span class='c'>#&gt;  $ X1                   : num [1:129971] 0 1 2 3 4 5 6 7 8 9 ...</span>
<span class='c'>#&gt;  $ country              : chr [1:129971] "Italy" "Portugal" "US" "US" ...</span>
<span class='c'>#&gt;  $ description          : chr [1:129971] "Aromas include tropical fruit, broom, brimstone and dried herb. The palate isn't overly expressive, offering un"| __truncated__ "This is ripe and fruity, a wine that is smooth while still structured. Firm tannins are filled out with juicy r"| __truncated__ "Tart and snappy, the flavors of lime flesh and rind dominate. Some green pineapple pokes through, with crisp ac"| __truncated__ "Pineapple rind, lemon pith and orange blossom start off the aromas. The palate is a bit more opulent, with note"| __truncated__ ...</span>
<span class='c'>#&gt;  $ designation          : chr [1:129971] "Vulkà Bianco" "Avidagos" NA "Reserve Late Harvest" ...</span>
<span class='c'>#&gt;  $ points               : num [1:129971] 87 87 87 87 87 87 87 87 87 87 ...</span>
<span class='c'>#&gt;  $ price                : num [1:129971] NA 15 14 13 65 15 16 24 12 27 ...</span>
<span class='c'>#&gt;  $ province             : chr [1:129971] "Sicily &amp; Sardinia" "Douro" "Oregon" "Michigan" ...</span>
<span class='c'>#&gt;  $ region_1             : chr [1:129971] "Etna" NA "Willamette Valley" "Lake Michigan Shore" ...</span>
<span class='c'>#&gt;  $ region_2             : chr [1:129971] NA NA "Willamette Valley" NA ...</span>
<span class='c'>#&gt;  $ taster_name          : chr [1:129971] "Kerin O’Keefe" "Roger Voss" "Paul Gregutt" "Alexander Peartree" ...</span>
<span class='c'>#&gt;  $ taster_twitter_handle: chr [1:129971] "@kerinokeefe" "@vossroger" "@paulgwine " NA ...</span>
<span class='c'>#&gt;  $ title                : chr [1:129971] "Nicosia 2013 Vulkà Bianco  (Etna)" "Quinta dos Avidagos 2011 Avidagos Red (Douro)" "Rainstorm 2013 Pinot Gris (Willamette Valley)" "St. Julian 2013 Reserve Late Harvest Riesling (Lake Michigan Shore)" ...</span>
<span class='c'>#&gt;  $ variety              : chr [1:129971] "white blend" "portuguese red" "pinot gris" "riesling" ...</span>
<span class='c'>#&gt;  $ winery               : chr [1:129971] "Nicosia" "Quinta dos Avidagos" "Rainstorm" "St. Julian" ...</span></code></pre>

</div>

I think this data will keep me entertained for a while. There's a lot to dig into here, and those reviews are going to be interesting when I can pull them apart. For example, 7 wines are described as tasting of tennis balls, and these wines are rated about average. It makes me think that I'm not spending enough time in life appreciating the taste of tennis balls. Dogs understand this.

Speaking of points, it appears as though wines are ranked on a scale from 80 to 100. Although, looking at the plot below, you'd be forgiven for thinking that the scale is from 80 to 97. Only 0.01% of wines make it to a rating of 100.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>wine</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggplot.html'>ggplot</a></span>(<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='k'>points</span>)) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_histogram.html'>geom_histogram</a></span>(
        bins = <span class='nf'><a href='https://rdrr.io/r/base/nrow.html'>nrow</a></span>(<span class='k'>wine</span> <span class='o'>%&gt;%</span> <span class='nf'>distinct</span>(<span class='k'>points</span>)),
        colour = <span class='s'>"white"</span>,
        fill = <span class='k'>red_wine_colour</span>
    )
</code></pre>
<img src="figs/points-1.png" width="700px" style="display: block; margin: auto;" />

</div>

The review below is for an 80-point wine, and it's certainly one of my favourite descriptions:

<div class='highlight'>
<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>wine</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='k'>X1</span> <span class='o'>==</span> <span class='m'>11086</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>description</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>(<span class='s'>'&gt; '</span>, <span class='k'>.</span>) <span class='o'>%&gt;%</span> <span class='c'># print as quote</span>
    <span class='k'>cat</span>
</code></pre>

> Picture grandma standing over a pot of stewed prunes, which fill the dusty old house with their sickly aromas. Cooked, earthy and rustic, this wine has little going for it. Just barely acceptable.
> </div>

One wine, indexed 86909, has a missing variety. Fortunately, we can recover the information from the review:

<div class='highlight'>
<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>wine</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='k'>X1</span> <span class='o'>==</span> <span class='m'>86909</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>description</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>(<span class='s'>'&gt; '</span>, <span class='k'>.</span>) <span class='o'>%&gt;%</span> <span class='c'># print as quote</span>
    <span class='k'>cat</span>
</code></pre>

> A chalky, dusty mouthfeel nicely balances this Petite Syrah's bright, full blackberry and blueberry fruit. Wheat-flour and black-pepper notes add interest to the bouquet; the wine finishes with herb and an acorny nuttiness. A good first Chilean wine for those more comfortable with the Californian style. It's got tannins to lose, but it's very good.
> </div>

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>wine</span> <span class='o'>&lt;-</span> <span class='k'>wine</span> <span class='o'>%&gt;%</span> <span class='nf'>mutate</span>(
  variety = <span class='nf'><a href='https://rdrr.io/r/base/ifelse.html'>ifelse</a></span>(<span class='k'>X1</span> <span class='o'>==</span> <span class='m'>86909</span>, <span class='s'>"petite syrah"</span>, <span class='k'>variety</span>)
)</code></pre>

</div>

Scraping Wikipedia
------------------

In order to classify the wines as red, white or rosé, we're going to scrape wine data from the [List of grape varieties](https://en.wikipedia.org/wiki/List_of_grape_varieties) Wikipedia page, using the `rvest` package. The first three tables of this page give red, white and rosé wines, in that order.

We're going to use an older version of the article, dated 2018-06-29, for consistency. Wikipedia displays a notice that the user is reading an older version of the article. This counts as a table, and so the code below refers to tables 2, 3 and 4. If using the live version, replace these figures with 1, 2 and 3.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='c'># Use an old revision of the article for consistency</span>
<span class='k'>wiki_tables</span> <span class='o'>&lt;-</span> <span class='s'>"https://en.wikipedia.org/w/index.php?title=List_of_grape_varieties&amp;oldid=847983339"</span> <span class='o'>%&gt;%</span> 
    <span class='k'>read_html</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rvest.tidyverse.org/reference/html_nodes.html'>html_nodes</a></span>(<span class='s'>"table"</span>)
<span class='k'>red_wines</span> <span class='o'>&lt;-</span> <span class='k'>wiki_tables</span>[[<span class='m'>1</span>]] <span class='o'>%&gt;%</span> <span class='k'>html_table</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>cbind</a></span>(colour = <span class='s'>"red"</span>)
<span class='k'>white_wines</span> <span class='o'>&lt;-</span> <span class='k'>wiki_tables</span>[[<span class='m'>2</span>]] <span class='o'>%&gt;%</span> <span class='k'>html_table</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>cbind</a></span>(colour = <span class='s'>"white"</span>)
<span class='k'>rose_wines</span> <span class='o'>&lt;-</span> <span class='k'>wiki_tables</span>[[<span class='m'>3</span>]] <span class='o'>%&gt;%</span> <span class='k'>html_table</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>cbind</a></span>(colour = <span class='s'>"rosé"</span>)
<span class='k'>all_wines</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>rbind</a></span>(<span class='k'>red_wines</span>, <span class='k'>white_wines</span>, <span class='k'>rose_wines</span>)
<span class='k'>all_wines</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>`Common Name(s)`</span>, <span class='k'>`All Synonyms`</span>, <span class='k'>colour</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/utils/head.html'>head</a></span>(<span class='m'>1</span>)
<span class='c'>#&gt;   Common Name(s)   All Synonyms colour</span>
<span class='c'>#&gt; 1        Abbuoto Aboto, Cecubo.    red</span></code></pre>

</div>

We're interested in three columns here: `Common Name(s)`, `All Synonyms` and the `colour` column we defined from the table scraping. We will take the opportunity to rename the columns to match the tidyverse style.

Apart from synonyms, some wines can also have multiple common names, eg. "shiraz / syrah". The synonyms seem to be very broad, and can include some unexpected results: pinot grigio (also known as pinot gris) is used to produce white wine, yet it appears as a synonym to canari noir, which is used to make red wine.

We're going to preference the common names over the synonyms, so that in any conflict we use the colour as given by the common name. To do this, we're going to `unnest` the common names and clean the results so that all entries are in lower-case, the results are distinct, and certain stray bits of punctuation are removed. We're then going to do the same with the synonyms, but when we combine the results we will ignore all entries that are already provided by the common names.

The end result will be a single table with two columns: `variety`, and `colour`. The table may very well still contain duplicates, but certainly less than we would have had if we had treated common names and synonyms as equals.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>all_wines_cleaned</span> <span class='o'>&lt;-</span> <span class='k'>all_wines</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>rename</span>(
        common_names = <span class='k'>`Common Name(s)`</span>,
        synonyms = <span class='k'>`All Synonyms`</span>
    ) <span class='o'>%&gt;%</span> 
    <span class='nf'>mutate_all</span>(<span class='k'>tolower</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>common_names</span>, <span class='k'>synonyms</span>, <span class='k'>colour</span>)

<span class='k'>common_names</span> <span class='o'>&lt;-</span> <span class='k'>all_wines_cleaned</span> <span class='o'>%&gt;%</span>
    <span class='nf'>unnest</span>(common_names = <span class='nf'><a href='https://rdrr.io/r/base/strsplit.html'>strsplit</a></span>(<span class='k'>common_names</span>, <span class='s'>" / "</span>)) <span class='o'>%&gt;%</span> <span class='c'># split common names into separate rows</span>
    <span class='nf'>rename</span>(variety = <span class='k'>common_names</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>mutate</span>(
        variety = <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\\."</span>, <span class='s'>""</span>, <span class='k'>variety</span>), <span class='c'># remove periods </span>
        variety = <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\\s*\\([^\\)]+\\)"</span>, <span class='s'>""</span>, <span class='k'>variety</span>), <span class='c'># remove brackets and anything within</span>
        variety = <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\\s*\\[[^\\)]+\\]"</span>, <span class='s'>""</span>, <span class='k'>variety</span>) <span class='c'># same for square brackets</span>
    ) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>variety</span>, <span class='k'>colour</span>)
<span class='c'>#&gt; Warning: unnest() has a new interface. See ?unnest for details.</span>
<span class='c'>#&gt; Try `df %&gt;% unnest(c(common_names))`, with `mutate()` if needed</span>

<span class='k'>synonyms</span> <span class='o'>&lt;-</span> <span class='k'>all_wines_cleaned</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>unnest</span>(synonyms = <span class='nf'><a href='https://rdrr.io/r/base/strsplit.html'>strsplit</a></span>(<span class='k'>synonyms</span>, <span class='s'>", "</span>)) <span class='o'>%&gt;%</span> <span class='c'># split the synonyms into multiple rows</span>
    <span class='nf'>rename</span>(variety = <span class='k'>synonyms</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>mutate</span>(
        variety = <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\\."</span>, <span class='s'>""</span>, <span class='k'>variety</span>), <span class='c'># remove periods </span>
        variety = <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\\s*\\([^\\)]+\\)"</span>, <span class='s'>""</span>, <span class='k'>variety</span>), <span class='c'># remove brackets and anything within</span>
        variety = <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\\s*\\[[^\\)]+\\]"</span>, <span class='s'>""</span>, <span class='k'>variety</span>) <span class='c'># same for square brackets</span>
    ) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>variety</span>, <span class='k'>colour</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>anti_join</span>(<span class='k'>common_names</span>, by = <span class='s'>"variety"</span>) <span class='c'># remove synonyms if we have a common name</span>
<span class='c'>#&gt; Warning: unnest() has a new interface. See ?unnest for details.</span>
<span class='c'>#&gt; Try `df %&gt;% unnest(c(synonyms))`, with `mutate()` if needed</span>

<span class='k'>variety_colours</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>rbind</a></span>(<span class='k'>common_names</span>, <span class='k'>synonyms</span>) <span class='o'>%&gt;%</span> 
    <span class='k'>distinct</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>arrange</span>(<span class='k'>variety</span>)

<span class='k'>variety_colours</span> <span class='o'>%&gt;%</span> <span class='k'>head</span>
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 6 x 2</span></span>
<span class='c'>#&gt;   variety             colour</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>               </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span> </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> </span><span style='color: #949494;'>"</span><span> barbera dolce</span><span style='color: #949494;'>"</span><span>    red   </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> </span><span style='color: #949494;'>"</span><span> cosses barbusen</span><span style='color: #949494;'>"</span><span>  red   </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> </span><span style='color: #949494;'>"</span><span> limberger blauer</span><span style='color: #949494;'>"</span><span> red   </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> </span><span style='color: #949494;'>"</span><span>22 a baco</span><span style='color: #949494;'>"</span><span>         white </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span> </span><span style='color: #949494;'>"</span><span>abbondosa</span><span style='color: #949494;'>"</span><span>         white </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>6</span><span> </span><span style='color: #949494;'>"</span><span>abboudossa</span><span style='color: #949494;'>"</span><span>        white</span></span></code></pre>

</div>

The end result is 8469 rows, with plenty of repeated entries to accommodate for multiple names or variations in spelling.

Joining the colour data
-----------------------

Now we join the colours with the wine data. If there are any missing values, we can attempt to fill them in based on obvious clues in the variety (eg. a "Red blend" can safely be assumed to be a red wine). We're going to repeat this join as we iteratively improve the `variety_colours` data, so we'll define it as a function.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>join_with_variety_colours</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>wine</span>, <span class='k'>variety_colours</span>) {
    <span class='k'>wine</span> <span class='o'>%&gt;%</span> 
        <span class='nf'>left_join</span>(
            <span class='k'>variety_colours</span> <span class='o'>%&gt;%</span> <span class='nf'>select</span>(<span class='k'>variety</span>, <span class='k'>colour</span>),
            by = <span class='s'>"variety"</span>
        ) <span class='o'>%&gt;%</span> 
        <span class='nf'>mutate</span>(
            colour = <span class='nf'>case_when</span>(
                <span class='o'>!</span><span class='nf'><a href='https://rdrr.io/r/base/NA.html'>is.na</a></span>(<span class='k'>colour</span>) <span class='o'>~</span> <span class='k'>colour</span>,
                <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"sparkling"</span>, <span class='k'>variety</span>, ignore.case = <span class='kc'>TRUE</span>) <span class='o'>~</span> <span class='s'>"white"</span>,
                <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"champagne"</span>, <span class='k'>variety</span>, ignore.case = <span class='kc'>TRUE</span>) <span class='o'>~</span> <span class='s'>"white"</span>,
                <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"red"</span>, <span class='k'>variety</span>, ignore.case = <span class='kc'>TRUE</span>) <span class='o'>~</span> <span class='s'>"red"</span>,
                <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"white"</span>, <span class='k'>variety</span>, ignore.case = <span class='kc'>TRUE</span>) <span class='o'>~</span> <span class='s'>"white"</span>,
                <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"rosé"</span>, <span class='k'>variety</span>, ignore.case = <span class='kc'>TRUE</span>) <span class='o'>~</span> <span class='s'>"rosé"</span>,
                <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"rose"</span>, <span class='k'>variety</span>, ignore.case = <span class='kc'>TRUE</span>) <span class='o'>~</span> <span class='s'>"rosé"</span>
            )
        )
}

<span class='k'>wine_colours</span> <span class='o'>&lt;-</span> <span class='k'>wine</span> <span class='o'>%&gt;%</span> <span class='nf'>join_with_variety_colours</span>(<span class='k'>variety_colours</span>)

<span class='k'>plot_wine_colours</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>wine_colours</span>) {
    <span class='k'>wine_colours</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/ggplot.html'>ggplot</a></span>(<span class='nf'><a href='https://ggplot2.tidyverse.org/reference/aes.html'>aes</a></span>(x = <span class='k'>colour</span>, fill = <span class='k'>colour</span>)) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/geom_bar.html'>geom_bar</a></span>() <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/scale_manual.html'>scale_fill_manual</a></span>(values = <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(
        <span class='s'>"red"</span> = <span class='k'>red_wine_colour</span>, 
        <span class='s'>"white"</span> = <span class='k'>white_wine_colour</span>, 
        <span class='s'>"rosé"</span> = <span class='k'>rose_wine_colour</span>),
        na.value = <span class='s'>"grey"</span>
    ) <span class='o'>+</span> 
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/labs.html'>ggtitle</a></span>(<span class='s'>"Wine colours"</span>) <span class='o'>+</span>
    <span class='nf'><a href='https://ggplot2.tidyverse.org/reference/theme.html'>theme</a></span>(legend.position=<span class='s'>"none"</span>)
}

<span class='nf'>plot_wine_colours</span>(<span class='k'>wine_colours</span>)
</code></pre>
<img src="figs/join_with_variety_colours-1.png" width="700px" style="display: block; margin: auto;" />

</div>

All but 6734 wines have been classified. We still have some colours missing, but first we consider the wines that have been classified as multiple colours:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>wine_colours</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>distinct</span>(<span class='k'>variety</span>, <span class='k'>colour</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>count</span>(<span class='k'>variety</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='k'>n</span> <span class='o'>&gt;</span> <span class='m'>1</span>)
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 4 x 2</span></span>
<span class='c'>#&gt;   variety           n</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>         </span><span style='color: #949494;font-style: italic;'>&lt;int&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> alicante          2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> grignolino        2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> malvasia fina     2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> sauvignon         2</span></span></code></pre>

</div>

We use web searches to manually classify the varieties based on the colour of the wine that is most often produced from them.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>variety_colours</span> <span class='o'>&lt;-</span> <span class='k'>variety_colours</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='o'>!</span>(<span class='k'>variety</span> <span class='o'>==</span> <span class='s'>"alicante"</span> <span class='o'>&amp;</span> <span class='k'>colour</span> != <span class='s'>"red"</span>)) <span class='o'>%&gt;%</span>     
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='o'>!</span>(<span class='k'>variety</span> <span class='o'>==</span> <span class='s'>"grignolino"</span> <span class='o'>&amp;</span> <span class='k'>colour</span> != <span class='s'>"red"</span>)) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='o'>!</span>(<span class='k'>variety</span> <span class='o'>==</span> <span class='s'>"malvasia fina"</span> <span class='o'>&amp;</span> <span class='k'>colour</span> != <span class='s'>"white"</span>)) <span class='o'>%&gt;%</span> <span class='c'># rarely red</span>
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='o'>!</span>(<span class='k'>variety</span> <span class='o'>==</span> <span class='s'>"sauvignon"</span> <span class='o'>&amp;</span> <span class='k'>colour</span> != <span class='s'>"white"</span>))</code></pre>

</div>

The below suggests that blends are not being classified:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>wine_colours</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/NA.html'>is.na</a></span>(<span class='k'>colour</span>)) <span class='o'>%&gt;%</span> 
    <span class='nf'>count</span>(<span class='k'>variety</span>, sort = <span class='kc'>TRUE</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/utils/head.html'>head</a></span>(<span class='m'>10</span>)
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 10 x 2</span></span>
<span class='c'>#&gt;    variety                           n</span>
<span class='c'>#&gt;    <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>                         </span><span style='color: #949494;font-style: italic;'>&lt;int&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 1</span><span> port                            668</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 2</span><span> corvina, rondinella, molinara   619</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 3</span><span> tempranillo blend               588</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 4</span><span> carmenère                       575</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 5</span><span> meritage                        260</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 6</span><span> g-s-m                           181</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 7</span><span> mencía                          178</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 8</span><span> cabernet sauvignon-merlot       117</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 9</span><span> nerello mascalese               117</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>10</span><span> rosato                          103</span></span></code></pre>

</div>

We operate under the assumption that if multiple wines are listed, the first wine determines the colour. For example, cabernet is red and sauvignon is white, but cabernet sauvignon is red. We try to classify the unclassified wines again but using only the first word in their varieties. We split the variety by either spaces or dashes.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>blend_colours</span> <span class='o'>&lt;-</span> 
    <span class='k'>wine_colours</span> <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/NA.html'>is.na</a></span>(<span class='k'>colour</span>)) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>variety</span>) <span class='o'>%&gt;%</span> 
    <span class='k'>rowwise</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>mutate</span>(first_variety = <span class='nf'><a href='https://rdrr.io/r/base/unlist.html'>unlist</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/strsplit.html'>strsplit</a></span>(<span class='k'>variety</span>, <span class='s'>"\\-|\\ | "</span>))[<span class='m'>1</span>]) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/base/merge.html'>merge</a></span>(<span class='k'>variety_colours</span>, by.x = <span class='s'>"first_variety"</span>, by.y = <span class='s'>"variety"</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>variety</span>, <span class='k'>colour</span>) <span class='o'>%&gt;%</span> 
    <span class='k'>distinct</span></code></pre>

</div>

Now we can rebuild the wine colours using these new blend results:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>wine_colours</span> <span class='o'>&lt;-</span> <span class='k'>wine</span> <span class='o'>%&gt;%</span> <span class='nf'>join_with_variety_colours</span>(
    <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>rbind</a></span>(<span class='k'>variety_colours</span>, <span class='k'>blend_colours</span>)
) 

<span class='nf'>plot_wine_colours</span>(<span class='k'>wine_colours</span>)
</code></pre>
<img src="figs/join_with_blend_colours-1.png" width="700px" style="display: block; margin: auto;" />

</div>

All but 4091 wines have been classified. This is an improvement, but we still have to classify the rest.

Manual classifications
----------------------

We manually classify the remaining 154 varieties using web searches or the `description`s (reviews) associated with the wines.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>manual_colours</span> <span class='o'>&lt;-</span> <span class='s'>"manually_classified.csv"</span> <span class='o'>%&gt;%</span> <span class='k'>read_csv</span>
<span class='c'>#&gt; Parsed with column specification:</span>
<span class='c'>#&gt; cols(</span>
<span class='c'>#&gt;   variety = <span style='color: #BB0000;'>col_character()</span><span>,</span></span>
<span class='c'>#&gt;   colour = <span style='color: #BB0000;'>col_character()</span></span>
<span class='c'>#&gt; )</span>

<span class='k'>wine_colours</span> <span class='o'>&lt;-</span> <span class='k'>wine</span> <span class='o'>%&gt;%</span> <span class='nf'>join_with_variety_colours</span>(
    <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>rbind</a></span>(<span class='k'>variety_colours</span>, <span class='k'>blend_colours</span>, <span class='k'>manual_colours</span>)
) 

<span class='nf'>plot_wine_colours</span>(<span class='k'>wine_colours</span>)
</code></pre>
<img src="figs/manual_colours-1.png" width="700px" style="display: block; margin: auto;" />

</div>

And we're there! As I said earlier, this is a somewhat aggressive classification. But we've got the most popular wines---the pinot noirs and the chardonnays---classified, and we can hope that any errors are only "kind of wrong" rather than "totally wrong", and limited to the varieties that only appear once or twice.

Data sources
------------

To avoid any potential licencing issues, I prefer not to post Kaggle data directly here. I encourage you to download the csv [directly from Kaggle](https://www.kaggle.com/zynicide/wine-reviews/). This will require a (free) Kaggle account. I've renamed the file here to `wine_reviews.csv`, but otherwise the data is unchanged before it is read. Other data used here:

-   My manual classification of variety colours: [manually\_classified.csv](/data/manually_classified.csv)
-   The final outcome, giving just varieties and colours: [variety\_colours.csv](/data/variety_colours.csv)

The header image at the top of this page is in the [public domain](https://www.pexels.com/photo/abundance-alcohol-berries-berry-357742/).

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
<span class='c'>#&gt;  broom         0.5.6      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cellranger    1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  codetools     0.2-16     2018-12-24 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  colorspace    1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  curl          4.3        2019-12-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  DBI           1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  dbplyr        1.4.3      2020-04-19 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-06-12 [1] Github (r-lib/downlit@87fb1af)    </span>
<span class='c'>#&gt;  dplyr       * 0.8.5      2020-03-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  farver        2.0.3      2020-01-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  forcats     * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  fs            1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  generics      0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ggplot2     * 3.3.0      2020-03-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  gtable        0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  haven         2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  highr         0.8        2019-03-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  htmltools     0.4.0      2019-10-04 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  httr          1.4.1      2019-08-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-06-12 [1] Github (r-lib/hugodown@6812ada)   </span>
<span class='c'>#&gt;  jsonlite      1.6.1      2020-02-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  kableExtra  * 1.1.0      2019-03-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  knitr         1.28       2020-02-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  labeling      0.3        2014-08-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lattice       0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  lubridate     1.7.8      2020-04-06 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)   </span>
<span class='c'>#&gt;  modelr        0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  munsell       0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  nlme          3.1-145    2020-03-04 [4] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pillar        1.4.4      2020-05-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgbuild      1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  pkgload       1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  processx      3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  ps            1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  purrr       * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  Rcpp          1.0.4.6    2020-04-09 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readr       * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  readxl        1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  reprex        0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rlang         0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rmarkdown     2.2.3      2020-06-12 [1] Github (rstudio/rmarkdown@4ee96c8)</span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rstudioapi    0.11       2020-02-07 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  rvest       * 0.3.5      2019-11-08 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  scales        1.1.0      2019-11-18 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  selectr       0.4-2      2019-11-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  stringr     * 1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tibble      * 3.0.1      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyr       * 1.0.2      2020-01-24 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyselect    1.0.0      2020-01-27 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  tidyverse   * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  vctrs         0.3.1      2020-06-05 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  viridisLite   0.3.0      2018-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  webshot       0.5.2      2019-11-22 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xfun          0.14       2020-05-20 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  xml2        * 1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                    </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

