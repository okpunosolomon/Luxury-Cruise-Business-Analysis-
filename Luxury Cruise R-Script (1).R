##########################################
#    Luxury Cruise Business Analysis    #
#  Data Cleaning, Visualization & KPI   #
##########################################

### -----------------------------###
### Load Necessary Libraries  ###
### -----------------------------###

library(readxl)    # For reading Excel files
library(dplyr)     # For data manipulation
library(ggplot2)   # For visualization
library(tidyr)     # For handling missing values
library(gridExtra) # For dashboard layout
library(reshape2)  # For data transformation
library(grid)      # For graphical layout elements
library(psych)     # For psychometric analysis and descriptive statistics

### ------------------------------###
### Load and Inspect Dataset ###
### ------------------------------###

# Set working directory in accordance to your system folder 
setwd("C:/Users/HP/Desktop/DDM")

# Load excel datasets from system folder  
agent_data <- read_excel("agent_36.xlsx")
cruise_info <- read_excel("cruise_01.xlsx")

# Display initial structure of both dataset
str(agent_info)
str(cruise_info)

### ------------------------------###
### Data Cleaning & Preprocessing  ###
### ------------------------------###

# Check for missing values for cruise dataset
cat("Missing values per column in Cruise Data before removal:\n")
print(colSums(is.na(cruise_info)))

# Check for missing values for agent dataset
cat("\nMissing values per column in Agent Data before removal:\n")
print(colSums(is.na(agent_info)))

# Remove rows with missing values in both datasets
cruise_info_cleaned <- na.omit(cruise_info)
agent_info_cleaned <- na.omit(agent_info)

# Confirm missing values removal in both datasets
cat("\nMissing values per column in Cruise Data after removal:\n")
print(colSums(is.na(cruise_info_cleaned)))

cat("\nMissing values per column in Agent Data after removal:\n")
print(colSums(is.na(agent_info_cleaned)))

### ------------------------------###
### Standardizing Data Values      ###
### ------------------------------###

####### Ensure valid values cruise dataset #######
## Function to clean the cruise dataset
cruise_info_cleaned <- cruise_info_cleaned %>%
  filter(promotions %in% c("yes", "no"),          # Remove invalid values from promotions column (valid values: Yes/No)
         return %in% c("yes", "no", "notsure"),   # Remove invalid values from return column (valid values: Yes/No/notsure)
         compensation >= 0,                       # Remove rows with negative compensation values
         cruise_score >= 1 & cruise_score <= 10,  # Remove rows with invalid cruise scores (valid range: 1-10)
         complaint_reason != "ri")                # Drop rows where Complaint Reason is 'ri'

### Processing Month Column from Numeric to Categorical
# Round 'month' column to the nearest integer
cruise_info_cleaned$month <- round(cruise_info_cleaned$month)

# Keep only valid month values (1-12)
cruise_info_cleaned <- cruise_info_cleaned %>% filter(month >= 1 & month <= 12)

# Convert numeric month to month names
month_mapping <- c("January", "February", "March", "April", "May", "June", 
                   "July", "August", "September", "October", "November", "December")

cruise_info_cleaned$month <- factor(cruise_info_cleaned$month, levels = 1:12, labels = month_mapping)

# Display dataset information/structure
str(cruise_info_cleaned)

###### Clean agent dataset ######
## Clean Training Column
# Task: "n" is removed and "don't know" is recoded to "unsure"
agent_info_cleaned <- agent_info_cleaned %>% filter(training != "n")
agent_info_cleaned <- agent_info_cleaned %>% mutate(training = ifelse(training == "don't know", "unsure", training))

## Clean Gender Column
# Task: Valid values are male/female, remove "unknown/don't want to say"
agent_info_cleaned <- agent_info_cleaned %>% filter(!gender %in% c("unknown", "unknown/ don't want to say"))

## Clean Job Type Column
# Task: Valid values are part-time/zero-hour/full-time, remove "p" and "z"
agent_info_cleaned <- agent_info_cleaned %>% filter(!jobtype %in% c("p", "z"))

### Outlier Removal using IQR Method  ###
# Function to remove outliers using IQR
remove_outliers <- function(df, columns) {
  for (col in columns) {
    Q1 <- quantile(df[[col]], 0.25, na.rm = TRUE)
    Q3 <- quantile(df[[col]], 0.75, na.rm = TRUE)
    IQR <- Q3 - Q1
    lower_bound <- Q1 - 1.5 * IQR
    upper_bound <- Q3 + 1.5 * IQR
    df <- df %>% filter(df[[col]] >= lower_bound & df[[col]] <= upper_bound)
  }
  return(df)
}

# Apply outlier removal function to both dataset (continuous variables)
cols_to_clean <- c("cruise_score", "compensation", "commission", "marketing")
cruise_info_cleaned <- remove_outliers(cruise_info_cleaned, cols_to_clean)
agent_info_cleaned <- remove_outliers(agent_info_cleaned, "experience")

# Boxplot for Experience Column After Cleaning to confirm outlier removal
ggplot(agent_info_cleaned, aes(y = experience)) +
  geom_boxplot(fill = "lightgreen", color = "black") +
  labs(title = "Boxplot of Experience (Cleaned)", y = "Experience (Years)") +
  theme_minimal()

### Merge Cleaned Datasets on agent_id    ###
merged_data <- merge(cruise_info_cleaned, agent_info_cleaned, by = "agent_id", all.x = TRUE)

## Select Key Variables
selected_columns <- c("agent_id", "experience", "training", "jobtype", "qualification", "gender", 
                      "cruise_score", "complaint_reason", "compensation", "marketing", "commission", 
                      "return","month", "promotions")

#### To remove any possible NA resulting from Merging datasets
merged_data <- merged_data %>% select(all_of(selected_columns)) %>% na.omit()

# Display First Few Rows and Structure after merging
head(merged_data, 10)
str(merged_data)

######## Summary Statistics ########

# Descriptive Statistics Table
summary(merged_data)

# Select relevant numerical columns for descriptive statistics
numeric_data <- merged_data %>% select(cruise_score, compensation, marketing, commission)

# Generate descriptive statistics using describe()
descriptive_stats <- describe(numeric_data)

# Print the result
print(descriptive_stats)

# save the descriptive statistics table as a CSV file
write.csv(descriptive_stats, "Descriptive_Statistics.csv", row.names = TRUE)

### ------------------------------###
### Visualizations                 ###
### ------------------------------###

####### Visualization of Dataset Distribution and Categorical Variables Counts #####
#### Histogram for Numerical Variables (Shows distribution of the dataset)
numeric_columns <- c("cruise_score", "compensation", "marketing", "commission")
par(mfrow=c(2,2))  # Set layout for multiple histograms
for (col in numeric_columns) {
  hist(merged_data[[col]], main=paste("Histogram of", col), xlab=col, col="green", border="black")
}
par(mfrow=c(1,1))

##### Bar Plots for Categorical Variables Count
categorical_columns_1 <- c("training", "jobtype", "qualification", "gender")
categorical_columns_2 <- c("return", "promotions", "complaint_reason","month")

# First sheet: categorical_columns_1 plots in a grid
par(mfrow=c(2,2))
for (col in categorical_columns_1) {
  barplot(table(merged_data[[col]]), main=paste("Count of", col), col="green", las=2)
}
par(mfrow=c(1,1))

# Second sheet: categorical_columns_2 plots in a grid
par(mfrow=c(2,2))
for (col in categorical_columns_2) {
  barplot(table(merged_data[[col]]), main=paste("Count of", col), col="lightgreen", las=2)
}
par(mfrow=c(1,1))

####### Custom theme for subsequent visualizations ########
theme_custom <- theme_minimal() +
  theme(plot.title = element_text(hjust=0.5, face="bold", size=10),
        axis.title = element_text(face="bold"),
        axis.text = element_text(size=10),
        plot.margin = margin(10, 15, 10, 10))

# ---------------------------------------------------------- #
# Stacked Bar Chart: Complaint Reasons vs Return Likelihood
# --------------------------------------------------------- #
## Highlights which complaints are causing customer churn.
## Will help in prioritizing service improvements.

# Aggregate data: Group by return likelihood and complaint reason
# Calculate the average compensation given for each category
complaint_return_summary <- merged_data %>%
  group_by(return, complaint_reason) %>%
  summarise(avg_compensation = mean(compensation, na.rm=TRUE), .groups='drop')

# Create stacked bar chart
complaint_return_barplot <- ggplot(complaint_return_summary, aes(x=complaint_reason, y=avg_compensation, fill=return)) +
  geom_bar(stat="identity", position="stack") +
  geom_text(aes(label=round(avg_compensation, 2)), position=position_stack(vjust=0.5), size=4, color="black") +
  scale_fill_manual(values=c("red", "orange", "green")) +
  labs(title="Complaint Reasons vs. Return Likelihood",
       x="Complaint Reason", y="Average Compensation (£)", fill="Return Likelihood") +
  theme_custom +
  theme(axis.text.x = element_text(angle=40, hjust=1))

# Display the plot
complaint_return_barplot

# save the Stacked Bar Chart: Complaint Reasons vs Return Likelihood
ggsave("Complaint_Reasons_vs_Return_Likelihood.png", plot = complaint_return_barplot, width = 12, height = 6, dpi = 300, bg = "white")

# -------------------------------------------- #
# Stacked Bar Chart: Return Likelihood by Agent Job Type
# -------------------------------------------- #
# This visualization examines how different agent job types influence 
# customer retention. Insights from this analysis can help optimize 
# staffing decisions and adjust agent commission structures.

# Aggregate data: Count occurrences of each return likelihood per job type
return_by_jobtype <- merged_data %>%
  count(jobtype, return)

# Create stacked bar chart
agent_return_barplot <- ggplot(return_by_jobtype, aes(x=jobtype, y=n, fill=return)) +
  geom_bar(stat="identity", position="stack") +
  scale_fill_manual(values=c("red", "orange", "green")) +
  labs(title="Customer Return Likelihood by Agent Job Type", x="Job Type", y="Count") +
  theme_custom

# Display the plot
agent_return_barplot

# save the stacked bar chart: Customer Return Likelihood by Agent Job Type
ggsave("Return_Likelihood_by_JobType.png", plot = agent_return_barplot, width = 10, height = 6, dpi = 300, bg = "white")

# -------------------------------------------- #
# Bar Chart: Promotions vs Return Likelihood
# -------------------------------------------- #
# This visualization examines whether promotional offers influence 
# customer retention and repeat purchases.
# Insights from this analysis will help optimize future promotional strategies.

# Aggregate data: Count occurrences of return likelihood across different promotion statuses
promotion_impact_summary <- merged_data %>%
  count(return, promotions)

# Create bar chart
promotion_effect_barplot <- ggplot(promotion_impact_summary, aes(x=return, y=n, fill=promotions)) +
  geom_bar(stat="identity", position="dodge") +
  geom_text(aes(label=n), position=position_dodge(width=0.9), vjust=-0.25, size=2.5) +
  scale_fill_manual(values=c("red", "green")) +
  labs(title="Impact of Promotions on Customer Retention", x="Return Likelihood", y="Count", fill="Promotions") +
  theme_custom

# Display the plot
promotion_effect_barplot

# save the Promotions vs Return Likelihood bar chart as png
ggsave("Promotions_vs_Return_Likelihood.png", plot = promotion_effect_barplot, width = 10, height = 6, dpi = 300, bg = "white")

# ------------------------------------------------------ #
# Bar Chart of Key Performance Indicators (KPI) Overview
# ------------------------------------------------------ #
# This visualization provides an overview of key performance indicators (KPIs), 
# helping to assess overall business performance in critical areas.
# Understanding these metrics supports data-driven decision-making.

# Aggregate data: Calculate average values for key performance indicators
kpi_summary <- merged_data %>%
  summarise(
    cruise_score = mean(cruise_score, na.rm=TRUE),
    commission = mean(commission, na.rm=TRUE),
    marketing = mean(marketing, na.rm=TRUE),
    compensation = mean(compensation, na.rm=TRUE)
  ) %>%
  melt()

# Create KPI bar chart
kpi_barplot <- ggplot(kpi_summary, aes(x=variable, y=value, fill=variable)) +
  geom_bar(stat="identity", show.legend=TRUE) +  #Show legend
  geom_text(aes(label=round(value, 2)), vjust=-0.25, size=2.2, fontface="bold") +
  scale_fill_manual(values=c("red", "blue", "orange", "green"), 
                    name="KPI Metrics",  #Add legend title
                    labels=c("Cruise Score", "Commission", "Marketing", "Compensation")) +  #Add meaningful legend labels
  labs(title="Key Performance Indicators", x="KPI Metrics", y="Average Value") +
  theme_custom +
  theme(legend.position="right")  #Position legend on the right

# Display the plot
kpi_barplot

# save KPI Key Metrics Bar Chart as png
ggsave("key_performance_indicators.png", plot = kpi_barplot + theme(plot.background = element_rect(fill = "white")), width = 12, height = 8, dpi = 600, bg = "white")

### ADDITIONAL PLOTS ###
## NOTE: The two plots below are not added to the performance dashboard because they do not portray any strateic business insight

### Boxplot: Compensation Amount vs. Return Likelihood 
# This visualization examines how compensation amounts vary across different 
# levels of return likelihood. It helps identify trends in compensation 
# strategies and their impact on customer retention.

# Create boxplot for compensation distribution across return likelihood categories
compensation_return_boxplot <- ggplot(merged_data, aes(x=return, y=compensation, fill=return)) +
  geom_boxplot() +
  scale_fill_manual(values=c("red", "orange", "green")) +
  labs(title="Compensation and Its Effect on Customer Retention", x="Return Likelihood", y="Compensation Amount (£)") +
  theme_custom

# Display the plot
compensation_return_boxplot

### Line Chart: Cruise Satisfaction Trend Across Months Plot
# This visualization tracks cruise satisfaction trends over time, 
# helping to identify seasonal patterns and potential areas for improvement.

# Aggregate data: Calculate the average cruise score for each month
monthly_satisfaction_trend <- merged_data %>%
  group_by(month) %>%
  summarise(avg_cruise_score = mean(cruise_score, na.rm = TRUE), .groups = 'drop')

cruise_satisfaction_trend_plot <- ggplot(monthly_satisfaction_trend, aes(x = month, y = avg_cruise_score, group = 1)) +
  geom_line(color = "green", linewidth = 1) +  #Fixed: Changed `size` to `linewidth`
  geom_point(color = "black", size = 2) +
  scale_y_continuous(limits = c(min(monthly_satisfaction_trend$avg_cruise_score), 8.0)) +
  labs(title = "Cruise Satisfaction Trend Across Months",
       x = "Month", y = "Average Cruise Score") +
  theme_custom

# Display the plot
cruise_satisfaction_trend_plot

# save the Boxplot: Compensation Amount vs. Return Likelihood 
ggsave("Compensation_vs_Return_Likelihood.png", plot = cruise_satisfaction_trend_plot, width = 10, height = 6, dpi = 300, bg = "white")

# ------------------------------------------------------- #
# Arrange Final Performance Dashboard Layout of Key Plots
# ------------------------------------------------------ #

layout_matrix <- rbind(
  c(1, 2),  # Row 1: agent_return_barplot and promotion_effect_barplot
  c(3, 4)  # Row 2: complaint_return_barplot and kpi_barplot
)

 grid.arrange(agent_return_barplot, promotion_effect_barplot, complaint_return_barplot, kpi_barplot,  layout_matrix = layout_matrix,
             top = textGrob("Luxury Cruise Business Performance Dashboard", gp = gpar(fontsize = 20, fontface = "bold")))

# -------------------------------------------- #
# Save Final Dashboard as Image
# -------------------------------------------- #
 ggsave("Luxury_Cruise_Dashboard.png", plot = grid.arrange(agent_return_barplot, promotion_effect_barplot, complaint_return_barplot, kpi_barplot, layout_matrix = layout_matrix, top = textGrob("Luxury Cruise Business Performance Dashboard", gp = gpar(fontsize = 20, fontface = "bold"))), width = 16, height = 10, dpi = 300, bg = "white")
 



