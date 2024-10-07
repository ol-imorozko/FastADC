import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats

# Read the data
df = pd.read_csv('results_memory.csv')

# Calculate peak memory usage per run
peak_memory_usage = df.groupby(['Implementation', 'Dataset', 'Run'])['MemoryUsage'].max().reset_index()

# Function to calculate mean and 95% confidence interval
def mean_ci(data, confidence=0.95):
    n = len(data)
    mean = np.mean(data)
    if n > 1:
        sem = stats.sem(data)
        h = sem * stats.t.ppf((1 + confidence) / 2., n-1)
    else:
        h = 0  # If only one sample, cannot compute confidence interval
    return mean, h

# Prepare data for plotting
implementations = peak_memory_usage['Implementation'].unique()
datasets = peak_memory_usage['Dataset'].unique()

mean_memory = {}
ci_memory = {}

for impl in implementations:
    mean_memory[impl] = []
    ci_memory[impl] = []
    for dataset in datasets:
        data = peak_memory_usage[(peak_memory_usage['Implementation'] == impl) & (peak_memory_usage['Dataset'] == dataset)]['MemoryUsage']
        data /= 1024
        mean, ci = mean_ci(data)
        mean_memory[impl].append(mean)
        ci_memory[impl].append(ci)

# Plotting
x = np.arange(len(datasets))  # Label locations
width = 0.35  # Width of the bars

fig, ax = plt.subplots(figsize=(10, 6))

rects = []
for i, impl in enumerate(implementations):
    offset = (i - 0.5) * width  # Center bars around x
    rect = ax.bar(x + offset, mean_memory[impl], width, yerr=ci_memory[impl], label=impl, capsize=5)
    rects.append(rect)

# Add labels, title, and custom x-axis tick labels
ax.set_ylabel('Память, Мбайт')
ax.set_xticks(x)
ax.set_xticklabels(datasets)
ax.set_yscale('log')
ax.legend()

fig.tight_layout()
plt.savefig('memory_usage.png')
plt.show()
