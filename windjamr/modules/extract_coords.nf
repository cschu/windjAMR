process extract_coords {
	executor "local"
	tag "${genome}"
	memory {4.GB * task.attempt}
	time {30.min * task.attempt}

	input:
	tuple val(genome), path(fasta), path(deeparg_results)

	output:
	tuple val(genome), path("${genome}.deeparg.coordinates.tsv"), emit: results

	script:
	"""
	if [[ "${fasta}" == *".gz" ]]; then
		gzip -dc ${fasta} > genes.ffn
	else
		ln -sf ${fasta} genes.ffn
	fi

	extract_coords.py ${deeparg_results} genes.ffn ${genome}.deeparg.coordinates.tsv
	"""
}