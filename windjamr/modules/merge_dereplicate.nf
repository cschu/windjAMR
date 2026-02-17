process merge_dereplicate {
	container "ghcr.io/cschu/windjamr:main"
	time '2.h'
	memory '2.GB'

	input:
	tuple val(genome), path(normed), path(non_normed)
	path(cardfile)
	val(runmode)

	output:
	path("windjAMR.${runmode}.tsv")


	script:

	def script = "merge_dereplicate_${runmode}.R"
	

	// echo ${normed}
	// echo ${non_normed}
	"""
	${script} ${normed} ${cardfile} windjAMR.${runmode}.tsv ${non_normed}
	"""

}

// combined_normed_file <- args[1]
// card_file            <- args[2]
// output_file          <- args[3]
// non_normed_files     <- args[4:length(args)]
