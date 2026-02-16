process deeparg {
	container "quay.io/biocontainers/deeparg:1.0.4--pyhdfd78af_0"
	cpus 4
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}

	input:
	tuple val(genome), path(fasta)
	path(db)

	output:
	tuple val(genome), path("${genome}/deeparg/${genome}"), emit: results

	script:
	"""
	mkdir -p ${genome}/deeparg

	deeparg predict \
    --model LS \
    --type nucl \
    --input ${fasta} \
    --output ${genome}/deeparg/${genome} \
    --data-path ${db}
	"""
}