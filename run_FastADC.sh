#!/bin/bash

# Variables
NUM_RUNS=6
DATASETS=("Airport.csv" "Atom.csv" "Food.csv" "SPStock.csv" "Neighbors.csv")
# NUM_RUNS=3
# DATASETS=("Airport.csv" "Neighbors.csv")
JARS="/home/imorozko/maga/FastADC/target/classes:/home/imorozko/.m2/repository/net/sourceforge/javacsv/javacsv/2.0/javacsv-2.0.jar:/home/imorozko/.m2/repository/net/mintern/primitive/1.3/primitive-1.3.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-impl-jdk8/1.0.0/koloboke-impl-jdk8-1.0.0.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-impl-common-jdk8/1.0.0/koloboke-impl-common-jdk8-1.0.0.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-api-jdk8/1.0.0/koloboke-api-jdk8-1.0.0.jar"
JAVA_DIR="/home/imorozko/maga/FastADC"
DESBORDANTE_DIR="/home/imorozko/maga/Desbordante/build/target"
RESULTS_FILE="$(pwd)/results.csv"
CORE=0  # The core to bind processes to and to set frequencies for

# Initialize results.csv file with header
echo "Implementation,Dataset,Run,EvidenceTime(ms),AEITime(ms),TotalTime(ms)" > $RESULTS_FILE

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

if [[ "$current_min_freq" == "$max_freq" ]] && [[ "$current_max_freq" == "$max_freq" ]]; then
    echo "SUCCESS: CPU frequency is set to $max_freq kHz on core $CORE"
else
    echo "ERROR: Failed to set CPU frequency on core $CORE"
    exit 1
fi

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

        # Run Java algorithm, binding to the specified core
        cd "$JAVA_DIR"
        java_cmd="java -cp $JARS Main ./dataset/$dataset"
        output=$(taskset -c $CORE $java_cmd 2>&1)

        # Extract times from output
        evidence_time=$(echo "$output" | grep "\[Java\] Evidence time:" | awk '{print $4}' | tr -d 'ms')
        aei_time=$(echo "$output" | grep "\[Java\] AEI time:" | awk '{print $4}' | tr -d 'ms')
        total_time=$(echo "$output" | grep "\[Java\] Total computing time:" | awk '{print $5}' | tr -d 'ms')

        # Write to results.csv
        echo "Java,$dataset_name,$i,$evidence_time,$aei_time,$total_time" >> $RESULTS_FILE

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

        # Run Desbordante algorithm, binding to the specified core
        cd "$DESBORDANTE_DIR"
        desbordante_cmd="./Desbordante_test --gtest_filter=FastADCTest.$dataset_name"
        output=$(taskset -c $CORE $desbordante_cmd 2>&1)

        # Extract times from output
        evidence_time=$(echo "$output" | grep "\[Desbordante\] Evidence time:" | awk '{print $4}' | tr -d 'ms.')
        aei_time=$(echo "$output" | grep "\[Desbordante\] AEI time:" | awk '{print $4}' | tr -d 'ms')
        total_time=$(echo "$output" | grep "\[Desbordante\] Total computing time:" | awk '{print $5}' | tr -d 'ms')

        # Write to results.csv
        echo "Desbordante,$dataset_name,$i,$evidence_time,$aei_time,$total_time" >> $RESULTS_FILE

        # Re-enable swap
        sudo swapon -a
    done
done

# Reset CPU frequency to original settings
echo 'Resetting CPU frequency to original settings...'
sudo cpupower -c $CORE frequency-set -g powersave -d $min_freq -u $max_freq

echo 'All tests completed.'

