include { amrfinder; postprocess_amrfinder } from "../modules/amrfinder"
include { rgi_card } from "../modules/rgi_card"
include { hamronize; hamronize_summarize } from "../modules/hamronize"
include { deeparg } from "../modules/deeparg"


workflow windjamr_proteins {
	take:
	proteins
	
	main:

	hamronize_input_ch = Channel.empty()

	amrfinder(
		proteins,
		params.amrfinder_db,
		"protein"
	)

	postprocess_amrfinder(
		proteins.join(amrfinder.out.results, by: 0)
	)
		
	hamronize_input_ch = hamronize_input_ch.mix(
		postprocess_amrfinder.out.results.map { genome, results -> [ "amrfinderplus", genome, results, null ] }
	)

	deeparg(
		proteins,
		params.deeparg_db,
		"prot"
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		deeparg.out.results.map { genome, results -> [ "deeparg", genome, results, null ] }
	)
	
	clean_faa(proteins)

	rgi_card(
		clean_faa.out.proteins.map { genome, fasta -> [ genome, fasta, "protein" ] },
		params.rgi_db
	)

	hamronize_input_ch = hamronize_input_ch.mix(
		rgi_card.out.results.map { genome, results -> [ "rgi", genome, results, null ] }
	)

	emit:
	results = hamronize_input_ch


}

//     hybrid : resfinder, abricate on contigs; deeparg, amrfinder, rgi on protein; gene: deeparg, amrfinder, rgi on protein