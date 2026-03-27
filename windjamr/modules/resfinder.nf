process resfinder {
	container "genomicepidemiology/resfinder:4.7.2"
	publishDir "${params.output_dir}", mode: "copy"
	time {2.d * task.attempt}
	memory {32.GB * task.attempt}
	cpus 4
	tag "${genome}"

	input:
	tuple val(genome), path(fasta)

	output:
	tuple val(genome), path("${genome}/resfinder/${genome}.resfinder.json"), emit: results

	script:
	"""
	set -e -o pipefail

	mkdir -p ${genome}/resfinder/

	if [[ "${fasta}" == *".gz" ]]; then
		gzip -dc ${fasta} > genome.fna
	else
		ln -sf ${fasta} genome.fna
	fi

	python3 -m resfinder \
	--kma_threads ${task.cpus} \
	-ifa genome.fna \
	-o ${genome}/resfinder/ \
	-s Other \
	--acquired \
	-j ${genome}/resfinder/${genome}.resfinder.json

	rm -rfv genome.fna ${genome}/resfinder/*_blast
	"""
}
