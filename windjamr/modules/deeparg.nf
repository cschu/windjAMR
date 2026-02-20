process deeparg {
	container "quay.io/biocontainers/deeparg:1.0.4--pyhdfd78af_0"
	publishDir "${params.output_dir}", mode: "copy"
	cpus 4
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}
	tag "${genome}"

	// https://github.com/nf-core/funcscan/issues/23 // does not solve the compiledir issue on its own!
	containerOptions {
        ['singularity', 'apptainer'].contains(workflow.containerEngine)
            ? '-B $(which bash):/usr/local/lib/python2.7/site-packages/Theano-0.8.2-py2.7.egg-info/PKG-INFO'
            : "${workflow.containerEngine}" == 'docker'
                ? '-v $(which bash):/usr/local/lib/python2.7/site-packages/Theano-0.8.2-py2.7.egg-info/PKG-INFO'
                : ''
    }

	input:
	tuple val(genome), path(fasta)
	path(db)
	val(input_type)

	output:
	tuple val(genome), path("${genome}/deeparg/${genome}.mapping.ARG"), emit: results

	script:
	// https://stackoverflow.com/questions/34346839/change-base-compiledir-to-save-compiled-files-in-another-directory
	"""
	mkdir -p ${genome}/deeparg tmp/

	export THEANO_FLAGS="base_compiledir=\$PWD/tmp"

	deeparg predict \
	--model LS \
	--type ${input_type} \
	--input ${fasta} \
	--output ${genome}/deeparg/${genome} \
	--data-path ${db}
	"""
}


process extract_coords {
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