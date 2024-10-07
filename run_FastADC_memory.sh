#!/bin/bash

# Variables
NUM_RUNS=1
DATASETS=("Airport.csv" "Atom.csv" "Food.csv" "SPStock.csv" "Neighbors.csv")
JARS="/home/imorozko/maga/FastADC/target/classes:/home/imorozko/.m2/repository/net/sourceforge/javacsv/javacsv/2.0/javacsv-2.0.jar:/home/imorozko/.m2/repository/net/mintern/primitive/1.3/primitive-1.3.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-impl-jdk8/1.0.0/koloboke-impl-jdk8-1.0.0.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-impl-common-jdk8/1.0.0/koloboke-impl-common-jdk8-1.0.0.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-api-jdk8/1.0.0/koloboke-api-jdk8-1.0.0.jar"
JAVA_DIR="/home/imorozko/maga/FastADC"
DESBORDANTE_DIR="/home/imorozko/maga/Desbordante/build/target"
RESULTS_FILE="$(pwd)/results_memory.csv"
CORE=0  # The core to bind processes to and to set frequencies for

# Initialize results_memory.csv file with header
echo "Implementation,Dataset,Run,TimeFactor,MemoryUsage" > $RESULTS_FILE

# Set CPU frequency to maximum performance mode
echo 'Setting CPU frequency to maximum performance mode...'

# Get maximum and minimum frequencies for the specified core
max_freq=$(cpupower -c $CORE frequency-info | grep -m 1 'hardware limits' | awk '{print $6}' | tr -d '[:alpha:]')
min_freq=$(cpupower -c $CORE frequency-info | grep -m 1 'hardware limits' | awk '{print $3}' | tr -d '[:alpha:]')

# Set CPU frequency to max for the specified core
sudo cpupower -c $CORE frequency-set -g performance -d $max_freq -u $max_freq

# Get maximum and minimum frequencies for the specified core
max_freq=$(cpupower -c $CORE frequency-info | grep -m 1 'hardware limits' | awk '{print $6$7}')
min_freq=$(cpupower -c $CORE frequency-info | grep -m 1 'hardware limits' | awk '{print $3$4}')

# Set CPU frequency to max for the specified core
sudo cpupower -c $CORE frequency-set -g performance -d $max_freq -u $max_freq

# Verify CPU frequency settings for the specified core
echo "Verifying CPU frequency settings for core $CORE..."
current_policy=$(cpupower -c $CORE frequency-info | grep 'current policy')
current_min_freq=$(echo $current_policy | awk '{print $7}')
current_max_freq=$(echo $current_policy | awk '{print $10}')

current_max_freq="${current_max_freq}GHz"
current_min_freq="${current_min_freq}GHz"

# Loop over datasets
for dataset in "${DATASETS[@]}"; do
    dataset_name=$(basename "$dataset" .csv)
    echo "Processing dataset $dataset_name"

    # Run Java algorithm
    for ((i=1; i<=NUM_RUNS; i++)); do
        echo "Run $i for Java on dataset $dataset_name"

        # Clear caches
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        # Disable swap
        sudo swapoff -a

        # Change to Java directory
        cd "$JAVA_DIR"

        # Build the java command
        java_cmd="java -cp $JARS Main ./dataset/$dataset"

        # Run Java algorithm, binding to the specified core, in background
        taskset -c $CORE $java_cmd &
        PID=$!

        # Initialize time factor
        time_factor=1

        # While process is running, measure memory usage every 100ms
        while kill -0 $PID 2>/dev/null; do
            # Get memory usage in KB
            mem_usage=$(ps -o rss= -p $PID)
            # Write to results_memory.csv
            echo "Java,$dataset_name,$i,$time_factor,$mem_usage" >> $RESULTS_FILE
            # Sleep for 100ms
            sleep 0.1
            # Increment time factor
            ((time_factor++))
        done

        # Re-enable swap
        sudo swapon -a
    done

    # Run Desbordante algorithm
    for ((i=1; i<=NUM_RUNS; i++)); do
        echo "Run $i for Desbordante on dataset $dataset_name"

        # Clear caches
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        # Disable swap
        sudo swapoff -a

        # Change to Desbordante directory
        cd "$DESBORDANTE_DIR"

        # Build the command
        desbordante_cmd="./Desbordante_test --gtest_filter=FastADCTest.$dataset_name"

        # Run Desbordante algorithm, binding to the specified core, in background
        taskset -c $CORE $desbordante_cmd &
        PID=$!

        # Initialize time factor
        time_factor=1

        # While process is running, measure memory usage every 100ms
        while kill -0 $PID 2>/dev/null; do
            # Get memory usage in KB
            mem_usage=$(ps -o rss= -p $PID)
            # Write to results_memory.csv
            echo "Desbordante,$dataset_name,$i,$time_factor,$mem_usage" >> $RESULTS_FILE
            # Sleep for 100ms
            sleep 0.1
            # Increment time factor
            ((time_factor++))
        done

        # Re-enable swap
        sudo swapon -a
    done
done

# Reset CPU frequency to original settings
echo 'Resetting CPU frequency to original settings...'
sudo cpupower -c $CORE frequency-set -g powersave -d $min_freq -u $max_freq

echo 'All tests completed.'
