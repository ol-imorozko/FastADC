import pandas as pd
import re

# Load your CSV file into a DataFrame
df = pd.read_csv('dataset/airport.csv', dtype=str)  # Load all columns as strings

# Define a pattern to match fields with unquoted double quotes
double_quote_pattern = re.compile(r'[^"]"[^"]')

# Initialize an empty list to store rows and columns with issues
problematic_fields = []

# Iterate over each cell in the DataFrame
for row_index, row in df.iterrows():
    for col_index, cell in row.items():
        # Check if the cell contains unquoted double quotes
        if pd.notna(cell) and double_quote_pattern.search(cell):
            problematic_fields.append((row_index, col_index, cell))

# Display results
if problematic_fields:
    print(f"Found {len(problematic_fields)} problematic fields with unquoted double quotes:")
    for row_index, col_name, cell_value in problematic_fields:
        print(f"Row {row_index}, Column '{col_name}': {cell_value}")
else:
    print("No problematic fields found.")
