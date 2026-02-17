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
