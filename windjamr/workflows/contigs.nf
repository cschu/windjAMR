include { amrfinder } from "../modules/amrfinder"
include { rgi_card } from "../modules/rgi_card"
include { hamronize; hamronize_summarize } from "../modules/hamronize"
include { argnorm } from "../modules/argnorm"
include { abricate } from "../modules/abricate"
include { resfinder } from "../modules/resfinder"
include { deeparg } from "../modules/deeparg"


workflow windjamr_contigs {
	take:
	contigs
	genes

	main:

	hamronize_input_ch = Channel.empty()

	amrfinder(
		contigs,
		params.amrfinder_db
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		amrfinder.out.results.map { genome, results -> [ genome, results, "amrfinderplus", "ncbi-amrfinderplus_4.0.23", "AMRFinder_2025-07-16.1", null ] }
	)

	rgi_card(
		contigs.map { genome, fasta -> [ genome, fasta, "contig" ] },
		params.rgi_db
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		rgi_card.out.results.map { genome, results -> [ genome, results, "rgi", "rgi_6.0.5", "CARD_4.0.1", null ] }
	)

	abricate_input_ch = contigs
		.combine(Channel.of("card", "argannot", "megares", "ncbi", "resfinder"))

	abricate(abricate_input_ch)

	hamronize_input_ch = hamronize_input_ch.mix(
		abricate.out.results
			.filter { it[2] == "card" }
			.map { genome, results, db -> [ genome, results, "abricate", "abricate_1.2.0", "card", "card" ] }
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		abricate.out.results
			.filter { it[2] != "card" }
			.map { genome, results, db -> [ genome, results, "abricate", "abricate_1.2.0", "abricate_1.2.0", db ] }
	)

	resfinder(contigs)

	hamronize_input_ch = hamronize_input_ch.mix(
		resfinder.out.results.map { genome, results -> [ genome, results, "resfinder", "", "", null ] }
	)

	if (params.add_deeparg_genes) {
		deeparg(
			genes,
			params.deeparg_db
		)

		hamronize_input_ch = hamronize_input_ch.mix(
			deeparg.out.results.map { genome, results -> [ genome, results, "deeparg", "DeepARG 1.0.4", "DeepARG database v2", null ] }
		)
	}

	hamronize(hamronize_input_ch)

	hamronize_summarize_input_ch = hamronize.out.results
		.filter { it -> ( it[2] == "resfinder" || (it[2] == "abricate" && it[5] != "card") || it[2] == "amrfinderplus" || (params.add_deeparg_genes && it[2] == "deeparg") ) }
		.map { genome, results, tool, tool_version, db_version, db -> [ genome, results ] }
		.groupTuple(by: 0, sort: true)

	hamronize_summarize(hamronize_summarize_input_ch)

	argnorm(hamronize_summarize.out.results)

	results_ch = argnorm.out.results
		.map { genome, results -> [ genome, [ "normed", results ] ] }
		.mix(
			hamronize.out.results
				.filter { it -> ( it[2] == "rgi" || ( it[2] == "abricate" && it[5] == "card" ) ) }
				.map { genome, results, tool, tool_version, db_version, db -> [ genome, [ "non_normed", results ] ] }
		)
		.groupTuple(by: 0, size: 3)
		.map { genome, data ->
			def files = ((data[0][0] == "normed")
				? [ data[0][1], data[1][1], data[2][1] ]
				: ((data[1][0] == "normed")
					? [ data[1][1], data[0][1], data[2][1] ]
					: [ data[2][1], data[0][1], data[1][1] ]))
			
			return [ genome, files[0], [files[1], files[2]] ]
		}

	emit:
	results = results_ch

}

// Input: hamronized CARD-RGI tsv, hamronized abricate+card tsv, summarized normed tsv (resfinder/abricate+4/AMRFinderPlus), CARD-ARO key tsv
