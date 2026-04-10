process hamronize {
	container "quay.io/biocontainers/hamronization:1.1.9--pyhdfd78af_1"
	tag "${tool}:${db}:${genome}"

	input:
	tuple val(genome), path(results), val(tool), val(tool_version), val(db_version), val(db)

	output:
	tuple val(genome), path("hamronized/${genome}/${genome}.${tool}.${db}.hamronized.tsv"), val(tool), val(tool_version), val(db_version), val(db), emit: results

	script:

	def version_strings = (tool != "resfinder") ? "--analysis_software_version '${tool_version}' --reference_database_version '${db_version}'" : "";
	def input_file = (tool == "deeparg" || tool == "amrfinderplus" || tool == "rgi") ? "--input_file_name ${results}" : ""

	"""
	mkdir -p hamronized/${genome}/

	hamronize ${tool} ${results} ${input_file} ${version_strings} \
	--output hamronized/${genome}/${genome}.${tool}.${db}.hamronized.tsv	
	"""
}

process batch_hamronize {
	container "quay.io/biocontainers/hamronization:1.1.9--pyhdfd78af_1"
	tag "${tool}:${db}"

	input:
	// tuple path(results), val(tool), val(tool_version), val(db_version), val(db)
	tuple val(tool), val(tool_version), val(db), val(db_version), path(results)

	output:
	// tuple path("hamronized/*/*.${tool}.${db}.hamronized.tsv"), val(tool), val(tool_version), val(db_version), val(db), emit: results
	// tuple val(tool), val(tool_version), val(db), val(db_version), path("hamronized/*/*.${tool}.${db}.hamronized.tsv"), emit: results
	path("hamronized/*/*.${tool}.${db}.hamronized.tsv"), emit: results

	script:

	def version_strings = "--analysis_software_version '${tool_version}' --reference_database_version '${db_version}'"
	def input_file = ""
	def genome_prefix = ""

	if (tool == "resfinder") {
		version_strings = ""
		genome_prefix = "\$(basename \$f .resfinder.json)"

	} else if (tool == "abricate") {
		genome_prefix = "\$(basename \$f .${db}.abricate.tsv)"		

	} else if (tool == "deeparg") {
		input_file = "--input_file_name ${results}"
		genome_prefix = "\$(basename \$f .mapping.ARG)"

	} else if (tool == "amrfinderplus") {
		input_file = "--input_file_name ${results}"
		genome_prefix = "\$(basename \$f .amrfinder.coordinates.tsv)"

	} else if (tool == "rgi") {
		input_file = "--input_file_name ${results}"
		genome_prefix = "\$(basename \$f .txt)"
	}

	"""
	for f in ${results}; do

		genome=${genome_prefix}
		mkdir -p hamronized/\$genome/

		hamronize ${tool} \$f ${input_file} ${version_strings} --output hamronized/\$genome/\$genome.${tool}.${db}.hamronized.tsv

	done
	"""
}



process hamronize_summarize {
	container "quay.io/biocontainers/hamronization:1.1.9--pyhdfd78af_1"
	tag "${genome}"

	input:
	tuple val(genome), path(inputs)

	output:
	tuple val(genome), path("${genome}/hamronize/${genome}.combined.tsv"), emit: results
	
	script:
	"""
	mkdir -p ${genome}/hamronize/

	hamronize summarize \
	-o ${genome}/hamronize/${genome}.combined.tsv \
	-t tsv \
	${inputs}
	"""
}
