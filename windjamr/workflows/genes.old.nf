include { amrfinder } from "../modules/amrfinder"
include { deeparg } from "../modules/deeparg"
include { rgi_card; clean_faa } from "../modules/rgi_card"
include { hamronize; hamronize_summarize } from "../modules/hamronize"
include { argnorm } from "../modules/argnorm"


workflow windjamr_genes {

	take:
	genes
	proteins

	main:

	predictors_ch = Channel.fromPath("${projectDir}/assets/predictors.json").splitJson()

	hamronize_input_ch = Channel.empty()

	amrfinder(
		genes,
		params.amrfinder_db,
		"nucleotide"
	)
	
	hamronize_input_ch = hamronize_input_ch.mix(
		amrfinder.out.results.map { genome, results -> [ "amrfinderplus", genome, results, null ] }
		// amrfinder.out.results.map { genome, results -> [ genome, results, "amrfinderplus", "ncbi-amrfinderplus_4.0.23", "AMRFinder_2025-07-16.1", null ] }
	)

	deeparg(
		genes,
		params.deeparg_db,
		"nucl"
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		deeparg.out.results.map { genome, results -> [ "deeparg", genome, results, null ] }
		// deeparg.out.results.map { genome, results -> [ genome, results, "deeparg", "DeepARG 1.0.4", "DeepARG database v2", null ] }
	)
	
	clean_faa(proteins)

	rgi_card(
		clean_faa.out.proteins,
		params.rgi_db,
		"protein"
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		rgi_card.out.results.map { genome, results -> [ "rgi", genome, results, null ] }
		// rgi_card.out.results.map { genome, results -> [ genome, results, "rgi", "rgi_6.0.5", "CARD_4.0.1", null ] }
	)

	hamronize_input_ch = hamronize_input_ch
		.combine(predictors_ch, by: 0)
		.map {
			tool, genome, results, db, tool_version, db_version -> [ genome, results, tool, tool_version, db_version, db ]
		}

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
