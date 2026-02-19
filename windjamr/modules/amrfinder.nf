process amrfinder {
	container "quay.io/biocontainers/ncbi-amrfinderplus:4.0.23--hf69ffd2_0"
	publishDir "${params.output_dir}", mode: "copy"
	cpus 4
	time {1.d * task.attempt}
	memory {64.GB * task.attempt}
	tag "${genome}"

	input:
	tuple val(genome), path(fasta)
	path(db)
	val(input_type)

	output:
	tuple val(genome), path("${genome}/amrfinder/${genome}.tsv"), emit: results

	script:
	"""
	mkdir -p ${genome}/amrfinder/ tmp/
	export TMPDIR=\$PWD/tmp
	echo \$TMPDIR
	amrfinder --threads ${task.cpus} --${input_type} ${fasta} --database ${db} -o ${genome}/amrfinder/${genome}.tsv

	rm -rf tmp/
	"""

}

process postprocess_amrfinder {
	tag "${genome}"
	memory {4.GB * task.attempt}
	time {30.min * task.attempt}

	input:
	tuple val(genome), path(fasta), path(amrfinder_results)

	output:
	tuple val(genome), path("${genome}.amrfinder.coordinates.tsv"), emit: results

	script:
	"""
	if [[ "${fasta}" == *".gz" ]]; then
		gzip -dc ${fasta} > proteins.faa
	else
		ln -sf ${fasta} proteins.faa
	fi
	prepare_amrfinder.py proteins.faa ${amrfinder_results} ${genome}.amrfinder.coordinates.tsv
	"""
	// "$FAA_FILE" "$INPUT_FILE" "$PREPPED_INPUT"
}