process resfinder {
	container "genomicepidemiology/resfinder:4.7.2"
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}
	cpus 4

	input:
	tuple val(genome), path(fasta)

	output:
	tuple val(genome), path("${genome}/resfinder/${genome}.resfinder.json"), emit: results

	script:
	"""
	mkdir -p ${genome}/resfinder/

	python3 -m resfinder \
	--kma_threads ${task.cpus} \
	-ifa ${fasta} \
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
