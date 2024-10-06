import FastADC.FastADC;
import de.metanome.algorithms.dcfinder.denialconstraints.DenialConstraintSet;

public class Main {

    public static void main(String[] args) {
        if (args.length == 0) {
            System.out.println("Please provide the path to the CSV file as a command-line argument.");
            return;
        }
        String fp = args[0];
        double threshold = 0.01d;
        int rowLimit = -1; // limit the number of tuples in dataset, -1 means no limit
        int shardLength = 350;
        boolean linear = true; // linear single-thread in EvidenceSetBuilder
        boolean singleColumn = false; // only single-attribute predicates

        FastADC fastADC = new FastADC(singleColumn, threshold, shardLength, linear);
        DenialConstraintSet dcs = fastADC.buildApproxDCs(fp, rowLimit);
        System.out.println("Gathered " + dcs.size() + " denial constraints");
    }

}
