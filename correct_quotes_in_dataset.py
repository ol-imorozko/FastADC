import re

# Define the input and output file paths
input_file = 'dataset/airport.csv'
output_file = 'corrected_airport.csv'

# Function to fix fields containing unescaped double quotes
def fix_field(field):
    if '"' in field and not field.startswith('"') and not field.endswith('"'):
        # Escape internal double quotes and enclose the entire field in double quotes
        return '"' + field.replace('"', '""') + '"'
    return field

# Open the input and output files
with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'w', encoding='utf-8') as outfile:
    for line in infile:
        # Find the index of the last quoted part
        # This regex finds the part of the string enclosed in quotes at the end of the line
        last_part_match = re.search(r'"[^"]+,[^"]+"$', line)
        
        if last_part_match:
            last_part = last_part_match.group(0)  # Get the quoted last part
            fields_part = line[:last_part_match.start()]  # Get everything before the quoted last part
        else:
            last_part = ''
            fields_part = line.strip()

        # Split the fields part by commas
        fields = fields_part.split(',')

        # Fix each field in the fields part (but not the last part)
        corrected_fields = [fix_field(field) for field in fields]

        # Rejoin the corrected fields part and append the last untouched part (if any)
        corrected_line = ','.join(corrected_fields) + (last_part if last_part else '')

        # Write the corrected line to the output file
        outfile.write(corrected_line + '\n')

print(f"CSV file has been corrected and saved as '{output_file}'.")

