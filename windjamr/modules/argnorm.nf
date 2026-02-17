process argnorm {
	container "quay.io/biocontainers/argnorm:1.1.0--pyhdfd78af_0"
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}
	tag "${genome}"

	input:
	tuple val(genome), path(table)

	output:
	tuple val(genome), path("${genome}/argnorm/${genome}.argnorm.tsv"), emit: results

	script:
	"""
	mkdir -p ${genome}/argnorm/

	argnorm hamronization -i ${table} -o ${genome}/argnorm/${genome}.argnorm.tsv
	"""
}
