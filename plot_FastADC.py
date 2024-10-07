import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats

# Read in the data
df = pd.read_csv('results.csv')

# List of datasets
datasets = df['Dataset'].unique()

# List of implementations
implementations = df['Implementation'].unique()

# Metrics to process
metrics = ['EvidenceTime(ms)', 'AEITime(ms)', 'TotalTime(ms)']

# Prepare data structures to hold the means and confidence intervals
mean_times = {metric: {impl: [] for impl in implementations} for metric in metrics}
ci_times = {metric: {impl: [] for impl in implementations} for metric in metrics}

# Calculate means and 95% confidence intervals
for metric in metrics:
    for dataset in datasets:
        for impl in implementations:
            # Filter data for this dataset and implementation
            data = df[(df['Dataset'] == dataset) & (df['Implementation'] == impl)][metric]
            n = len(data)
            mean = data.mean()
            std_err = stats.sem(data)
            h = std_err * stats.t.ppf((1 + 0.95) / 2., n-1) if n > 1 else 0
            # Append to the lists
            mean_times[metric][impl].append(mean)
            ci_times[metric][impl].append(h)

# Now, for each metric, plot the bar chart
x = np.arange(len(datasets))  # the label locations
total_width = 0.8  # Total width for all bars at one x location
num_bars = len(implementations)
bar_width = total_width / num_bars

for metric in metrics:
    fig, ax = plt.subplots(figsize=(10, 6))
    for i, impl in enumerate(implementations):
        means = mean_times[metric][impl]
        cis = ci_times[metric][impl]
        # Positions: adjust x positions to have the bars side by side
        positions = x - (total_width - bar_width) / 2 + i * bar_width
        ax.bar(positions, means, bar_width, yerr=cis, capsize=5, label=impl)
    # Add labels and title
    ax.set_ylabel('Time (ms)')
    ax.set_title(f'{metric[:-4]} by Dataset and Implementation')
    ax.set_xticks(x)
    ax.set_xticklabels(datasets)
    ax.set_yscale('log')
    ax.legend()

    plt.xticks(rotation=45)
    plt.tight_layout()
    # Save the figure as PNG
    plt.savefig(f'{metric[:-4]}.png')
    plt.show()

