process abricate {
	container "quay.io/biocontainers/abricate:1.2.0--h05cac1d_0"
	publishDir "${params.output_dir}", mode: "copy"
	memory {32.GB * task.attempt}
	time {8.h * task.attempt}
	cpus 4
	tag "${db}:${genome}"

	input:
	tuple val(genome), path(fasta),	val(db)

	output:
	tuple val(genome), path("${genome}/abricate/${genome}.${db}.abricate.tsv"), val(db), emit: results

	script:
	"""
	mkdir -p ${genome}/abricate/
	abricate --threads ${task.cpus} --db ${db} ${fasta} > ${genome}/abricate/${genome}.${db}.abricate.tsv
	"""

}
