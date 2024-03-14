package FastADC;

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.List;

import FastADC.aei.ApproxEvidenceInverter;
import FastADC.evidence.EvidenceSetBuilder;
import FastADC.evidence.evidenceSet.EvidenceSet;
import FastADC.plishard.Cluster;
import FastADC.plishard.Pli;
import FastADC.plishard.PliShard;
import FastADC.plishard.PliShardBuilder;
import FastADC.predicate.PredicateBuilder;
import de.metanome.algorithms.dcfinder.denialconstraints.DenialConstraintSet;
import de.metanome.algorithms.dcfinder.input.Input;
import de.metanome.algorithms.dcfinder.input.RelationalInput;

public class FastADC {

    // configures of PredicateBuilder
    private final boolean noCrossColumn;
    private final double minimumSharedValue = 0.3d;
    private final double comparableThreshold = 0.1d;

    // configure of PliShardBuilder
    private final int shardLength;

    // configure of EvidenceSetBuilder
    private final boolean linear;

    // configure of ApproxCoverSearcher
    private final double threshold;


    private String dataFp;
    private Input input;
    private PredicateBuilder predicateBuilder;
    private PliShardBuilder pliShardBuilder;
    private EvidenceSetBuilder evidenceSetBuilder;

     public static void printPliShardsToFile(PliShard[] pliShards, String fp) {
        // Replace the .csv extension with .plishards
        String outputPath = fp.replaceAll("\\.csv$", ".plishards");

        try (BufferedWriter writer = new BufferedWriter(new FileWriter(outputPath))) {
            for (int shardIndex = 0; shardIndex < pliShards.length; shardIndex++) {
                PliShard shard = pliShards[shardIndex];
                writer.write(String.format("PliShard #%d (Range: [%d, %d))\n", shardIndex + 1, shard.beg, shard.end));
                
                List<Pli> plis = shard.plis;
                for (int pliIndex = 0; pliIndex < plis.size(); pliIndex++) {
                    Pli pli = plis.get(pliIndex);
                    writer.write(String.format("\tPLI #%d\n", pliIndex + 1));
                    writer.write("\tKeys: " + arrayToString(pli.getKeys()) + "\n");
                    writer.write("\tClusters:\n");
                    
                    for (Cluster cluster : pli.getClusters()) {
                        writer.write("\t\t" + cluster + "\n");
                    }
                }
                writer.write("\n");
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static String arrayToString(int[] array) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < array.length; i++) {
            if (i > 0) sb.append(", ");
            sb.append(array[i]);
        }
        sb.append("]");
        return sb.toString();
    }

    public FastADC(boolean _noCrossColumn, double _threshold, int _len, boolean _linear) {
        noCrossColumn = _noCrossColumn;
        threshold = _threshold;
        shardLength = _len;
        linear = _linear;
        predicateBuilder = new PredicateBuilder(noCrossColumn, minimumSharedValue, comparableThreshold);
    }

    public DenialConstraintSet buildApproxDCs(String _dataFp, int sizeLimit) {
        dataFp = _dataFp;
        System.out.println("INPUT FILE: " + dataFp);
        System.out.println("ERROR THRESHOLD: " + threshold);

        // Pre-process: load input data, build predicate space and pli shards
        long t00 = System.currentTimeMillis();
        input = new Input(new RelationalInput(dataFp), sizeLimit);
        predicateBuilder.buildPredicateSpace(input);
        pliShardBuilder = new PliShardBuilder(shardLength, input.getParsedColumns());
        PliShard[] pliShards = pliShardBuilder.buildPliShards(input.getIntInput());

        printPliShardsToFile(pliShards, _dataFp);

        long t_pre = System.currentTimeMillis() - t00;
        System.out.println(" [Predicate] Predicate space size: " + predicateBuilder.predicateCount());
        System.out.println("[FastADC] Pre-process time: " + t_pre + "ms");

        // build evidence set
        long t10 = System.currentTimeMillis();
        evidenceSetBuilder = new EvidenceSetBuilder(predicateBuilder);
        EvidenceSet evidenceSet = evidenceSetBuilder.buildEvidenceSet(pliShards, linear);
        long t_evi = System.currentTimeMillis() - t10;
        long eviCount = evidenceSet.getTotalCount();
        System.out.println(" [Evidence] # of evidences: " + evidenceSet.size());
        System.out.println(" [Evidence] Accumulated evidence count: " + evidenceSet.getTotalCount());
        System.out.println("[FastADC] Evidence time: " + t_evi + "ms");

        // approx evidence inversion
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        System.out.println(" [AEI Start] " + sdf.format(System.currentTimeMillis()));
        long t20 = System.currentTimeMillis();
        long aeiTarget = (long) Math.ceil((1 - threshold) * eviCount);
        System.out.println(" [AEI] Violate at most " + (eviCount - aeiTarget) + " tuple pairs");
        ApproxEvidenceInverter evidenceInverter = new ApproxEvidenceInverter(predicateBuilder);
        DenialConstraintSet dcs = evidenceInverter.buildDenialConstraints(evidenceSet, aeiTarget);
        long t_aei = System.currentTimeMillis() - t20;
        System.out.println("[FastADC] AEI time: " + t_aei + "ms");

        System.out.println("[FastADC] Total computing time: " + (t_pre + t_evi + t_aei) + " ms\n");
        return dcs;
    }

}
