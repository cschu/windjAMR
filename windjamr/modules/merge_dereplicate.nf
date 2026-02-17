process merge_dereplicate {

	input:
	tuple val(genome), path(normed), path(non_normed)
	path(cardfile)
	val(mode)

	output:
	// path("windjAMR.${mode}.tsv")


	script:

	def script = "merge_dereplicate_${mode}.R"
	

	"""
	echo ${normed}
	echo ${non_normed}
	"""
	// ${script} x ${cardfile} windjAMR.${mode}.tsv y

}

// combined_normed_file <- args[1]
// card_file            <- args[2]
// output_file          <- args[3]
// non_normed_files     <- args[4:length(args)]
