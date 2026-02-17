process merge_dereplicate {
	container "ghcr.io/cschu/windjamr:main"
	publishDir "${params.output_dir}", mode: "copy"
	time '2.h'
	memory '2.GB'
	tag "${genome}"

	input:
	tuple val(genome), path(normed), path(non_normed)
	path(cardfile)
	val(runmode)

	output:
	path("windjAMR.${runmode}.tsv")

	script:

	def script = "merge_dereplicate_${runmode}.R"
	
	"""
	${script} ${normed} ${cardfile} windjAMR.${runmode}.tsv ${non_normed}
	"""

}
