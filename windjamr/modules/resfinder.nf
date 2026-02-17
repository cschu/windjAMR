process resfinder {
	container "genomicepidemiology/resfinder:4.7.2"
	publishDir "${params.output_dir}", mode: "copy"
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}
	cpus 4
	tag "${genome}"

	input:
	tuple val(genome), path(fasta)

	output:
	tuple val(genome), path("${genome}/resfinder/${genome}.resfinder.json"), emit: results

	script:
	"""
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
	"""
}

// singularity exec \
//   --bind /g/bork6/dickinson/argnorm_prep/test_sample:/app \
//   /g/bork6/dickinson/argnorm_prep/containers/resfinder_latest.sif \
//   python3 -m resfinder \
//       -ifa /app/SAMEA112496619_METAG_H5WNWDSXC.SW051-2-assembled.fa \
//       -o /app/resfinder_output_new \
//       -s Other \
//       --acquired \
//       -j /app/resfinder_output_new/resfinder_results.json
