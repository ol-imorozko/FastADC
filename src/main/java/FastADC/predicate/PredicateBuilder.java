package FastADC.predicate;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import ch.javasoft.bitset.LongBitSet;
import de.metanome.algorithms.dcfinder.helpers.IndexProvider;
import de.metanome.algorithms.dcfinder.predicates.ColumnPair;
import de.metanome.algorithms.dcfinder.input.Input;
import de.metanome.algorithms.dcfinder.input.ParsedColumn;
import de.metanome.algorithms.dcfinder.predicates.Operator;
import de.metanome.algorithms.dcfinder.predicates.Predicate;
import de.metanome.algorithms.dcfinder.predicates.PredicateProvider;
import de.metanome.algorithms.dcfinder.predicates.operands.ColumnOperand;
import de.metanome.algorithms.dcfinder.predicates.sets.Closure;
import de.metanome.algorithms.dcfinder.predicates.sets.PredicateSet;
import java.io.FileWriter;
import java.io.IOException;

public class PredicateBuilder {

    private final boolean noCrossColumn;
    private final double comparableThreshold;
    private final double minimumSharedValue;

    private final List<Predicate> predicates;
    private final List<List<Predicate>> predicateGroups;    // [i]: predicates of i-th Column Pair

    List<List<Predicate>> numSingleColumnPredicateGroups;
    List<List<Predicate>> numCrossColumnPredicateGroups;
    List<List<Predicate>> strSingleColumnPredicateGroups;
    List<List<Predicate>> strCrossColumnPredicateGroups;

    private final PredicateProvider predicateProvider;
    private final IndexProvider<Predicate> predicateIdProvider;
    private LongBitSet[] mutexMap;   // i -> indices of predicates from the same column pair with predicate i
    private int[] inverseMap;        // i -> index of predicate having inverse op to predicate i

    public PredicateBuilder(boolean _noCrossColumn, double _minimumSharedValue, double _comparableThreshold) {
        noCrossColumn = _noCrossColumn;
        minimumSharedValue = _minimumSharedValue;
        comparableThreshold = _comparableThreshold;
        predicates = new ArrayList<>();
        predicateGroups = new ArrayList<>();
        predicateProvider = new PredicateProvider();
        predicateIdProvider = new IndexProvider<>();
    }

    public static void printpredicates(List<Predicate> predicates) {
        String outputPath = "predicates.out";

        try (FileWriter writer = new FileWriter(outputPath)) {
            for (Predicate p : predicates) {
                writer.write(p.toString() + "\n");
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void PrintGroup(FileWriter writer, List<List<Predicate>> group, String group_name) throws IOException {
        writer.write(group_name + ":\n");

        for (List<Predicate> plist : group) {
            for (Predicate p : plist) {
                writer.write(p.toString() + "\n");
            }
        }

        writer.write("\n");
    }

    public void PrintPredicateGroups() {
        String outputPath = "predicate_groups.out";

        try (FileWriter writer = new FileWriter(outputPath)) {
            PrintGroup(writer, numSingleColumnPredicateGroups, "SingleColumnPredicateGroup");
            PrintGroup(writer, numCrossColumnPredicateGroups, "CrossColumnPredicateGroup");
            PrintGroup(writer, strSingleColumnPredicateGroups, "SingleColumnPredicateGroup");
            PrintGroup(writer, strCrossColumnPredicateGroups, "CrossColumnPredicateGroup");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void buildPredicateSpace(Input input) {
        List<ColumnPair> columnPairs = constructColumnPairs(input);

        for (ColumnPair pair : columnPairs) {
            ColumnOperand<?> o1 = new ColumnOperand<>(pair.getC1(), 0);
            addPredicates(o1, new ColumnOperand<>(pair.getC2(), 1), pair.isComparable());
        }
        predicateIdProvider.addAll(predicates);

        printpredicates(predicates);

        Predicate.configure(predicateProvider);
        Closure.configure(predicateProvider);
        PredicateSet.configure(predicateIdProvider);

        buildPredicateGroups();
        PrintPredicateGroups();

        buildMutexMap();
        buildInverseMap();
    }

    public void buildMutexMap() {
        mutexMap = new LongBitSet[predicates.size()];
        for (Predicate p1 : predicates) {
            LongBitSet mutex = new LongBitSet();
            for (Predicate p2 : predicates) {
                if (p1.getOperand1().equals(p2.getOperand1()) && p1.getOperand2().equals(p2.getOperand2()))
                    mutex.set(predicateIdProvider.getIndex(p2));
            }
            mutexMap[predicateIdProvider.getIndex(p1)] = mutex;
        }
    }

    public void buildInverseMap() {
        inverseMap = new int[predicateIdProvider.size()];
        for (var r : predicateIdProvider.entrySet())
            inverseMap[r.getValue()] = predicateIdProvider.getIndex(r.getKey().getInverse());
    }

    public int predicateCount() {
        return predicates.size();
    }

    public LongBitSet[] getMutexMap() {
        return mutexMap;
    }

    public PredicateSet getInverse(LongBitSet predicateSet) {
        LongBitSet inverse = new LongBitSet();
        for (int l = predicateSet.nextSetBit(0); l >= 0; l = predicateSet.nextSetBit(l + 1))
            inverse.set(inverseMap[l]);
        return new PredicateSet(inverse);
    }

    public List<List<Predicate>> getPredicateGroupsNumericalSingleColumn() {
        return numSingleColumnPredicateGroups;
    }

    public List<List<Predicate>> getPredicateGroupsNumericalCrossColumn() {
        return numCrossColumnPredicateGroups;
    }

    public List<List<Predicate>> getPredicateGroupsCategoricalSingleColumn() {
        return strSingleColumnPredicateGroups;
    }

    public List<List<Predicate>> getStrCrossColumnPredicateGroups() {
        return strCrossColumnPredicateGroups;
    }

    public Predicate getPredicateByType(Collection<Predicate> predicateGroup, Operator type) {
        Predicate pwithtype = null;
        for (Predicate p : predicateGroup) {
            if (p.getOperator().equals(type)) {
                pwithtype = p;
                break;
            }
        }
        return pwithtype;
    }

    private ArrayList<ColumnPair> constructColumnPairs(Input input) {
        ArrayList<ColumnPair> pairs = new ArrayList<>();
        for (int i = 0; i < input.getColumns().length; ++i) {
            ParsedColumn<?> c1 = input.getColumns()[i];
            for (int j = i; j < input.getColumns().length; ++j) {
                ParsedColumn<?> c2 = input.getColumns()[j];
                boolean joinable = isJoinable(c1, c2);
                boolean comparable = isComparable(c1, c2);
                if (joinable || comparable) {
                //System.out.println("Current column pair {" + c1.toString() + ", " + c2.toString() + "} is " + (!joinable ? "not " : "") + "joinable and " + (!comparable ? "not " : "") + "comparable");
                    pairs.add(new ColumnPair(c1, c2, true, comparable));
                } else {
                //System.out.println("Skipping column pair {" + c1.toString() + ", " + c2.toString() + "}");
                }
            }
        }
        return pairs;
    }

    /**
     * Can form a predicate within {==, !=}
     */
    private boolean isJoinable(ParsedColumn<?> c1, ParsedColumn<?> c2) {
        if (noCrossColumn)
            return c1.equals(c2);

        if (!c1.getType().equals(c2.getType()))
            return false;

        return c1.getSharedPercentage(c2) > minimumSharedValue;
    }

    /**
     * Can form a predicate within {==, !=, <, <=, >, >=}
     */
    private boolean isComparable(ParsedColumn<?> c1, ParsedColumn<?> c2) {
        if (noCrossColumn)
            return c1.equals(c2) && (c1.getType().equals(Double.class) || c1.getType().equals(Long.class));

        if (!c1.getType().equals(c2.getType()))
            return false;

        if (c1.getType().equals(Double.class) || c1.getType().equals(Long.class)) {
            if (c1.equals(c2))
                return true;

            double avg1 = c1.getAverage();
            double avg2 = c2.getAverage();
            return Math.min(avg1, avg2) / Math.max(avg1, avg2) > comparableThreshold;
        }
        return false;
    }

    private void addPredicates(ColumnOperand<?> o1, ColumnOperand<?> o2, boolean comparable) {
        List<Predicate> partialPredicates = new ArrayList<>();
        for (Operator op : Operator.values()) {
            if (op == Operator.EQUAL || op == Operator.UNEQUAL) {
                partialPredicates.add(predicateProvider.getPredicate(op, o1, o2));
            } else if (comparable) {
                partialPredicates.add(predicateProvider.getPredicate(op, o1, o2));
            }
        }

        predicates.addAll(partialPredicates);
        // not needed, do not use.
        predicateGroups.add(new ArrayList<>(partialPredicates));
    }

    private void buildPredicateGroups() {
        numSingleColumnPredicateGroups = new ArrayList<>();
        numCrossColumnPredicateGroups = new ArrayList<>();
        strSingleColumnPredicateGroups = new ArrayList<>();
        strCrossColumnPredicateGroups = new ArrayList<>();

        for (List<Predicate> predicateGroup : predicateGroups) {
            // numeric: comparable, all 6 predicates
            if (predicateGroup.size() == 6) {
                if (predicateGroup.iterator().next().isCrossColumn())
                    numCrossColumnPredicateGroups.add(predicateGroup);
                else
                    numSingleColumnPredicateGroups.add(predicateGroup);
            }
            // string: joinable but non-comparable, only 2 predicates
            if (predicateGroup.size() == 2) {
                if (predicateGroup.iterator().next().isCrossColumn())
                    strCrossColumnPredicateGroups.add(predicateGroup);
                else
                    strSingleColumnPredicateGroups.add(predicateGroup);
            }
        }
    }



}
