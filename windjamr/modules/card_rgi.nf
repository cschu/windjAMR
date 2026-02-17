process clean_faa {
	executor "local"
	input:
	tuple val(genome), path(fasta)

	output:
	tuple val(genome), path("${genome}/cleaned/${genome}.faa"), emit: proteins

	script:
	"""
	mkdir -p ${genome}/cleaned/

	if [[ "${fasta}" == *".gz" ]]; then
		gzip -dc ${fasta} > proteins.faa
	else
		ln -sf ${fasta} proteins.faa
	fi

	tr -d "*" < proteins.faa > ${genome}/cleaned/${genome}.faa
	"""
}

process card_rgi {
	container "quay.io/biocontainers/rgi:6.0.5--pyh05cac1d_0"
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}
	cpus 8

	input:
	tuple val(genome), path(fasta), val(input_type)
	path(db)

	output:
	tuple val(genome), path("{genome}/rgi/${genome}.txt"), emit: results
	// SAMEA112496619_METAG_H5WNWDSXC.SW051-2.psa_megahit.prodigal.txt

	script:
	"""
	mkdir -p ${genome}/rgi
	rgi main \
	-n ${task.cpus} \
	--input_sequence ${fasta} \
	--output_file ${genome}/rgi/${genome} \
	--input_type ${input_type} \
	--local \
	--clean
	"""

}




// singularity exec \
//   --bind /g/bork6/dickinson/argnorm_prep/test_sample:/mnt/test_sample \
//   --bind /g/bork6/dickinson/argnorm_prep/test_sample/rgi_output_protein:/mnt/output \
//   /g/bork6/dickinson/argnorm_prep/containers/rgi_6.0.5--pyh05cac1d_0.sif \
//   rgi main \
//     --input_sequence /mnt/test_sample/SAMEA112496619_METAG_H5WNWDSXC.SW051-2.psa_megahit.prodigal.cleaned.faa \
//     --output_file /mnt/output/rgi_output_protein \
//     --input_type protein \
//     --local \
//     --clean
