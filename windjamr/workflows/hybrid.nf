include { hamronize; hamronize_summarize } from "../modules/hamronize"
include { argnorm } from "../modules/argnorm"
include { amrfinder } from "../modules/amrfinder"
include { rgi_card } from "../modules/rgi_card"
include { abricate } from "../modules/abricate"
include { resfinder } from "../modules/resfinder"
include { deeparg; extract_deeparg_coords } from "../modules/deeparg"

include { windjamr_proteins } from "./proteins"


workflow windjamr_hybrid {

	take:
	proteins
	genes
	contigs
	predictors

	main:

	abricate_db_ch = Channel.of("card", "argannot", "megares", "ncbi", "resfinder")

	hamronize_input_ch = Channel.empty()
	
	windjamr_proteins(proteins)
	
	hamronize_input_ch = hamronize_input_ch.mix(windjamr_proteins.out.results)

	abricate_input_ch = contigs.combine(abricate_db_ch)

	abricate(abricate_input_ch)

	hamronize_input_ch = hamronize_input_ch.mix(
		abricate.out.results
			.filter { it[2] == "card" }
			.map { genome, results, db -> [ "abricate_card", genome, results, "card" ] }
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		abricate.out.results
			.filter { it[2] != "card" }
			.map { genome, results, db -> [ "abricate_x", genome, results, db ] }
	)

	resfinder(contigs)

	hamronize_input_ch = hamronize_input_ch.mix(
		resfinder.out.results.map { genome, results -> [ "resfinder", genome, results, null ] }
	)

	hamronize_input_ch = hamronize_input_ch
		.combine(predictors, by: 0)
		.map {
			tool, genome, results, db, tool_version, db_version -> [ genome, results, tool.replaceAll(/abricate_.+/, "abricate"), tool_version, db_version, db ]
		}

	hamronize(hamronize_input_ch)

	hamronize_summarize_input_ch = hamronize.out.results
		.filter { it -> ( it[2] == "resfinder" || (it[2] == "abricate" && it[5] != "card") || it[2] == "amrfinderplus" || it[2] == "deeparg" ) }
		.map { genome, results, tool, tool_version, db_version, db -> [ genome, results ] }
		.groupTuple(by: 0, sort: true)

	hamronize_summarize(hamronize_summarize_input_ch)

	argnorm(hamronize_summarize.out.results)

	extract_deeparg_coords(
		genes.join(argnorm.out.results, by: 0)
	)

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

	results_ch = results_ch.join(extract_deeparg_coords.out.results, by: 0)	

	emit:
	results = results_ch


}


// hybrid : resfinder, abricate on contigs; deeparg, amrfinder, rgi on protein;