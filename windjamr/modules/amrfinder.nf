process amrfinder {
	container "quay.io/biocontainers/ncbi-amrfinderplus:4.0.23--hf69ffd2_0"
	cpus 4
	time {1.d * task.attempt}
	memory {64.GB * task.attempt}

	input:
	tuple val(genome), path(fasta)
	path(db)

	output:
	tuple val(genome), path("${genome}/amrfinder/${genome}.tsv"), emit: results

	script:
	"""
	mkdir -p ${genome}/amrfinder/ tmp/
	export TMPDIR=\$PWD/tmp
	echo \$TMPDIR
	amrfinder --threads ${task.cpus} -n ${fasta} --database ${db} -o ${genome}/amrfinder/${genome}.tsv

	rm -rf tmp/
	"""

}

// # Run AMRFinderPlus
// singularity exec \
//   --bind ${HOST_WORKDIR}:/mnt,\
// /g/bork6/dickinson/argnorm_prep/containers/AMRFinder_DB/2025-07-16.1:/mnt/amrfinder_db,\
// ${TEMP_DIR}:/tmp \
//   --env TMPDIR=/tmp \
//   /g/bork6/dickinson/argnorm_prep/containers/ncbi-amrfinderplus_4.0.23--hf69ffd2_0.sif \
//   amrfinder \
//     -n /mnt/${INPUT_FASTA} \
//     --database /mnt/amrfinder_db \
//     -o /mnt/amrfinder_output_gene/${PREFIX}.amrfinder.gene.tsv

// singularity exec \
//   --bind ${HOST_WORKDIR}:/mnt,\
// /g/bork6/dickinson/argnorm_prep/containers/AMRFinder_DB/2025-07-16.1:/mnt/amrfinder_db,\
// ${TEMP_DIR}:/tmp \
//   --env TMPDIR=/tmp \
//   /g/bork6/dickinson/argnorm_prep/containers/ncbi-amrfinderplus_4.0.23--hf69ffd2_0.sif \
//   amrfinder \
//     --nucleotide /mnt/${INPUT_FASTA} \
//     --database /mnt/amrfinder_db \
//     -o /mnt/amrfinder_output/${PREFIX}.amrfinder.tsv
