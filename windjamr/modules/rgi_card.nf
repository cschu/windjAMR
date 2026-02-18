process clean_faa {
	executor "local"
	tag "${genome}"

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


process clean_faa_bulk {
	executor "local"
	tag "${genome}"

	input:
	path(fasta_files)

	output:
	path("cleaned_faa/*.faa"), emit: proteins

	script:
	"""
	set -e -o pipefail

	mkdir -p cleaned_faa

	for faa in \(find . -maxdepth 1 -mindepth 1 -type l); do
		if [[ "${fasta}" == *".gz" ]]; then
			tool=zcat
		else
			tool=cat
		fi

		genome=\$(basename \$genome | sed "s/\.(fa(s(ta)?)?|f[an]a)(\.gz)?$//")

		\$tool \$faa | tr -d "*" > cleaned_faa/\$genome.faa
	done
	"""
}


process rgi_card {
	container "quay.io/biocontainers/rgi:6.0.5--pyh05cac1d_0"
	publishDir "${params.output_dir}", mode: "copy"
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}
	cpus 8
	tag "${input_type}:${genome}"

	input:
	tuple val(genome), path(fasta), val(input_type)
	path(db)

	output:
	tuple val(genome), path("${genome}/rgi/${genome}.txt"), emit: results
	
	script:
	"""
	mkdir -p ${genome}/rgi tmp

	export MPLCONFIGDIR=\$PWD/tmp/matplotlib

	rgi main \
	-n ${task.cpus} \
	--input_sequence ${fasta} \
	--output_file ${genome}/rgi/${genome} \
	--input_type ${input_type} \
	--local \
	--clean
	"""

}
