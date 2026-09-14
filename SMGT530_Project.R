library(dplyr)
library(tidyr)
library(broom)
library(ggplot2)
library(BradleyTerry2)

data <- read.csv("/Users/jiananhong/PycharmProjects/pythonProject/Scraper/match_up.csv", stringsAsFactors = FALSE)


data$games <- as.numeric(gsub(",", "", data$games))
data$win_rate <- as.numeric(sub("%", "", data$win_rate)) / 100
# Drop rows where `games` is NA
data <- data[!is.na(data$games), ]

data$win  <- round(data$win_rate * data$games)
data$loss <- data$games - data$win
data$diff <- data$win - data$loss
data$winner <- ifelse(data$diff > 0, data$champion,
                      ifelse(data$diff < 0, data$opponent, data$champion))


data_simple <- read.csv("/Users/jiananhong/PycharmProjects/pythonProject/Scraper/match_up_deduped.csv", stringsAsFactors = FALSE)
data_simple$games    <- as.numeric(gsub(",", "", data_simple$games))
data_simple$win_rate <- as.numeric(sub("%", "", data_simple$win_rate)) / 100
# Drop rows where `games` is NA
data_simple <- data_simple[!is.na(data_simple$games), ]

# Compute win / loss / diff
data_simple$win  <- round(data_simple$win_rate * data_simple$games)
data_simple$loss <- data_simple$games - data_simple$win
data_simple$diff <- data_simple$win - data_simple$loss
data_simple$winner <- ifelse(data_simple$diff > 0, data_simple$champion,
                      ifelse(data_simple$diff < 0, data_simple$opponent, data_simple$champion))

data_1 <- data_simple %>%
  mutate(diff_signed = if_else(winner == champion, diff, -diff))

teams <- sort(unique(c(data_1$champion, data_1$opponent)))

H <- model.matrix(~ 0 + factor(champion, levels = teams), data = data_1)  # champion indicators
A <- model.matrix(~ 0 + factor(opponent, levels = teams), data = data_1)  # opponent indicators
X <- H - A
colnames(X) <- teams

# 3) Identifiability: drop one team (reference) and fit with NO intercept
ref_team <- teams[1]
team_cols <- setdiff(teams, ref_team)
team_data <- X[, team_cols, drop = FALSE] 

df_model <- cbind(diff_signed = data_1$diff_signed, as.data.frame(team_data))

fit <- lm(diff_signed ~ . - 1, data = df_model)
print(summary(fit))
#### Visualization

coefs_0 <- coef(fit)
coefs_ranked_0 <- sort(coefs_0, decreasing = TRUE)
coefs_ranked_0

top20_0 <- head(coefs_ranked_0, 20)
top20_0
barplot(
  top20_0,
  las = 2,
  col = "lightblue",
  border = "darkblue",
  main = "Top 20 Champion Coefficients",
  xlab = "",
  ylab = "Coefficient"
)
abline(h = 0, col = "red")



# Notes:
# - With very few games, estimates won’t be meaningful; you’ll want many rows across champions.

# filter here for glm over 200?


# special counter? outlier?


# k means classificaion;

selected_data <- data %>% select(champion, opponent, win, loss, diff, winner)
head(selected_data)



selected_data <- selected_data %>%
  filter(champion != opponent)


all_champs <- sort(unique(c(selected_data$champion,
                            selected_data$opponent)))

selected_data <- selected_data %>%
  mutate(
    champion = factor(champion, levels = all_champs),
    opponent = factor(opponent, levels = all_champs)
  )

# --- 3. Fit Bradley–Terry model ---

bt_model <- BTm(
  outcome = cbind(win, loss), 
  player1 = champion,
  player2 = opponent,
  data    = selected_data,
  id      = "champion"
)

summary(bt_model)


abilities <- BTabilities(bt_model)

# Turn into a nice data frame and rank
abilities_df <- as.data.frame(abilities)
abilities_df$champion <- rownames(abilities_df)

abilities_ranked <- abilities_df %>%
  arrange(desc(ability))

abilities_ranked <- abilities_ranked %>%
  mutate(champion = as.factor(champion))

ggplot(abilities_ranked,
       aes(x = reorder(champion, ability), y = ability)) +
  geom_col() +                        # bar heights = ability
  coord_flip() +                      # flip so names are readable
  labs(
    title = "Champion Strength",
    x = "Champion",
    y = "Coefficient (theta)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.y = element_text(size = 7)  # shrink text if many champs
  )


exp(-0.2198)/(1+exp(-0.2198))


# implement regression to the mean
# sum up each champ total games then filter small samples(threshold pick rate > 1%); create id column for each champion
# make like champ: ambessa vs. aatrox win=true; loss=false
# then build lme4::lmer func to championid





# Then K-mean, choosing related columns


## ---------------------------------------------------------
## 1) Filter out champions with lane_pick_rate < 1%
## ---------------------------------------------------------

# make lane_pick_rate numeric in [0,1]
data$lane_pick_rate_num <- as.numeric(sub("%", "", data$lane_pick_rate)) / 100

# keep only champs whose lane_pick_rate >= 1%
high_pick_champs <- data %>%
  group_by(champion) %>%
  summarise(lane_pick_rate = first(lane_pick_rate_num), .groups = "drop") %>%
  filter(!is.na(lane_pick_rate), lane_pick_rate >= 0.02) %>%
  pull(champion)

# filter matchups so BOTH sides are high-pick champs
selected_data_hp <- data %>%
  filter(champion %in% high_pick_champs,
         opponent %in% high_pick_champs,
         champion != opponent) %>%          # no self-matchups
  select(champion, opponent, win, loss, diff, winner)

# shared factor levels for BT design
all_champs_hp <- sort(unique(c(selected_data_hp$champion,
                               selected_data_hp$opponent)))

selected_data_hp <- selected_data_hp %>%
  mutate(
    champion = factor(champion, levels = all_champs_hp),
    opponent = factor(opponent, levels = all_champs_hp)
  )

## ---------------------------------------------------------
## 2) Ridge-regularized Bradley–Terry via glmnet (L2)
## ---------------------------------------------------------
# install.packages("glmnet")
library(glmnet)

players <- all_champs_hp

# design matrix: +1 for champion, -1 for opponent
X_bt <- sapply(players, function(p) {
  as.integer(selected_data_hp$champion == p) -
    as.integer(selected_data_hp$opponent == p)
})

# choose a reference champion (ability = 0)
ref_player <- players[1]
X_bt <- X_bt[, players != ref_player, drop = FALSE]
colnames(X_bt) <- players[players != ref_player]

# aggregated binomial response: wins vs losses for "champion"
y_bt <- with(selected_data_hp, cbind(win, loss))

# ridge (L2) BT model
cv_ridge <- cv.glmnet(
  x         = X_bt,
  y         = y_bt,
  family    = "binomial",
  alpha     = 0,         # 0 = ridge
  intercept = FALSE
)

# coefficients at 1-SE lambda (more shrinkage)
coef_ridge <- coef(cv_ridge, s = "lambda.1se")

# turn sparse matrix into named numeric vector (no intercept)
coef_vec <- as.numeric(coef_ridge)
names(coef_vec) <- rownames(coef_ridge)
coef_vec <- coef_vec[names(coef_vec) != "(Intercept)"]

# rebuild full ability vector including reference champ (set to 0)
abilities_ridge <- numeric(length(players))
names(abilities_ridge) <- players
abilities_ridge[ref_player] <- 0
abilities_ridge[names(coef_vec)] <- coef_vec

# nice data frame of shrunken champion strengths
abilities_ridge_df <- data.frame(
  champion = players,
  ability  = abilities_ridge
) %>%
  arrange(desc(ability))

head(abilities_ridge_df, 10)

## (Optional) quick visualization of top 20 shrunken thetas
top20_ridge <- head(abilities_ridge_df, 20)
top20_ridge <- abilities_ridge_df
ggplot(top20_ridge,
       aes(x = reorder(champion, ability), y = ability)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Top 20 Champion Strengths (Ridge-regularized BT)",
    x = "Champion",
    y = "Coefficient (theta, shrunken)"
  ) +
  theme_minimal(base_size = 12)

exp(0.008)/(1+exp(0.001))












## ---------------------------------------------------------
## Lighter shrinkage: use lambda.min instead of lambda.1se
## ---------------------------------------------------------

# Compare the two lambdas (just to see how different they are)
cv_ridge$lambda.1se
cv_ridge$lambda.min

# 1) Get coefficients at lambda.min (weaker penalty)
coef_ridge_light <- coef(cv_ridge, s = "lambda.min")

# Turn sparse coef vector into named numeric (drop intercept)
coef_vec_light <- as.numeric(coef_ridge_light)
names(coef_vec_light) <- rownames(coef_ridge_light)
coef_vec_light <- coef_vec_light[names(coef_vec_light) != "(Intercept)"]

# 2) Rebuild full ability vector including the reference champion
abilities_ridge_light <- numeric(length(players))
names(abilities_ridge_light) <- players
abilities_ridge_light[ref_player] <- 0
abilities_ridge_light[names(coef_vec_light)] <- coef_vec_light

# 3) Put into a data frame and rank
abilities_ridge_light_df <- data.frame(
  champion = players,
  ability  = abilities_ridge_light
) %>%
  arrange(desc(ability))

# Check the range of thetas now
range(abilities_ridge_light_df$ability)

# 4) Visualize (top 20, lighter shrinkage)
top20_ridge_light <- head(abilities_ridge_light_df, 20)
top20_ridge_light <- abilities_ridge_light_df
ggplot(top20_ridge_light,
       aes(x = reorder(champion, ability), y = ability)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Champion Strengths (with regularization)",
    x = "Champion",
    y = "Coefficient (theta)"
  ) +
  theme_minimal(base_size = 12)


exp(0.09)/(1+exp(0.09))



# k means
## =========================================================
## 1. Prepare numeric features for clustering (row = matchup)
##    starting from your current `data`
## =========================================================

library(dplyr)
library(tidyr)
library(ggplot2)

# `data` already has numeric: games, win_rate (0–1)
data_clust <- data %>%
  mutate(
    # % → numeric in [0,1]
    lane_kill_rate_num     = as.numeric(sub("%", "", lane_kill_rate)) / 100,
    kill_participation_num = as.numeric(sub("%", "", kill_participation)) / 100,
    lane_win_rate_num      = as.numeric(sub("%", "", lane_win_rate)) / 100,
    lane_pick_rate_num     = as.numeric(sub("%", "", lane_pick_rate)) / 100,
    ban_rate_num           = as.numeric(sub("%", "", ban_rate)) / 100,
    # KDA like "1.95 : 1" → 1.95
    kda_num                = as.numeric(sub("[: ].*$", "", kda)),
    # damage_to_champions like "24,339" → 24339
    damage_to_champions_num = as.numeric(gsub(",", "", damage_to_champions)),
    # clean first_tower_kill like 16'34"
    ft_raw                 = gsub('"', "", first_tower_kill)
  ) %>%
  separate(ft_raw, into = c("ft_min", "ft_sec"), sep = "'", fill = "right", remove = TRUE) %>%
  mutate(
    ft_min  = suppressWarnings(as.numeric(ft_min)),
    ft_sec  = suppressWarnings(as.numeric(ft_sec)),
    first_tower_kill_sec = ft_min * 60 + ft_sec
  )

## =========================================================
## 2. Aggregate to champion-level features
## =========================================================

champ_features <- data_clust %>%
  group_by(champion) %>%
  summarise(
    total_games         = sum(games, na.rm = TRUE),
    win_rate            = weighted.mean(win_rate, games, na.rm = TRUE),
    lane_kill_rate      = weighted.mean(lane_kill_rate_num, games, na.rm = TRUE),
    kda                 = weighted.mean(kda_num, games, na.rm = TRUE),
    kill_participation  = weighted.mean(kill_participation_num, games, na.rm = TRUE),
    damage_to_champions = weighted.mean(damage_to_champions_num, games, na.rm = TRUE),
    first_tower_kill_sec= weighted.mean(first_tower_kill_sec, games, na.rm = TRUE),
    lane_win_rate       = weighted.mean(lane_win_rate_num, games, na.rm = TRUE),
    lane_pick_rate      = max(lane_pick_rate_num, na.rm = TRUE),
    ban_rate            = max(ban_rate_num, na.rm = TRUE),
    .groups = "drop"
  )

# (Optional) drop very low-sample champs before clustering
champ_features <- champ_features %>%
  filter(total_games >= 200)   # pick a threshold you like

## =========================================================
## 3. Run k-means clustering on standardized features
## =========================================================

# choose the numeric columns to cluster on
feat_mat <- champ_features %>%
  select(win_rate, lane_kill_rate, kda, kill_participation,
         damage_to_champions, first_tower_kill_sec,
         lane_win_rate, lane_pick_rate, ban_rate) %>%
  as.matrix()

# scale features (0 mean, unit variance)
feat_scaled <- scale(feat_mat)

set.seed(123)          # for reproducibility
k <- 7                 # number of clusters (try 3–6 and compare)
km_fit <- kmeans(feat_scaled, centers = k, nstart = 25)

# attach cluster labels back to champions
champ_clusters <- champ_features %>%
  mutate(cluster = factor(km_fit$cluster))

# see which champions are together
champ_clusters %>%
  arrange(cluster, desc(win_rate)) %>%
  select(champion, cluster, total_games, win_rate, lane_pick_rate, ban_rate) %>%
  head(30)

## =========================================================
## 4. Simple 2D visualization (PCA + clusters)
## =========================================================

pca <- prcomp(feat_scaled, center = TRUE, scale. = FALSE)

plot_df <- data.frame(
  champion = champ_clusters$champion,
  PC1      = pca$x[, 1],
  PC2      = pca$x[, 2],
  cluster  = champ_clusters$cluster
)

ggplot(plot_df, aes(x = PC1, y = PC2, colour = cluster, label = champion)) +
  geom_point(size = 2) +
  geom_text(size = 3, vjust = -0.6, show.legend = FALSE) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Champion clusters (k-means on lane stats)",
    x = "PC1",
    y = "PC2",
    colour = "Cluster"
  )





# special counter
library(dplyr)

## 0) Make sure lane_pick_rate is numeric in [0, 1]
data$lane_pick_rate_num <- as.numeric(sub("%", "", data$lane_pick_rate)) / 100

## 1) Champion-level baseline win rate (null model)

champ_baseline <- data %>%
  group_by(champion) %>%
  summarise(
    champ_games   = sum(games, na.rm = TRUE),
    champ_wins    = sum(win,   na.rm = TRUE),
    champ_wr      = champ_wins / champ_games,           # baseline win rate
    lane_pick_rate_champ = max(lane_pick_rate_num, na.rm = TRUE),
    .groups = "drop"
  )

## 2) Attach baseline to each matchup row

matchups <- data %>%
  left_join(champ_baseline,
            by = "champion") %>%
  mutate(
    n_games   = games,
    p_obs     = win_rate,        # observed matchup win rate (already 0–1)
    p_exp     = champ_wr,        # expected from champion's overall WR
    se        = sqrt(p_exp * (1 - p_exp) / n_games),
    z_score   = (p_obs - p_exp) / se,
    p_value   = 2 * pnorm(-abs(z_score))   # two-sided
  )

## 3) Focus on LOW-pick champions (< 2% lane pick rate)

low_pick_threshold <- 0.02
min_games          <- 20     # you can raise this to be stricter
z_thresh           <- 2.0    # ~5% two-sided; use 2.5 or 3 for more strict

low_pick_matchups_stats <- matchups %>%
  filter(
    lane_pick_rate_champ < low_pick_threshold,
    n_games >= min_games
  )

## 4) "Special counters": rare champ that OVER-performs its baseline

special_counters_strong <- low_pick_matchups_stats %>%
  filter(z_score >= z_thresh) %>%
  arrange(desc(z_score)) %>%
  select(
    champion, opponent, n_games, 
    p_obs, p_exp, z_score, p_value,
    lane_pick_rate = lane_pick_rate_champ
  )

## 5) (Optional) rare champs that get DESTROYED by someone

special_counters_weak <- low_pick_matchups_stats %>%
  filter(z_score <= -z_thresh) %>%
  arrange(z_score) %>%
  select(
    champion, opponent, n_games, 
    p_obs, p_exp, z_score, p_value,
    lane_pick_rate = lane_pick_rate_champ
  )

# Take a look:
head(special_counters_strong, 20)
head(special_counters_weak, 20)
