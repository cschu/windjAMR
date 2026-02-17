process hamronize {
	container "quay.io/biocontainers/hamronization:1.1.9--pyhdfd78af_1"
	tag "${tool}:${db}:${genome}"

	input:
	tuple val(genome), path(results), val(tool), val(tool_version), val(db_version), val(db)

	output:
	tuple val(genome), path("hamronized/${genome}/${genome}.${tool}.hamronized.tsv"), val(tool), val(tool_version), val(db_version), val(db), emit: results

	script:

	def version_strings = (tool != "resfinder") ? "--analysis_software_version '${tool_version}' --reference_database_version '${db_version}'" : "";
	def input_file = (tool == "deeparg" || tool == "amrfinderplus" || tool == "rgi") ? "--input_file_name ${results}" : ""

	"""
	mkdir -p hamronized/${genome}/

	hamronize ${tool} ${results} ${input_file} ${version_strings} \
	--output hamronized/${genome}/${genome}.${tool}.hamronized.tsv	
	"""
}
	// singularity exec --bind $BIND_DIR \
    //     $HAMRONIZATION_CONTAINER \
    //     hamronize abricate \
    //     "$INPUT_FILE" \
    //     --analysis_software_version "abricate_1.2.0" \
    //     --reference_database_version "abricate_1.2.0" \
    //     --output "$HAMRONIZED_FILE"


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

// singularity exec --bind $BIND_DIR \
//     $HAMRONIZATION_CONTAINER \
//     hamronize summarize \
//     -o "$SUMMARIZED_FILE" \
//     -t tsv \
//     "${INPUT_FILES[@]}"

