# League of Legends Top-Lane Matchup Analysis

## Overview

This project analyzes **League of Legends top-lane matchup data** to build an interpretable champion tier ranking and identify statistically meaningful counter matchups.

The analysis is based on matchup-level data collected from **OP.GG** for **Master+ ranked games**. The project focuses on top lane because it provides a relatively clean setting for champion-versus-champion comparisons, with less dependence on duo-lane synergy and cross-map interaction than some other roles.

The main analysis is implemented in **R**. The web scraper used to collect the OP.GG data is maintained separately in:

`timiddd/OPGG-Scraper`

---

## Research Questions

This project focuses on two main questions:

1. **Can a Bradley–Terry paired-comparison model recover a meaningful tier ranking for League of Legends top-lane champions?**
2. **Can matchup-level data reveal champion-specific counter effects beyond a single overall strength score?**

The goal is not only to produce a ranking, but also to make the reasoning behind the ranking and counter recommendations transparent.

---

## Data

The dataset contains champion-versus-opponent matchup statistics collected from OP.GG.

Each matchup record includes information such as:

- Champion
- Opponent
- Matchup win rate
- Number of games
- Pick-rate-related information

To reduce noise and make champion strength easier to interpret, the analysis is limited to:

- **Top-lane matchups**
- **Master rank and above**

The data collection process is handled by the separate Python scraper repository:

`timiddd/OPGG-Scraper`

This repository focuses on the **statistical analysis and report generation** after the data has been collected.

---

## Methodology

### 1. Bradley–Terry Champion Ranking

The first part of the analysis uses a **Bradley–Terry paired-comparison model**.

The Bradley–Terry model assumes that each champion has an underlying latent strength parameter. When two champions are matched against each other, the probability of one champion winning depends on the relative difference between their estimated strengths.

The fitted strength parameters are then used to rank champions from strongest to weakest.

### 2. Pick-Rate Filtering

The initial Bradley–Terry model produced rankings that were strongly influenced by low-pick-rate champions.

Many niche champions are selected primarily as counter picks, so their observed matchups are not a random sample of opponents. This can make them appear stronger overall than they actually are.

To reduce this selection effect, champions with a pick rate below **2%** are filtered out before fitting the improved ranking model.

### 3. Regularized Bradley–Terry Model

A regularized version of the Bradley–Terry model is used to reduce extreme strength estimates caused by:

- Small matchup sample sizes
- Uneven matchup coverage
- Extreme observed win rates
- Low-pick-rate counter-pick behavior

Regularization produces a more stable ranking and results that align more closely with OP.GG's published top-lane rankings.

### 4. Special Counter Detection

A separate statistical test is used to identify matchup-specific counter effects.

For each champion-opponent pair, the observed matchup win rate is compared with the champion's overall expected performance.

A Z-score-style statistic is used to measure whether the matchup differs significantly from the champion's typical performance while accounting for the number of games played.

Matchups are treated as statistically meaningful when they pass a **95% confidence threshold**.

- Positive deviations indicate an unusually favorable matchup.
- Negative deviations indicate an unusually unfavorable matchup.

This analysis provides an explainable alternative to black-box "weak against" or counter recommendations.

---

## Main Findings

The raw Bradley–Terry model tended to overvalue low-pick-rate champions because these champions are often selected specifically into favorable matchups.

After applying a **2% pick-rate filter** and **regularization**, the resulting champion ranking became much more stable and showed substantial overlap with OP.GG's published top-lane tier list.

The matchup-level hypothesis tests also identified clear champion-specific counter relationships. These results were particularly useful for low-pick-rate champions, whose strategic value often comes from being strong situational counter picks rather than universally strong champions.

Overall, the project shows that relatively simple and interpretable statistical models can provide useful information for both:

- Global champion strength ranking
- Matchup-specific draft and counter-pick decisions

---

## Repository Structure

A typical project structure is:

```text
.
├── README.md
├── SMGT530_Project.R
└── report/
    └── SMGT530_Final.pdf
```

The exact filenames may differ depending on the local version of the project.

The `.R` file is responsible for:

- Loading and cleaning the matchup data
- Fitting the Bradley–Terry models
- Applying filtering and regularization
- Detecting statistically significant counters
- Producing tables and figures used in the final report

The scraper itself is not included in this repository.

---

## Scraper

The OP.GG scraper used to collect the original matchup data is available in a separate GitHub repository:

**Repository:** `timiddd/OPGG-Scraper`

The general workflow is:

```text
OP.GG
  ↓
Python Scraper
  ↓
Matchup Dataset
  ↓
R Analysis
  ↓
Bradley–Terry Ranking + Counter Analysis
  ↓
Figures / Tables / Final Report
```

---

## Running the Analysis

### Requirements

The project requires **R** and the R packages used in the analysis script.

Because package names may depend on the current version of the `.R` file, install any missing packages reported by R before running the analysis.

### Run

From R or RStudio:

```r
source("SMGT530_Project.R")
```

or run the script directly from the command line:

```bash
Rscript SMGT530_Project.R
```

Make sure the required dataset is stored in the path expected by the script before running it.

---

## Outputs

The analysis produces results including:

- Raw Bradley–Terry champion strength estimates
- Regularized champion strength estimates
- Champion tier/ranking visualizations
- Statistically significant champion-opponent counter matchups
- Low-pick-rate counter-pick results

These outputs are used in the accompanying final report.

---

## Limitations

There are several important limitations to this analysis.

First, the Bradley–Terry model compresses each champion into a single global strength parameter. This does not fully represent non-transitive or "rock-paper-scissors" matchup behavior.

Second, matchup observations are not randomly assigned. Players often choose champions after seeing an opponent's pick, creating **selection bias**, especially for niche counter-pick champions.

Third, matchup sample sizes vary substantially. Some champion pairs are supported by many games, while others have much smaller samples.

Finally, OP.GG may use additional information such as pick rate, ban rate, KDA, lane performance, or other gameplay statistics that are not included in the Bradley–Terry model.

For these reasons, this project should be viewed as an **interpretable statistical approach to champion ranking**, rather than a replacement for all existing ranking systems.

---

## Practical Motivation

Many amateur, collegiate, second-tier, or semi-professional teams may not have access to a dedicated analyst or coaching staff.

Instead of relying only on unexplained tier lists or counter recommendations, this project demonstrates how observed matchup data can be converted into:

- An explainable champion tier ranking
- Statistically supported counter recommendations
- Actionable information for champion draft and ban/pick preparation

The emphasis of the project is therefore not only predictive performance, but also **interpretability**.

---

## Report

The full methodology, results, discussion, and interpretation are available in the accompanying final report:

`SMGT530_Final.pdf`

---

## Author

**Jianan Hong**  
Rice University  
SMGT 530
