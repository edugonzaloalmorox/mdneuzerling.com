---
title: Markdown monsters
author: ''
date: '2018-09-02'
slug: markdown-monsters
categories: []
tags:
  - R
  - scraping
images: ["/img/dice.jpg"]
featuredalt: "dice"
output: hugodown::md_document
rmd_hash: 21e10c59cb795420

---

Whenever I take an interest in something I think to myself, "How can I combine this with R?"

This post is the result of applying that attitude to Dungeons and Dragons.

So how would I combine D&D with R? A good start would be to have a nice data set of Dungeons and Dragons monsters, with all of their statistics, abilities and attributes. One of the core D&D rule books is the [Monster Manual](http://dnd.wizards.com/products/tabletop-games/rpg-products/monster-manual). I could attempt to scrape the Monster Manual but I figured that the lovely people behind D&D wouldn't be too happy if I uploaded most of the book to GitHub!

Fortunately, Wizards of the Coast have included around 300 monsters in the [Systems Reference Document](http://dnd.wizards.com/articles/features/systems-reference-document-srd) (SRD) for 5th edition D&D. This is made available under the Open Gaming License Version 1.0a.

I started off trying to scrape the SRD directly, but scraping a PDF was looking to be a nightmare. Fortunately, [vitusventure had already converted the SRD to markdown documents](https://github.com/vitusventure/5thSRD) to host the content on the (rather pretty) <https://5thsrd.org/>. I figured it would be easier to scrape markdown files, since they are structured but simple text. Here's an example of a monster's "stat block" written in markdown:

------------------------------------------------------------------------

name: Medusa type: monstrosity cr: 6

Medusa
======

*Medium monstrosity, lawful evil*

**Armor Class** 15 (natural armor)  
**Hit Points** 127 (17d8 + 51)  
**Speed** 30 ft.

| STR     | DEX     | CON     | INT     | WIS     | CHA     |
|---------|---------|---------|---------|---------|---------|
| 10 (+0) | 15 (+2) | 16 (+3) | 12 (+1) | 13 (+1) | 15 (+2) |

**Skills** Deception +5, Insight +4, Perception +4, Stealth +5  
**Senses** darkvision 60 ft., passive Perception 14  
**Languages** Common  
**Challenge** 6 (2,300 XP)

**Petrifying Gaze.** When a creature that can see the medusa's eyes starts its turn within 30 feet of the medusa, the medusa can force it to make a DC 14 Constitution saving throw if the medusa isn't incapacitated and can see the creature. If the saving throw fails by 5 or more, the creature is instantly petrified. Otherwise, a creature that fails the save begins to turn to stone and is restrained. The restrained creature must repeat the saving throw at the end of its next turn, becoming petrified on a failure or ending the effect on a success. The petrification lasts until the creature is freed by the greater restoration spell or other magic.  
Unless surprised, a creature can avert its eyes to avoid the saving throw at the start of its turn. If the creature does so, it can't see the medusa until the start of its next turn, when it can avert its eyes again. If the creature looks at the medusa in the meantime, it must immediately make the save.  
If the medusa sees itself reflected on a polished surface within 30 feet of it and in an area of bright light, the medusa is, due to its curse, affected by its own gaze.

### Actions

**Multiattack.** The medusa makes either three melee attacks--one with its snake hair and two with its shortsword--or two ranged attacks with its longbow.  
**Snake Hair.** *Melee Weapon Attack:* +5 to hit, reach 5 ft., one creature. *Hit:* 4 (1d4 + 2) piercing damage plus 14 (4d6) poison damage.  
**Shortsword.** *Melee Weapon Attack:* +5 to hit, reach 5 ft., one target. *Hit:* 5 (1d6 + 2) piercing damage.  
**Longbow.** *Ranged Weapon Attack:* +5 to hit, range 150/600 ft., one target. *Hit:* 6 (1d8 + 2) piercing damage plus 7 (2d6) poison damage.

------------------------------------------------------------------------

I put the scraped monsters in the SRD into the `monsters` data set and uploaded it to a quickly created `monstr` package. You can access the data set by installing the package with [`devtools::install_github("mdneuzerling/monstr")`](https://devtools.r-lib.org//reference/remote-reexports.html).

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>monsters</span> <span class='o'>&lt;-</span> <span class='k'>monstr</span>::<span class='k'><a href='https://rdrr.io/pkg/monstr/man/monsters.html'>monsters</a></span>
<span class='k'>skimr</span>::<span class='nf'><a href='https://docs.ropensci.org/skimr/reference/skim.html'>skim</a></span>(<span class='k'>monsters</span>)
</code></pre>

|                                                  |          |
|:-------------------------------------------------|:---------|
| Name                                             | monsters |
| Number of rows                                   | 317      |
| Number of columns                                | 39       |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_   |          |
| Column type frequency:                           |          |
| character                                        | 10       |
| list                                             | 1        |
| numeric                                          | 28       |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |          |
| Group variables                                  | None     |

**Variable type: character**

| skim\_variable |  n\_missing|  complete\_rate|  min|  max|  empty|  n\_unique|  whitespace|
|:---------------|-----------:|---------------:|----:|----:|------:|----------:|-----------:|
| name           |           0|            1.00|    3|   25|      0|        317|           0|
| type           |           0|            1.00|    3|   30|      0|         35|           0|
| size           |           0|            1.00|    4|   10|      0|          6|           0|
| alignment      |           0|            1.00|    7|   40|      0|         16|           0|
| ac\_note       |         108|            0.66|    5|   23|      0|         22|           0|
| hp             |           0|            1.00|    3|   11|      0|        168|           0|
| senses         |           0|            1.00|   20|  170|      0|         88|           0|
| languages      |           0|            1.00|    1|   91|      0|         86|           0|
| speed          |           0|            1.00|    4|   52|      0|         90|           0|
| description    |         274|            0.14|   96|  654|      0|         43|           0|

**Variable type: list**

| skim\_variable |  n\_missing|  complete\_rate|  n\_unique|  min\_length|  max\_length|
|:---------------|-----------:|---------------:|----------:|------------:|------------:|
| actions        |           3|            0.99|        305|            1|           10|

**Variable type: numeric**

| skim\_variable    |  n\_missing|  complete\_rate|     mean|        sd|   p0|    p25|  p50|   p75|    p100| hist  |
|:------------------|-----------:|---------------:|--------:|---------:|----:|------:|----:|-----:|-------:|:------|
| cr                |           0|               1|     4.60|      5.91|    0|    0.5|    2|     6|      30| ▇▁▁▁▁ |
| xp                |           0|               1|  4275.30|  12436.13|    0|  100.0|  450|  2300|  155000| ▇▁▁▁▁ |
| ac                |           0|               1|    14.07|      3.27|    5|   12.0|   13|    17|      25| ▁▇▅▂▁ |
| hp\_avg           |           0|               1|    82.31|     99.88|    1|   18.0|   45|   114|     676| ▇▁▁▁▁ |
| str               |           0|               1|    15.34|      6.63|    1|   11.0|   16|    19|      30| ▂▃▇▃▂ |
| dex               |           0|               1|    12.61|      3.22|    1|   10.0|   13|    15|      28| ▁▅▇▁▁ |
| con               |           0|               1|    15.16|      4.50|    8|   12.0|   14|    18|      30| ▇▇▅▂▁ |
| int               |           0|               1|     7.86|      5.69|    1|    2.0|    7|    12|      25| ▇▅▃▂▁ |
| wis               |           0|               1|    11.72|      2.98|    0|   10.0|   12|    13|      25| ▁▅▇▁▁ |
| cha               |           0|               1|     9.79|      5.76|    0|    5.0|    8|    14|      30| ▇▇▅▂▁ |
| acrobatics        |           0|               1|     1.12|      1.64|   -5|    0.0|    1|     2|       9| ▁▅▇▁▁ |
| animal\_handling  |           0|               1|     0.66|      1.49|   -5|    0.0|    1|     1|       7| ▁▁▇▁▁ |
| arcana            |           0|               1|    -1.07|      3.46|   -5|   -4.0|   -2|     1|      18| ▇▅▁▁▁ |
| athletics         |           0|               1|     2.55|      3.48|   -5|    0.0|    3|     4|      14| ▂▆▇▂▁ |
| deception         |           0|               1|    -0.11|      3.37|   -5|   -3.0|   -1|     2|      11| ▇▅▃▂▁ |
| history           |           0|               1|    -1.05|      3.46|   -5|   -4.0|   -2|     1|      13| ▇▅▂▁▁ |
| insight           |           0|               1|     0.95|      2.12|   -5|    0.0|    1|     1|      10| ▁▇▂▁▁ |
| intimidation      |           0|               1|    -0.35|      2.94|   -5|   -3.0|   -1|     2|      10| ▇▅▃▁▁ |
| investigation     |           0|               1|    -1.26|      2.94|   -5|   -4.0|   -2|     1|       7| ▇▃▆▂▁ |
| medicine          |           0|               1|     0.68|      1.55|   -5|    0.0|    1|     1|       7| ▁▁▇▁▁ |
| nature            |           0|               1|    -1.26|      2.93|   -5|   -4.0|   -2|     1|       7| ▇▃▆▂▁ |
| perception        |           0|               1|     2.87|      4.02|   -5|    0.0|    2|     4|      17| ▂▇▃▁▁ |
| performance       |           0|               1|    -0.36|      2.94|   -5|   -3.0|   -1|     2|      10| ▇▅▃▁▁ |
| persuasion        |           0|               1|    -0.19|      3.34|   -5|   -3.0|   -1|     2|      16| ▇▅▂▁▁ |
| religion          |           0|               1|    -1.18|      3.12|   -5|   -4.0|   -2|     1|      15| ▇▅▁▁▁ |
| sleight\_of\_hand |           0|               1|     1.11|      1.62|   -5|    0.0|    1|     2|       9| ▁▅▇▁▁ |
| stealth           |           0|               1|     2.30|      2.56|   -5|    0.0|    2|     4|      10| ▁▇▇▃▁ |
| survival          |           0|               1|     0.70|      1.54|   -5|    0.0|    1|     1|       7| ▁▁▇▁▁ |

</div>

Because it's an R crime to introduce a new data set without a ggplot, here we can see the relationship between strength and constitution, faceted by monster size:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>monsters</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>ggplot</span>(<span class='nf'>aes</span>(x = <span class='k'>str</span>, y = <span class='k'>con</span>)) <span class='o'>+</span> 
    <span class='nf'>geom_point</span>() <span class='o'>+</span> 
    <span class='nf'>facet_wrap</span>(<span class='k'>.</span> <span class='o'>~</span> <span class='k'>size</span>, nrow = <span class='m'>2</span>)
</code></pre>
<img src="figs/monster_ggplot-1.png" width="700px" style="display: block; margin: auto;" />

</div>

One note before we go on: "monster" is a generic term. This data set contains bandits which, while of questionable moral character, are not necessarily monstrous. You can also find a simple frog in this data set, capable of nothing more than a ribbit. We refer to them all as "monsters", perhaps unfairly!

Scraping line-by-line
---------------------

Let's take the Medusa `monster` above, loaded as a single string. I'm going to make life easier for myself by separating the string into lines. At first I tried to do this myself with `strsplit`, but please take my advice: use the `stringi` package. You'll notice that I turn the resulting list into a single-column tibble. I won't lie: I find manipulating lists directly difficult, so being able to use `dplyr` verbs makes me happy. I'm also going to remove the italics (represented in markdown by underscores) since I won't need them here.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>lines</span> <span class='o'>&lt;-</span> <span class='k'>monster</span> <span class='o'>%&gt;%</span> 
        <span class='k'>stringi</span>::<span class='nf'><a href='https://rdrr.io/pkg/stringi/man/stri_split_lines.html'>stri_split_lines</a></span>(omit_empty = <span class='kc'>TRUE</span>) <span class='o'>%&gt;%</span> 
        <span class='k'>unlist</span> <span class='o'>%&gt;%</span> 
        <span class='k'>as_tibble</span> <span class='o'>%&gt;%</span> <span class='c'># much easier to deal with than lists</span>
        <span class='nf'>mutate_all</span>(<span class='k'>trimws</span>) <span class='o'>%&gt;%</span> 
        <span class='nf'>mutate_all</span>(<span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"_"</span>, <span class='s'>""</span>, <span class='k'>x</span>)) <span class='c'># remove italics</span>
<span class='nf'><a href='https://rdrr.io/r/base/print.html'>print</a></span>(<span class='k'>lines</span>, n = <span class='nf'><a href='https://rdrr.io/r/base/nrow.html'>nrow</a></span>(<span class='k'>lines</span>))
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 23 x 1</span></span>
<span class='c'>#&gt;    value                                                                        </span>
<span class='c'>#&gt;    <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>                                                                        </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 1</span><span> name: Medusa                                                                 </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 2</span><span> type: monstrosity                                                            </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 3</span><span> cr: 6                                                                        </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 4</span><span> # Medusa                                                                     </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 5</span><span> Medium monstrosity, lawful evil                                              </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 6</span><span> **Armor Class** 15 (natural armor)                                           </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 7</span><span> **Hit Points** 127 (17d8 + 51)                                               </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 8</span><span> **Speed** 30 ft.                                                             </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'> 9</span><span> | STR     | DEX     | CON     | INT     | WIS     | CHA     |                </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>10</span><span> |---------|---------|---------|---------|---------|---------|                </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>11</span><span> | 10 (+0) | 15 (+2) | 16 (+3) | 12 (+1) | 13 (+1) | 15 (+2) |                </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>12</span><span> **Skills** Deception +5, Insight +4, Perception +4, Stealth +5               </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>13</span><span> **Senses** darkvision 60 ft., passive Perception 14                          </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>14</span><span> **Languages** Common                                                         </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>15</span><span> **Challenge** 6 (2,300 XP)                                                   </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>16</span><span> **Petrifying Gaze.** When a creature that can see the medusa's eyes starts i…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>17</span><span> Unless surprised, a creature can avert its eyes to avoid the saving throw at…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>18</span><span> If the medusa sees itself reflected on a polished surface within 30 feet of …</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>19</span><span> ### Actions                                                                  </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>20</span><span> **Multiattack.** The medusa makes either three melee attacks--one with its s…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>21</span><span> **Snake Hair.** Melee Weapon Attack: +5 to hit, reach 5 ft., one creature. H…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>22</span><span> **Shortsword.** Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>23</span><span> **Longbow.** Ranged Weapon Attack: +5 to hit, range 150/600 ft., one target.…</span></span></code></pre>

</div>

Scraping monster name, type and CR
----------------------------------

The wonderful thing about these markdown files is that they have a nifty couple of lines up the top listing the name, type and challenge rating (cr) of the monster. These are marked by headings with colons, so we'll define a function to extract the data based on that.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>extract_from_colon_heading</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>lines</span>, <span class='k'>heading</span>) {
    <span class='k'>lines</span> <span class='o'>%&gt;%</span> 
        <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>(<span class='k'>heading</span>, <span class='s'>":"</span>), <span class='k'>value</span>)) <span class='o'>%&gt;%</span> 
        <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>(<span class='k'>heading</span>, <span class='s'>":"</span>), <span class='s'>""</span>, <span class='k'>.</span>) <span class='o'>%&gt;%</span> 
        <span class='k'>as.character</span> <span class='o'>%&gt;%</span> 
        <span class='k'>trimws</span>
}

<span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(
    <span class='nf'>extract_from_colon_heading</span>(<span class='k'>lines</span>, <span class='s'>"name"</span>),
    <span class='nf'>extract_from_colon_heading</span>(<span class='k'>lines</span>, <span class='s'>"type"</span>),
    <span class='nf'>extract_from_colon_heading</span>(<span class='k'>lines</span>, <span class='s'>"cr"</span>)
)
<span class='c'>#&gt; [1] "Medusa"      "monstrosity" "6"</span></code></pre>

</div>

I should offer some explanations for those new to D&D! The "type" of a monster is a category like beast, undead or---in the case of the Medusa---monstrosity. The challenge rating is a rough measure of difficulty. The Medusa has a challenge rating of 6, so is a suitable encounter for 4 players with characters of level 6. Characters begin at level 1 and move up to level 20 (if the campaign lasts that long).

Scraping based on bold text
---------------------------

Most of the information we need is labelled by bold text, represented in markdown by double asterisks. We'll define three functions:

1.  `identify_bold_text` looks for a given `bold_text` in a string `x`, and returns a Boolean value.
2.  `strip_bold_text` removes *all* bolded text from a string `x`, and trims white space from either end of the result.
3.  `extract_from_bold_text` looks through a list of lines (like the `lines` defined above) for a particular `bold_text`. It will return all text in the string *except* the `bold_text`. This function uses the two above.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>identify_bold_text</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>, <span class='k'>bold_text</span>) {
    <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/paste.html'>paste0</a></span>(<span class='s'>"\\*\\*"</span>, <span class='k'>bold_text</span>, <span class='s'>"\\*\\*"</span>), <span class='k'>x</span>, ignore.case = <span class='kc'>TRUE</span>)
}

<span class='k'>strip_bold_text</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) {
    <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>"\\*\\*(.*?)\\*\\*"</span>, <span class='s'>""</span>, <span class='k'>x</span>, ignore.case = <span class='kc'>TRUE</span>) <span class='o'>%&gt;%</span> <span class='k'>trimws</span>
}

<span class='k'>extract_from_bold_text</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>lines</span>, <span class='k'>bold_text</span>) {
    <span class='k'>lines</span> <span class='o'>%&gt;%</span> 
        <span class='nf'><a href='https://rdrr.io/r/stats/filter.html'>filter</a></span>(<span class='nf'>identify_bold_text</span>(<span class='k'>value</span>, <span class='k'>bold_text</span>)) <span class='o'>%&gt;%</span> 
        <span class='k'>as.character</span> <span class='o'>%&gt;%</span> 
        <span class='k'>strip_bold_text</span>
}

<span class='nf'>extract_from_bold_text</span>(<span class='k'>lines</span>, <span class='s'>"Languages"</span>)
<span class='c'>#&gt; [1] "Common"</span></code></pre>

</div>

Scraping based on brackets
--------------------------

Some of the data we need is found in bracketed information. The `extract_bracketed` function returns all text inside the first set of brackets found in a string `x`, or returns `NA` if no bracketed text is found.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>extract_bracketed</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) {
    <span class='kr'>if</span> (<span class='o'>!</span><span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"\\(.*\\)"</span>, <span class='k'>x</span>)) {
        <span class='nf'><a href='https://rdrr.io/r/base/function.html'>return</a></span>(<span class='m'>NA</span>)
    } <span class='kr'>else</span> {
        <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>".*\\((.*?)\\).*"</span>, <span class='s'>"\\1"</span>, <span class='k'>x</span>)
    }
}

<span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Armor Class"</span>) <span class='o'>%&gt;%</span> <span class='k'>extract_bracketed</span>
<span class='c'>#&gt; [1] "natural armor"</span></code></pre>

</div>

A monster's armor class (AC) determines how hard it is to hit the creature with a weapon or certain spells. The Medusa has an AC of 15. To attack the Medusa, a player will roll a 20-sided die (d20) and add certain modifiers based on their character's skills and proficiencies. If the result is at least 15, the attack hits. The "natural armor" note means that the Medusa's armor class is provided by thickened skin or scales, and not a separate piece of armour.

Abilities
---------

Player characters and monsters in D&D have six ability scores that influence almost everything that they do: strength, dexterity, constitution, intelligence, wisdom and charisma. These abilities are represented by numeric scores that usually (but not always) fall between 10 and 20, with 10 being "average" and 20 being superb.

In the markdown files, these ability scores are tables. We look for the table header and find the ability scores two rows below.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>ability_header</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/Extremes.html'>min</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/which.html'>which</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"\\| STR"</span>, <span class='k'>lines</span><span class='o'>$</span><span class='k'>value</span>), arr.ind = <span class='kc'>TRUE</span>))
<span class='k'>ability_text</span> <span class='o'>&lt;-</span> <span class='k'>lines</span><span class='o'>$</span><span class='k'>value</span>[<span class='k'>ability_header</span> <span class='o'>+</span> <span class='m'>2</span>]
<span class='k'>ability_vector</span> <span class='o'>&lt;-</span> <span class='k'>ability_text</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/r/base/strsplit.html'>strsplit</a></span>(<span class='s'>"\\|"</span>) <span class='o'>%&gt;%</span> <span class='k'>unlist</span>
<span class='k'>monster_ability</span> <span class='o'>&lt;-</span> <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/parse_number.html'>parse_number</a></span>(<span class='k'>ability_vector</span>[<span class='o'>!</span>(<span class='k'>ability_vector</span> <span class='o'>==</span> <span class='s'>""</span>)])
<span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>monster_ability</span>) <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='s'>"STR"</span>, <span class='s'>"DEX"</span>, <span class='s'>"CON"</span>, <span class='s'>"INT"</span>, <span class='s'>"WIS"</span>, <span class='s'>"CHA"</span>)
<span class='k'>monster_ability</span>    
<span class='c'>#&gt; STR DEX CON INT WIS CHA </span>
<span class='c'>#&gt;  10  15  16  12  13  15</span></code></pre>

</div>

Skills
------

Skills represent the monster's ability to perform activities. There are 18 skills, and each skill is associated with one of the 6 ability scores.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>skill_ability</span> <span class='o'>&lt;-</span> <span class='nf'>tribble</span>(
<span class='o'>~</span><span class='k'>skill</span>, <span class='o'>~</span><span class='k'>ability_code_upper</span>,
<span class='c'>#-------|------------------</span>
<span class='s'>"athletics"</span>, <span class='s'>"STR"</span>,
<span class='s'>"acrobatics"</span>, <span class='s'>"DEX"</span>,
<span class='s'>"sleight_of_hand"</span>, <span class='s'>"DEX"</span>,
<span class='s'>"stealth"</span>, <span class='s'>"DEX"</span>,
<span class='s'>"arcana"</span>, <span class='s'>"INT"</span>,
<span class='s'>"history"</span>, <span class='s'>"INT"</span>,
<span class='s'>"investigation"</span>, <span class='s'>"INT"</span>,
<span class='s'>"nature"</span>, <span class='s'>"INT"</span>,
<span class='s'>"religion"</span>, <span class='s'>"INT"</span>,
<span class='s'>"animal_handling"</span>, <span class='s'>"WIS"</span>,
<span class='s'>"insight"</span>, <span class='s'>"WIS"</span>,
<span class='s'>"medicine"</span>, <span class='s'>"WIS"</span>,
<span class='s'>"perception"</span>, <span class='s'>"WIS"</span>,
<span class='s'>"survival"</span>, <span class='s'>"WIS"</span>,
<span class='s'>"deception"</span>, <span class='s'>"CHA"</span>,
<span class='s'>"intimidation"</span>, <span class='s'>"CHA"</span>,
<span class='s'>"performance"</span>, <span class='s'>"CHA"</span>,
<span class='s'>"persuasion"</span>, <span class='s'>"CHA"</span>,
)</code></pre>

</div>

All skills begin with a roll of a d20 for an element of chance. Modifiers, which can be negative, are then added to the result to determine how well the monster did. The Medusa has a +5 bonus to Deception, which would be added to the roll.

If a skill isn't listed in the Medusa's stat block, she can still use it. In this case, she would rely instead on her ability scores. For example, the Medusa isn't trained in acrobatics, but her high dexterity would give her a slight advantage nevertheless.

Modifiers can be calculated from ability scores with a simple formula, defined below. Note that modifiers can be negative. Zombies, for example, are not known for their high intelligence, and have a history modifier of -4.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>modifier</span> <span class='o'>&lt;-</span> <span class='nf'>function</span>(<span class='k'>x</span>) {
    <span class='nf'><a href='https://rdrr.io/r/base/Round.html'>floor</a></span>((<span class='k'>x</span> <span class='o'>-</span> <span class='m'>10</span>) <span class='o'>/</span> <span class='m'>2</span>)
}

<span class='k'>monster_modifiers</span> <span class='o'>&lt;-</span> <span class='k'>monster_ability</span> <span class='o'>%&gt;%</span> 
    <span class='k'>as.list</span> <span class='o'>%&gt;%</span> <span class='c'># preserves list names as column names</span>
    <span class='k'>as_tibble</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>mutate_all</span>(<span class='k'>modifier</span>) <span class='o'>%&gt;%</span> <span class='c'># convert raw ability to modifiers</span>
    <span class='nf'>gather</span>(key = <span class='k'>ability_code_upper</span>, value = <span class='k'>modifier</span>) <span class='c'># convert to long</span>
<span class='k'>monster_modifiers</span>
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 6 x 2</span></span>
<span class='c'>#&gt;   ability_code_upper modifier</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>                 </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> STR                       0</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> DEX                       2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> CON                       3</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> INT                       1</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span> WIS                       1</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>6</span><span> CHA                       2</span></span></code></pre>

</div>

We're going to list every skill modifier for each monster. We start with the `base_skills`, determined solely by the monster's ability scores.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>base_skills</span> <span class='o'>&lt;-</span> <span class='k'>skill_ability</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>left_join</span>(<span class='k'>monster_modifiers</span>, by = <span class='s'>"ability_code_upper"</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'>select</span>(<span class='k'>skill</span>, <span class='k'>modifier</span>)
<span class='nf'><a href='https://rdrr.io/r/utils/head.html'>head</a></span>(<span class='k'>base_skills</span>, <span class='m'>6</span>)
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 6 x 2</span></span>
<span class='c'>#&gt;   skill           modifier</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>              </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> athletics              0</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> acrobatics             2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> sleight_of_hand        2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> stealth                2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span> arcana                 1</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>6</span><span> history                1</span></span></code></pre>

</div>

Now we find the `listed_skills`, which are those explicitly provided in the markdown. We use the `extract_from_bold_text` function, and split the resulting line along the commas into a vector. The words in an element name the skill, while the number gives the modifier.

This chain of piped functions has a peculiar `unlist %>% as.list`, which seems to be necessary to preserve the vector names. I'd love to do without this code, since it seems very ugly!

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>listed_skills</span> <span class='o'>&lt;-</span> <span class='k'>lines</span> <span class='o'>%&gt;%</span> 
    <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Skills"</span>) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/base/strsplit.html'>strsplit</a></span>(<span class='s'>", "</span>) <span class='o'>%&gt;%</span> 
        <span class='k'>unlist</span> <span class='o'>%&gt;%</span>  
        <span class='nf'><a href='https://rdrr.io/r/base/lapply.html'>lapply</a></span>(<span class='nf'>function</span>(<span class='k'>x</span>) {
            <span class='k'>skill_name</span> <span class='o'>&lt;-</span> <span class='nf'>word</span>(<span class='k'>x</span>)
            <span class='k'>skill_modifier</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/c.html'>c</a></span>(<span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/parse_number.html'>parse_number</a></span>(<span class='k'>x</span>))
            <span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>skill_modifier</span>) <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/chartr.html'>tolower</a></span>(<span class='k'>skill_name</span>)
            <span class='k'>skill_modifier</span>
        }) <span class='o'>%&gt;%</span> 
        <span class='k'>unlist</span> <span class='o'>%&gt;%</span> <span class='c'># This is </span>
        <span class='k'>as.list</span> <span class='o'>%&gt;%</span> <span class='c'># so weird</span>
        <span class='k'>as_tibble</span> <span class='o'>%&gt;%</span> 
        <span class='nf'>gather</span>(key = <span class='k'>skill</span>, value = <span class='k'>modifier</span>) <span class='o'>%&gt;%</span> 
        <span class='nf'>mutate</span>(skill = <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>" "</span>, <span class='s'>"_"</span>, <span class='k'>skill</span>)) <span class='c'># keep naming conventions (underscores)</span>
<span class='k'>listed_skills</span>
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 4 x 2</span></span>
<span class='c'>#&gt;   skill      modifier</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>         </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> deception         5</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> insight           4</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> perception        4</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> stealth           5</span></span></code></pre>

</div>

Finally, we combine `listed_skills` and `base_skills`, allowing listed skills to override base skills.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>monster_skills</span> <span class='o'>&lt;-</span> <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/length.html'>length</a></span>(<span class='k'>listed_skills</span>) <span class='o'>==</span> <span class='m'>0</span>) {
    <span class='k'>base_skills</span>
} <span class='kr'>else</span> {
    <span class='k'>listed_skills</span> <span class='o'>%&gt;%</span> <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>rbind</a></span>(
        <span class='nf'>anti_join</span>(<span class='k'>base_skills</span>, <span class='k'>listed_skills</span>, by = <span class='s'>"skill"</span>)
    )
}
<span class='k'>monster_skills</span> <span class='o'>&lt;-</span> <span class='k'>monster_skills</span>[<span class='nf'><a href='https://rdrr.io/r/base/match.html'>match</a></span>(<span class='k'>base_skills</span><span class='o'>$</span><span class='k'>skill</span>, <span class='k'>monster_skills</span><span class='o'>$</span><span class='k'>skill</span>),] <span class='c'># maintain skill order</span>
<span class='nf'><a href='https://rdrr.io/r/utils/head.html'>head</a></span>(<span class='k'>monster_skills</span>, <span class='m'>6</span>)
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 6 x 2</span></span>
<span class='c'>#&gt;   skill           modifier</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>              </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> athletics              0</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> acrobatics             2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> sleight_of_hand        2</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> stealth                5</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span> arcana                 1</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>6</span><span> history                1</span></span></code></pre>

</div>

Monster actions
---------------

Actions are are a tough one. Take a look at the last 5 lines of the markdown:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'><a href='https://rdrr.io/r/utils/head.html'>tail</a></span>(<span class='k'>lines</span>, <span class='m'>5</span>)
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 5 x 1</span></span>
<span class='c'>#&gt;   value                                                                         </span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>                                                                         </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> ### Actions                                                                   </span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>2</span><span> **Multiattack.** The medusa makes either three melee attacks--one with its sn…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>3</span><span> **Snake Hair.** Melee Weapon Attack: +5 to hit, reach 5 ft., one creature. Hi…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>4</span><span> **Shortsword.** Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit:…</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>5</span><span> **Longbow.** Ranged Weapon Attack: +5 to hit, range 150/600 ft., one target. …</span></span></code></pre>

</div>

We're going to look for an actions h3 heading (three hashes) "Actions". The lines that correspond to actions begin after this `Actions` subheading. The last action is determined by finding either:

1.  the line before the next h3 heading or, failing that,
2.  the last line.

We then have a list of lines that correspond to monster actions. We're going to turn these lines into a named vector, in which the name of the action (taken from the bold text) corresponds to the action text.

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>header_rows</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/which.html'>which</a></span>(<span class='nf'><a href='https://rdrr.io/r/base/grep.html'>grepl</a></span>(<span class='s'>"###"</span>, <span class='k'>lines</span><span class='o'>$</span><span class='k'>value</span>), arr.ind = <span class='kc'>TRUE</span>)
    <span class='k'>actions_header_row</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/which.html'>which</a></span>(<span class='k'>lines</span> <span class='o'>==</span> <span class='s'>"### Actions"</span>, arr.ind = <span class='kc'>TRUE</span>)[,<span class='s'>"row"</span>]
    <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/length.html'>length</a></span>(<span class='k'>actions_header_row</span>) <span class='o'>==</span> <span class='m'>0</span>) { <span class='c'># This monster has no actions</span>
        <span class='k'>monster_actions</span> <span class='o'>&lt;-</span> <span class='m'>NA</span>
    } <span class='kr'>else</span> {
        <span class='kr'>if</span> (<span class='nf'><a href='https://rdrr.io/r/base/Extremes.html'>max</a></span>(<span class='k'>header_rows</span>) <span class='o'>==</span> <span class='k'>actions_header_row</span>) {
            <span class='k'>last_action</span> <span class='o'>=</span> <span class='nf'><a href='https://rdrr.io/r/base/nrow.html'>nrow</a></span>(<span class='k'>lines</span>) <span class='c'># in this case, the actions are the last lines</span>
        } <span class='kr'>else</span> {
            <span class='k'>last_action</span> <span class='o'>&lt;-</span>  <span class='nf'><a href='https://rdrr.io/r/base/Extremes.html'>min</a></span>(<span class='k'>header_rows</span>[<span class='k'>header_rows</span> <span class='o'>&gt;</span> <span class='k'>actions_header_row</span>]) <span class='o'>-</span> <span class='m'>1</span> <span class='c'># the row before the heading that comes after ### Actions</span>
        }
        <span class='k'>action_rows</span> <span class='o'>&lt;-</span>  <span class='nf'><a href='https://rdrr.io/r/base/seq.html'>seq</a></span>(<span class='k'>actions_header_row</span> <span class='o'>+</span> <span class='m'>1</span>, <span class='k'>last_action</span>)
        <span class='k'>monster_actions</span> <span class='o'>&lt;-</span> <span class='k'>lines</span><span class='o'>$</span><span class='k'>value</span>[<span class='k'>action_rows</span>]
        <span class='k'>monster_actions</span> <span class='o'>&lt;-</span> <span class='k'>monster_actions</span> <span class='o'>%&gt;%</span> <span class='k'>purrr</span>::<span class='nf'><a href='https://purrr.tidyverse.org/reference/map.html'>map</a></span>(<span class='nf'>function</span>(<span class='k'>x</span>) {
            <span class='k'>action_name</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/grep.html'>gsub</a></span>(<span class='s'>".*\\*\\*(.*?)\\.\\*\\*.*"</span>, <span class='s'>"\\1"</span>, <span class='k'>x</span>)
            <span class='k'>action</span> <span class='o'>&lt;-</span> <span class='k'>x</span> <span class='o'>%&gt;%</span> <span class='k'>strip_bold_text</span> <span class='o'>%&gt;%</span> <span class='k'>trimws</span>
            <span class='nf'><a href='https://rdrr.io/r/base/names.html'>names</a></span>(<span class='k'>action</span>) <span class='o'>&lt;-</span> <span class='k'>action_name</span>
            <span class='k'>action</span>
        }) <span class='o'>%&gt;%</span> <span class='k'>purrr</span>::<span class='nf'><a href='https://purrr.tidyverse.org/reference/reduce.html'>reduce</a></span>(<span class='k'>c</span>)
    }
<span class='k'>monster_actions</span>
<span class='c'>#&gt;                                                                                                                                 Multiattack </span>
<span class='c'>#&gt; "The medusa makes either three melee attacks--one with its snake hair and two with its shortsword--or two ranged attacks with its longbow." </span>
<span class='c'>#&gt;                                                                                                                                  Snake Hair </span>
<span class='c'>#&gt;                  "Melee Weapon Attack: +5 to hit, reach 5 ft., one creature. Hit: 4 (1d4 + 2) piercing damage plus 14 (4d6) poison damage." </span>
<span class='c'>#&gt;                                                                                                                                  Shortsword </span>
<span class='c'>#&gt;                                                "Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) piercing damage." </span>
<span class='c'>#&gt;                                                                                                                                     Longbow </span>
<span class='c'>#&gt;              "Ranged Weapon Attack: +5 to hit, range 150/600 ft., one target. Hit: 6 (1d8 + 2) piercing damage plus 7 (2d6) poison damage."</span></code></pre>

</div>

Putting it all together
-----------------------

We can now put everything together into a single-row tibble:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='nf'>tibble</span>(
    name = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_colon_heading</span>(<span class='s'>"name"</span>),
    type = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_colon_heading</span>(<span class='s'>"type"</span>),
    cr = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_colon_heading</span>(<span class='s'>"cr"</span>) <span class='o'>%&gt;%</span> <span class='k'>as.numeric</span>,
    xp = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"challenge"</span>) <span class='o'>%&gt;%</span> <span class='k'>extract_bracketed</span> <span class='o'>%&gt;%</span> <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/parse_number.html'>parse_number</a></span>(),
    ac = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Armor Class"</span>) <span class='o'>%&gt;%</span> <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/parse_number.html'>parse_number</a></span>(),
    ac_note = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Armor Class"</span>) <span class='o'>%&gt;%</span> <span class='k'>extract_bracketed</span>,
    hp_avg = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Hit Points"</span>) <span class='o'>%&gt;%</span> <span class='k'>readr</span>::<span class='nf'><a href='https://readr.tidyverse.org/reference/parse_number.html'>parse_number</a></span>(),
    hp = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Hit Points"</span>) <span class='o'>%&gt;%</span> <span class='k'>extract_bracketed</span>,
    str = <span class='k'>monster_ability</span>[<span class='s'>"STR"</span>],
    dex = <span class='k'>monster_ability</span>[<span class='s'>"DEX"</span>],
    con = <span class='k'>monster_ability</span>[<span class='s'>"CON"</span>],
    int = <span class='k'>monster_ability</span>[<span class='s'>"INT"</span>],
    wis = <span class='k'>monster_ability</span>[<span class='s'>"WIS"</span>],
    cha = <span class='k'>monster_ability</span>[<span class='s'>"CHA"</span>],
    senses = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Senses"</span>),
    languages = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Languages"</span>),
    speed = <span class='k'>lines</span> <span class='o'>%&gt;%</span> <span class='nf'>extract_from_bold_text</span>(<span class='s'>"Speed"</span>),
    actions = <span class='k'>monster_actions</span> <span class='o'>%&gt;%</span> <span class='k'>list</span>
    ) <span class='o'>%&gt;%</span> 
    <span class='nf'><a href='https://rdrr.io/r/base/cbind.html'>cbind</a></span>(<span class='nf'>spread</span>(<span class='k'>monster_skills</span>, <span class='k'>skill</span>, <span class='k'>modifier</span>)) <span class='o'>%&gt;%</span> 
    <span class='k'>as_tibble</span>
<span class='c'>#&gt; <span style='color: #949494;'># A tibble: 1 x 36</span></span>
<span class='c'>#&gt;   name  type     cr    xp    ac ac_note hp_avg hp      str   dex   con   int</span>
<span class='c'>#&gt;   <span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span>    </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span> </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span>
<span class='c'>#&gt; <span style='color: #BCBCBC;'>1</span><span> Medu… mons…     6  </span><span style='text-decoration: underline;'>2</span><span>300    15 natura…    127 17d8…    10    15    16    12</span></span>
<span class='c'>#&gt; <span style='color: #949494;'># … with 24 more variables: wis </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, cha </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, senses </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span style='color: #949494;'>,</span></span>
<span class='c'>#&gt; <span style='color: #949494;'>#   languages </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span style='color: #949494;'>, speed </span><span style='color: #949494;font-style: italic;'>&lt;chr&gt;</span><span style='color: #949494;'>, actions </span><span style='color: #949494;font-style: italic;'>&lt;list&gt;</span><span style='color: #949494;'>, acrobatics </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>,</span></span>
<span class='c'>#&gt; <span style='color: #949494;'>#   animal_handling </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, arcana </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, athletics </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, deception </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>,</span></span>
<span class='c'>#&gt; <span style='color: #949494;'>#   history </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, insight </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, intimidation </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, investigation </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>,</span></span>
<span class='c'>#&gt; <span style='color: #949494;'>#   medicine </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, nature </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, perception </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, performance </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>,</span></span>
<span class='c'>#&gt; <span style='color: #949494;'>#   persuasion </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, religion </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, sleight_of_hand </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>, stealth </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span><span style='color: #949494;'>,</span></span>
<span class='c'>#&gt; <span style='color: #949494;'>#   survival </span><span style='color: #949494;font-style: italic;'>&lt;dbl&gt;</span></span></code></pre>

</div>

There are a few more fields that I haven't covered here (size, alignment and description, for example). I've put the full version of the `parse_monster.R` script in a [gist](https://gist.github.com/mdneuzerling/1a70a2da97300c478186aba226053595).

Of course, this is how to parse just one monster. Fortunately, the `purrr` package exists. Here's how to scrape every monster:

1.  Clone [vitusventure's 5th edition SRD repository](https://github.com/vitusventure/5thSRD)
2.  Set the `/docs/gamemaster_rules/monsters` directory to a variable `monster_dir`
3.  Run the following code:

<div class="highlight">

<pre class='chroma'><code class='language-r' data-lang='r'><span class='k'>monsters</span> <span class='o'>&lt;-</span> <span class='nf'><a href='https://rdrr.io/r/base/list.files.html'>list.files</a></span>(<span class='k'>monster_dir</span>, full.names = <span class='kc'>TRUE</span>) <span class='o'>%&gt;%</span> 
    <span class='k'>purrr</span>::<span class='nf'><a href='https://purrr.tidyverse.org/reference/map.html'>map</a></span>(<span class='nf'>function</span>(<span class='k'>x</span>) <span class='nf'><a href='https://rdrr.io/r/base/readChar.html'>readChar</a></span>(<span class='k'>x</span>, <span class='nf'><a href='https://rdrr.io/r/base/file.info.html'>file.info</a></span>(<span class='k'>x</span>)<span class='o'>$</span><span class='k'>size</span>)) <span class='o'>%&gt;%</span> <span class='c'># read files as strings</span>
    <span class='k'>purrr</span>::<span class='nf'><a href='https://purrr.tidyverse.org/reference/map.html'>map</a></span>(<span class='k'>parse_monster</span>) <span class='o'>%&gt;%</span> 
    <span class='k'>purrr</span>::<span class='nf'><a href='https://purrr.tidyverse.org/reference/reduce.html'>reduce</a></span>(<span class='k'>rbind</span>)</code></pre>

</div>

What's next
-----------

A few things are missing here:

-   Damage/condition immunities and resistances are not being scraped.
-   Monster traits, such as the ability to breathe underwater, are not being scraped. I think this is a matter of finding any bold heading that isn't "standard" and treating it as a trait.
-   Some monsters have complicated armor classes. For example, the werewolf has an AC of "11 in humanoid form, 12 (natural armor) in wolf or hybrid form". This doesn't fit the template of `ac` and `ac_note`.

I'd like to incorporate the spells in the SRD, as well as some basic mechanics. Imagine being able to generate an encounter in R according to a specific party level!

Sources
-------

The Medusa and all Dungeons and Dragons 5th edition mechanics are available in the [Systems Reference Document under the Open Gaming License Version 1.0a](https://media.wizards.com/2016/downloads/DND/SRD-OGL_V5.1.pdf). The `monsters` data set in the `monstr` package is available under the same license.

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
<span class='c'>#&gt;  package     * version    date       lib source                              </span>
<span class='c'>#&gt;  assertthat    0.2.1      2019-03-21 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  backports     1.1.7      2020-05-13 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  base64enc     0.1-3      2015-07-28 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  broom         0.5.6      2020-04-20 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  callr         3.4.3      2020-03-28 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  cellranger    1.1.0      2016-07-27 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  cli           2.0.2      2020-02-28 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  colorspace    1.4-1      2019-03-18 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  crayon        1.3.4      2017-09-16 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  DBI           1.1.0      2019-12-15 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  dbplyr        1.4.3      2020-04-19 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  desc          1.2.0      2018-05-01 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  devtools      2.3.0      2020-04-10 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  digest        0.6.25     2020-02-23 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  downlit       0.0.0.9000 2020-06-12 [1] Github (r-lib/downlit@87fb1af)      </span>
<span class='c'>#&gt;  dplyr       * 0.8.5      2020-03-07 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  ellipsis      0.3.1      2020-05-15 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  evaluate      0.14       2019-05-28 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  fansi         0.4.1      2020-01-08 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  farver        2.0.3      2020-01-16 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  forcats     * 0.5.0      2020-03-01 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  fs            1.4.1      2020-04-04 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  generics      0.0.2      2018-11-29 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  ggplot2     * 3.3.0      2020-03-05 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  glue          1.4.1      2020-05-13 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  gtable        0.3.0      2019-03-25 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  haven         2.2.0      2019-11-08 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  highr         0.8        2019-03-20 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  hms           0.5.3      2020-01-08 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  htmltools     0.4.0      2019-10-04 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  httr          1.4.1      2019-08-05 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  hugodown      0.0.0.9000 2020-06-12 [1] Github (r-lib/hugodown@6812ada)     </span>
<span class='c'>#&gt;  jsonlite      1.6.1      2020-02-02 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  knitr         1.28       2020-02-06 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  labeling      0.3        2014-08-23 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  lattice       0.20-41    2020-04-02 [4] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  lifecycle     0.2.0      2020-03-06 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  lubridate     1.7.8      2020-04-06 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  magrittr      1.5        2014-11-22 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  memoise       1.1.0.9000 2020-05-09 [1] Github (hadley/memoise@4aefd9f)     </span>
<span class='c'>#&gt;  modelr        0.1.6      2020-02-22 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  monstr        0.0.0.9000 2020-06-13 [1] Github (mdneuzerling/monstr@dc7e102)</span>
<span class='c'>#&gt;  munsell       0.5.0      2018-06-12 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  nlme          3.1-145    2020-03-04 [4] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  pillar        1.4.4      2020-05-05 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  pkgbuild      1.0.7      2020-04-25 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  pkgconfig     2.0.3      2019-09-22 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  pkgload       1.0.2      2018-10-29 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  prettyunits   1.1.1      2020-01-24 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  processx      3.4.2      2020-02-09 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  ps            1.3.3      2020-05-08 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  purrr       * 0.3.4      2020-04-17 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  R6            2.4.1      2019-11-12 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  Rcpp          1.0.4.6    2020-04-09 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  readr       * 1.3.1      2018-12-21 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  readxl        1.3.1      2019-03-13 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  remotes       2.1.1      2020-02-15 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  repr          1.1.0      2020-01-28 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  reprex        0.3.0      2019-05-16 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  rlang         0.4.6      2020-05-02 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  rmarkdown     2.2.3      2020-06-12 [1] Github (rstudio/rmarkdown@4ee96c8)  </span>
<span class='c'>#&gt;  rprojroot     1.3-2      2018-01-03 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  rstudioapi    0.11       2020-02-07 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  rvest         0.3.5      2019-11-08 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  scales        1.1.0      2019-11-18 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  sessioninfo   1.1.1      2018-11-05 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  skimr         2.1.1      2020-04-16 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  stringi       1.4.6      2020-02-17 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  stringr     * 1.4.0      2019-02-10 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  testthat      2.3.2      2020-03-02 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  tibble      * 3.0.1      2020-04-20 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  tidyr       * 1.0.2      2020-01-24 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  tidyselect    1.0.0      2020-01-27 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  tidyverse   * 1.3.0      2019-11-21 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  usethis       1.6.1      2020-04-29 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  utf8          1.1.4      2018-05-24 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  vctrs         0.3.1      2020-06-05 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  withr         2.2.0      2020-04-20 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  xfun          0.14       2020-05-20 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  xml2          1.3.2      2020-04-23 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt;  yaml          2.2.1      2020-02-01 [1] CRAN (R 4.0.0)                      </span>
<span class='c'>#&gt; </span>
<span class='c'>#&gt; [1] /home/mdneuzerling/R/x86_64-pc-linux-gnu-library/4.0</span>
<span class='c'>#&gt; [2] /usr/local/lib/R/site-library</span>
<span class='c'>#&gt; [3] /usr/lib/R/site-library</span>
<span class='c'>#&gt; [4] /usr/lib/R/library</span></code></pre>

</div>

