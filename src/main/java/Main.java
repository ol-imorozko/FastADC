import FastADC.FastADC;
import de.metanome.algorithms.dcfinder.denialconstraints.DenialConstraint;
import de.metanome.algorithms.dcfinder.denialconstraints.DenialConstraintSet;
import java.io.FileWriter;
import java.io.IOException;

public class Main {

    /**
     * Writes denial constraints from the set to a file based on the specified
     * count.
     * Writes all constraints if count is -1.
     * 
     * @param dcSet The set of denial constraints.
     * @param count The number of constraints to write or -1 to write all.
     * @param fp    The file path to write the constraints to, with .csv replaced by
     *              .out.
     */
    public static void printDenialConstraints(DenialConstraintSet dcSet, int count, String fp) {
        int printedCount = 0;
        // Change the file extension from .csv to .out
        String outputPath = fp.replaceAll("\\.csv$", ".out");

        try (FileWriter writer = new FileWriter(outputPath)) {
            for (DenialConstraint dc : dcSet) {
                writer.write(dc.toString() + "\n");
                printedCount++;
                if (count != -1 && printedCount >= count)
                    break;
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void main(String[] args) {
        // String fp = "./dataset/tax.csv";
        String fp = "./dataset/dc_test_dataset.csv";
        //String fp = "./dataset/dc_small.csv";
        // double threshold = 0.01d;
        double threshold = 0.01d;
        int rowLimit = -1;              // limit the number of tuples in dataset, -1 means no limit
        int shardLength = 350;
        boolean linear = true;         // linear single-thread in EvidenceSetBuilder
        boolean singleColumn = false;   // only single-attribute predicates

        FastADC fastADC = new FastADC(singleColumn, threshold, shardLength, linear);
        DenialConstraintSet dcs = fastADC.buildApproxDCs(fp, rowLimit);

        printDenialConstraints(dcs, -1, fp);
        System.out.println();
    }

}
