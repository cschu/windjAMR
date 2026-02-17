process deeparg {
	container "quay.io/biocontainers/deeparg:1.0.4--pyhdfd78af_0"
	cpus 4
	time {8.h * task.attempt}
	memory {32.GB * task.attempt}

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

	output:
	tuple val(genome), path("${genome}/deeparg/${genome}.mapping.ARG"), emit: results

	script:
	// https://stackoverflow.com/questions/34346839/change-base-compiledir-to-save-compiled-files-in-another-directory
	"""
	mkdir -p ${genome}/deeparg tmp/

	export THEANO_FLAGS="base_compiledir=\$PWD/tmp"

	deeparg predict \
	--model LS \
	--type nucl \
	--input ${fasta} \
	--output ${genome}/deeparg/${genome} \
	--data-path ${db}
	"""
}