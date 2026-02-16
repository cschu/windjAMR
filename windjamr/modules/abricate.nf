process abricate {
	container "quay.io/biocontainers/abricate:1.2.0--h05cac1d_0"
	memory {32.GB * task.attempt}
	time {8.h * task.attempt}

	input:
	tuple val(genome), path(fasta),	val(db)

	output:
	tuple val(genome), path("${genome}/abricate/${genome}.${db}.abricate.tsv"), val(db), emit: results

	script:
	"""
	mkdir -p ${genome}/abricate/
	abricate --db ${db} ${fasta} > ${genome}/abricate/${genome}.${db}.abricate.tsv
	"""

}

// singularity exec \
//         --bind /g/scb/bork/data/spire:/mnt/spire,\
// /g/bork6/dickinson/argnorm_prep/test_sample:/mnt/work \
//         $CONTAINER \
//         abricate --db $DB \
//         /mnt/spire/studies/909/psa_megahit/assemblies/SAMEA112496619_METAG_H5WNWDSXC.SW051-2-assembled.fa.gz \
//         > $OUTDIR/${SAMPLE_ID}.${DB}.abricate.tsv


// for DB in card
// do
//     echo "[ABRicate] Running $DB"

//     singularity exec \
//         --bind /g/scb/bork/data/spire:/mnt/spire,\
// /g/bork6/dickinson/argnorm_prep/test_sample:/mnt/work \
//         $CONTAINER \
//         abricate --db $DB \
//         /mnt/spire/studies/909/psa_megahit/assemblies/SAMEA112496619_METAG_H5WNWDSXC.SW051-2-assembled.fa.gz \
//         > $OUTDIR/${SAMPLE_ID}.${DB}.abricate.tsv
// done
