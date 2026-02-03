import re

def read_file(filename):
    """Reads the content of the given file."""
    with open(filename, 'r') as file:
        return file.read()

def sort_clue_set(content):
    """Sorts the entries in each clue set block by the key."""
    # Split the content into blocks: "Partial clue set" and "Final clue set"
    blocks = re.split(r"(?=Final|Partial)", content)
    
    sorted_blocks = []
    
    for block in blocks:
        lines = block.splitlines()
        
        # Separate header (non-key lines) and key lines
        non_key_lines = [line for line in lines if "Key" not in line]
        key_lines = [line for line in lines if "Key" in line]
        
        # Sort key lines by the numeric value after "Key:"
        sorted_key_lines = sorted(key_lines, key=lambda x: int(re.search(r"\d+", x).group()))
        
        # Combine non-key lines and sorted key lines
        sorted_block = "\n".join(non_key_lines + sorted_key_lines)
        sorted_blocks.append(sorted_block)
    
    return "\n".join(sorted_blocks)

def write_output(filename, content):
    """Writes the sorted content to a new file."""
    with open(filename, 'w') as file:
        file.write(content)

if __name__ == "__main__":
    # Input and output file names
    input_filename = "clue_set.out"
    output_filename = "sorted_clue_set.out"
    
    # Read the file content
    file_content = read_file(input_filename)
    
    # Sort the clue set by key
    sorted_content = sort_clue_set(file_content)
    
    # Write the sorted content to a new file
    write_output(output_filename, sorted_content)
    
    print(f"Sorted content written to {output_filename}")

