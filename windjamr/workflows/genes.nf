include { amrfinder } from "../modules/amrfinder"
include { deeparg } from "../modules/deeparg"
include { rgi_card; clean_faa } from "../modules/rgi_card"
include { hamronize; hamronize_summarize } from "../modules/hamronize"
include { argnorm } from "../modules/argnorm"


params.amrfinder_db = "/g/bork6/dickinson/argnorm_prep/containers/AMRFinder_DB/2025-07-16.1"
params.deeparg_db = "/g/bork6/dickinson/argnorm_prep/containers/deeparg_DB"
params.rgi_db = "/g/bork6/dickinson/argnorm_prep/containers/localDB"


workflow windjamr_genes {

	take:
	genes
	proteins

	main:
	amrfinder(
		genes,
		params.amrfinder_db
	)
	
	deeparg(
		genes,
		params.deeparg_db
	)

	clean_faa(proteins)

	rgi_card(
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
		rgi_card.out.results.map { genome, results -> [ genome, results, "rgi", "rgi_6.0.5", "CARD_4.0.1", null ] }
	)

	hamronize(hamronize_input_ch)

	hamronize_summarize_input_ch = hamronize.out.results
		.filter { it -> ( it[2] == "deeparg" || it[2] == "amrfinderplus" ) }
		.map { genome, results, tool, tool_version, db_version, db -> [ genome, results ] }
		.groupTuple(by: 0, sort: true)

	hamronize_summarize(hamronize_summarize_input_ch)

	argnorm(hamronize_summarize.out.results)

	results_ch = argnorm.out.results
		.map { genome, results -> [ genome, [ "normed", results ] ] }
		.mix(
			hamronize.out.results
				.filter { it -> ( it[2] == "rgi" ) }
				.map { genome, results, tool, tool_version, db_version, db -> [ genome, [ "non_normed", results ] ] }
		)
		.groupTuple(by: 0, size: 2)
		.map { genome, data ->
			def files = (data[0][0] == "normed") ? [ data[0][1], data[1][1] ] : [ data[1][1], data[0][1] ]
			return [ genome, files[0], [files[1]] ]
		}

	emit:
	results = results_ch

}


// Input: hamronized CARD-RGI tsv, summarized normed AMRFinderPlus and DeepARG tsv, CARD-ARO key tsv
