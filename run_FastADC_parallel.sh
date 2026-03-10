#!/bin/bash

set -euo pipefail

NUM_RUNS=1
DATASETS=("Airport.csv" "Atom.csv" "Food.csv" "SPStock.csv" "Neighbors.csv")
JARS="/home/imorozko/maga/FastADC/target/classes:/home/imorozko/.m2/repository/net/sourceforge/javacsv/javacsv/2.0/javacsv-2.0.jar:/home/imorozko/.m2/repository/net/mintern/primitive/1.3/primitive-1.3.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-impl-jdk8/1.0.0/koloboke-impl-jdk8-1.0.0.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-impl-common-jdk8/1.0.0/koloboke-impl-common-jdk8-1.0.0.jar:/home/imorozko/.m2/repository/com/koloboke/koloboke-api-jdk8/1.0.0/koloboke-api-jdk8-1.0.0.jar"
JAVA_DIR="/home/imorozko/maga/FastADC"
DESBORDANTE_DIR="/home/imorozko/maga/Desbordante/build/target"
RESULTS_FILE="$(pwd)/results_parallel.csv"

# Modes:
#   both   - run HT-off and HT-on
#   ht-off - only SMT off, 1 thread per P-core
#   ht-on  - only SMT on, all logical CPUs on P-cores
MODE="${MODE:-both}"

cpu_list_to_csv() {
  local cpus=("$@")
  local out=""
  for c in "${cpus[@]}"; do
    if [ -z "$out" ]; then
      out="$c"
    else
      out+=",$c"
    fi
  done
  echo "$out"
}

# Count how many logical CPUs are listed in a kernel CPU list string like:
#   0,1
#   2-3
#   0-3,8,10-11
count_cpu_list_items() {
  local s="$1"
  local count=0
  IFS=',' read -ra parts <<< "$s"
  for part in "${parts[@]}"; do
    if [[ "$part" == *-* ]]; then
      local start=${part%-*}
      local end=${part#*-}
      count=$((count + end - start + 1))
    else
      count=$((count + 1))
    fi
  done
  echo "$count"
}

# Return first CPU from a kernel CPU list string
first_cpu_in_list() {
  local s="$1"
  local first_part=${s%%,*}
  if [[ "$first_part" == *-* ]]; then
    echo "${first_part%-*}"
  else
    echo "$first_part"
  fi
}

# Detect P-core logical CPUs and one representative logical CPU per P-core.
# On your CPU:
#   P-core => thread_siblings_list has 2 logical CPUs
#   E-core => thread_siblings_list has 1 logical CPU
detect_pcores_from_siblings() {
  declare -A seen_groups=()
  declare -a pcore_all=()
  declare -a pcore_representatives=()

  for p in /sys/devices/system/cpu/cpu[0-9]*; do
    local cpu
    cpu=$(basename "$p" | sed 's/cpu//')

    [ -f "$p/online" ] && [ "$(cat "$p/online")" = "0" ] && continue

    local sib
    sib=$(cat "$p/topology/thread_siblings_list")
    local cnt
    cnt=$(count_cpu_list_items "$sib")

    # P-core has 2 siblings on Alder Lake / 12800H
    if [ "$cnt" -eq 2 ]; then
      pcore_all+=("$cpu")

      if [ -z "${seen_groups[$sib]+x}" ]; then
        seen_groups["$sib"]=1
        pcore_representatives+=("$(first_cpu_in_list "$sib")")
      fi
    fi
  done

  echo "ALL:${pcore_all[*]}"
  echo "REP:${pcore_representatives[*]}"
}

set_smt() {
  local state="$1"   # on/off
  if [ ! -f /sys/devices/system/cpu/smt/control ]; then
    echo "[SCRIPT] ERROR: /sys/devices/system/cpu/smt/control not found."
    echo "[SCRIPT] Cannot control SMT/Hyper-Threading from this script."
    exit 1
  fi

  echo "[SCRIPT] Setting SMT to '$state'"
  echo "$state" | sudo tee /sys/devices/system/cpu/smt/control >/dev/null
}

get_smt_state() {
  if [ -f /sys/devices/system/cpu/smt/control ]; then
    cat /sys/devices/system/cpu/smt/control
  else
    echo "unknown"
  fi
}

set_fixed_frequency() {
  local cpuset="$1"
  echo "[SCRIPT] Setting CPU frequency governor=performance for CPUs: $cpuset"

  local first_cpu
  first_cpu=$(echo "$cpuset" | cut -d',' -f1)

  local max_freq
  max_freq=$(cpupower -c "$first_cpu" frequency-info | grep -m 1 'hardware limits' | awk '{print $6$7}')

  sudo cpupower -c "$cpuset" frequency-set -g performance -d "$max_freq" -u "$max_freq"
}

reset_frequency() {
  local cpuset="$1"
  echo "[SCRIPT] Resetting CPU governor=powersave for CPUs: $cpuset"
  sudo cpupower -c "$cpuset" frequency-set -g powersave || true
}

run_one_config() {
  local config_name="$1"   # HT_OFF or HT_ON
  local smt_state="$2"     # off/on
  local threads="$3"
  local cpus_raw="$4"

  read -ra cpus <<< "$cpus_raw"
  local cpuset_taskset
  cpuset_taskset=$(cpu_list_to_csv "${cpus[@]}")

  echo
  echo "[SCRIPT] =========================================================="
  echo "[SCRIPT] Running config: $config_name"
  echo "[SCRIPT] SMT state     : $smt_state"
  echo "[SCRIPT] Threads       : $threads"
  echo "[SCRIPT] CPU set       : $cpuset_taskset"
  echo "[SCRIPT] =========================================================="
  echo

  set_smt "$smt_state"
  set_fixed_frequency "$cpuset_taskset"

  for dataset in "${DATASETS[@]}"; do
    dataset_name=$(basename "$dataset" .csv)
    echo "[SCRIPT] Processing dataset $dataset_name ($config_name)"

    for ((i=1; i<=NUM_RUNS; i++)); do
      echo "[SCRIPT] Run $i for Java on dataset $dataset_name ($config_name)"

      sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
      sudo swapoff -a

      cd "$JAVA_DIR"
      java_cmd=(
        java
        -XX:ActiveProcessorCount="$threads"
        -Djava.util.concurrent.ForkJoinPool.common.parallelism="$threads"
        -cp "$JARS"
        Main
        "./dataset/$dataset"
      )

      output=$(taskset -c "$cpuset_taskset" "${java_cmd[@]}" 2>&1)

      evidence_time=$(echo "$output" | grep "\[Java\] Evidence time:" | awk '{print $4}' | tr -d 'ms')
      aei_time=$(echo "$output" | grep "\[Java\] AEI time:" | awk '{print $4}' | tr -d 'ms')
      total_time=$(echo "$output" | grep "\[Java\] Total computing time:" | awk '{print $5}' | tr -d 'ms')

      echo "$config_name,Java,$dataset_name,$i,$threads,$cpuset_taskset,$evidence_time,$aei_time,$total_time" >> "$RESULTS_FILE"

      sudo swapon -a
    done

    for ((i=1; i<=NUM_RUNS; i++)); do
      echo "[SCRIPT] Run $i for Desbordante on dataset $dataset_name ($config_name)"

      sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
      sudo swapoff -a

      cd "$DESBORDANTE_DIR"
      desbordante_cmd=(./Desbordante_test "--gtest_filter=FastADCTest.$dataset_name")
      output=$(taskset -c "$cpuset_taskset" env THREADS="$threads" "${desbordante_cmd[@]}" 2>&1)

      evidence_time=$(echo "$output" | grep "\[Desbordante\] Evidence time:" | awk '{print $4}' | tr -d 'ms.')
      aei_time=$(echo "$output" | grep "\[Desbordante\] AEI time:" | awk '{print $4}' | tr -d 'ms')
      total_time=$(echo "$output" | grep "\[Desbordante\] Total computing time:" | awk '{print $5}' | tr -d 'ms')

      echo "$config_name,Desbordante,$dataset_name,$i,$threads,$cpuset_taskset,$evidence_time,$aei_time,$total_time" >> "$RESULTS_FILE"

      sudo swapon -a
    done
  done

  reset_frequency "$cpuset_taskset"
}

main() {
  local original_smt
  original_smt=$(get_smt_state)
  echo "[SCRIPT] Original SMT state: $original_smt"

  trap '
    echo "[SCRIPT] Restoring SMT state: '"$original_smt"'"
    if [ -f /sys/devices/system/cpu/smt/control ]; then
      echo '"$original_smt"' | sudo tee /sys/devices/system/cpu/smt/control >/dev/null || true
    fi
  ' EXIT

  mapfile -t detected < <(detect_pcores_from_siblings)
  local all_line="${detected[0]}"
  local rep_line="${detected[1]}"

  local pcore_all="${all_line#ALL:}"
  local pcore_rep="${rep_line#REP:}"

  echo "[SCRIPT] P-core logical CPUs      : $pcore_all"
  echo "[SCRIPT] P-core representatives   : $pcore_rep"

  echo "Config,Implementation,Dataset,Run,Threads,CPUSet,EvidenceTime(ms),AEITime(ms),TotalTime(ms)" > "$RESULTS_FILE"

  local ht_off_threads
  ht_off_threads=$(echo "$pcore_rep" | wc -w | tr -d ' ')
  local ht_on_threads
  ht_on_threads=$(echo "$pcore_all" | wc -w | tr -d ' ')

  case "$MODE" in
    ht-off)
      run_one_config "HT_OFF" "off" "$ht_off_threads" "$pcore_rep"
      ;;
    ht-on)
      run_one_config "HT_ON" "on" "$ht_on_threads" "$pcore_all"
      ;;
    both)
      run_one_config "HT_OFF" "off" "$ht_off_threads" "$pcore_rep"
      run_one_config "HT_ON" "on" "$ht_on_threads" "$pcore_all"
      ;;
    *)
      echo "[SCRIPT] Unknown MODE='$MODE'. Use: ht-off | ht-on | both"
      exit 1
      ;;
  esac

  echo "[SCRIPT] All tests completed. Results: $RESULTS_FILE"
}

main
