include { amrfinder } from "../modules/amrfinder"
include { deeparg } from "../modules/deeparg"
include { card_rgi; clean_faa } from "../modules/card_rgi"
include { hamronize; hamronize_summarize } from "../modules/hamronize"
include { argnorm } from "../modules/argnorm"


params.amrfinder_db = "/g/bork6/dickinson/argnorm_prep/containers/AMRFinder_DB/2025-07-16.1"
params.deeparg_db = "/g/bork6/dickinson/argnorm_prep/containers/deeparg_DB"
params.rgi_db = "/g/bork6/dickinson/argnorm_prep/containers/localDB"


workflow windjamr_genes {

	take:
	gene_input_ch

	main:
	amrfinder(
		gene_input_ch.genes,
		params.amrfinder_db
	)
	
	deeparg(
		gene_input_ch.genes,
		params.deeparg_db
	)

	clean_faa(gene_input_ch.proteins)

	card_rgi(
		clean_faa.out.proteins.map { genome, fasta -> [ genome, fasta, "protein" ] },
		params.rgi_db
	)

	hamronize_input_ch = Channel.empty()
	hamronize_input_ch = hamronize_input_ch.mix(
		amrfinder.out.results.map { genome, results -> [ genome, results, "amrfinderplus", "ncbi-amrfinderplus_4.0.23", "AMRFinder_2025-07-16.1", null ] }
	)
	hamronize_input_ch = hamronize_input_ch.mix(
		deeparg.out.results.map { genome, results -> [ genome, results, "deeparg", "DeepARG 1.0.4", "DeepARG database v2", null ] }
	)
	hamronize_input_ch = hamronize_input_ch.mix(
		card_rgi.out.results.map { genome, results -> [ genome, results, "rgi", "rgi_6.0.5", "CARD_4.0.1", null ] }
	)

	hamronize(hamronize_input_ch)

	hamronize_summarize_input_ch = hamronize.out.results
		.filter { it -> ( it[2] == "deeparg" || it[2] == "amrfinderplus" ) }
		.map { genome, results, tool, tool_version, db_version, db -> [ genome, results ] }
		.groupTuple(by: 0, sort: true)

	hamronize_summarize(hamronize_summarize_input_ch)

	argnorm(hamronize_summarize.out.results)

	results_ch = argnorm.out.results
		.mix(
			hamronize.out.results
				.filter { it -> ( it[2] == "rgi" ) }
				.map { genome, results, tool, tool_version, db_version, db -> [ genome, results ] }
		)

	emit:

	results = results_ch

}