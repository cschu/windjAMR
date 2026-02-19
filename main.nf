include { windjamr_genes } from "./windjamr/workflows/genes"
include { windjamr_contigs } from "./windjamr/workflows/contigs"
include { windjamr_hybrid } from "./windjamr/workflows/hybrid"
include { merge_dereplicate; merge_dereplicate_deeparg } from "./windjamr/modules/merge_dereplicate"

params.contig_file_pattern = "**.{fna,fasta,fa,fna.gz,fasta.gz,fa.gz}"
params.gene_file_pattern = "**.{faa,fna,fasta,fa,faa.gz,fna.gz,fasta.gz,fa.gz}"
params.contigs = null
params.genes = null
params.runmode = "genes"

print "PARAMS: ${params}"

workflow {

	// contig_input_ch = Channel
    //     .fromPath("${params.contigs}/${params.contig_file_pattern}")
    //     .map { fasta ->
    //         def genome_id = fasta.name.replaceAll(/\.(fa(s(ta)?)?|fna)(\.gz)?$/, "")
    //         return [ genome_id, fasta ]
    //     }

	// Channel
	// 	.fromPath("${params.genes}/${params.gene_file_pattern}")
	// 	.map { fasta ->
	// 		def genome_id = fasta.name.replaceAll(/\.(fa(s(ta)?)?|f[an]a)(\.gz)?$/, "")
	// 		return [ genome_id, fasta ]
	// 	}
	// 	.branch { genome_id, fasta  ->
	// 		proteins: (fasta.name.endsWith(".faa") || fasta.name.endsWith(".faa.gz"))
	// 		genes: true
	// 	}
	// 	.set { gene_input_ch }
	predictors_ch = Channel.fromPath("${projectDir}/assets/predictors.json").splitJson()

	input_ch = Channel.fromPath(params.samplesheet).splitCsv(header: true, sep: '\t')

	// contig_input_ch = input_ch.map { row -> [row.]}


	// contig_input_ch.dump(pretty: true, tag: "contig_input_ch")
	// gene_input_ch.proteins.dump(pretty: true, tag: "gene_input_ch.proteins")
	// gene_input_ch.genes.dump(pretty: true, tag: "gene_input_ch.genes")
	input_ch.dump(pretty: true, tag: "input_ch")


	results_ch = Channel.empty()

	if (params.runmode == "genes") {
		windjamr_genes(
			input_ch.map { row -> [ row.genome, row.proteins ] },
			predictors_ch
		)
		merge_dereplicate(
			results_ch.mix(windjamr_genes.out.results),
			"${projectDir}/assets/card_collapsed.tsv",
			params.runmode
		)
	} else if (params.runmode == "hybrid") {
		windjamr_hybrid(
			input_ch.map { row -> [ row.genome, row.proteins ] },
			input_ch.map { row -> [ row.genome, row.genes ] },
			input_ch.map { row -> [ row.genome, row.contigs ] },
			predictors_ch
		)
		merge_dereplicate_deeparg(
			windjamr_hybrid.out.results,
			"${projectDir}/assets/card_collapsed.tsv",
			params.runmode
		)
	}

	// results_ch.dump(pretty: true, tag: "results_ch")


	// if (params.add_deeparg_genes) {
	// 	merge_dereplicate_deeparg(
	// 		results_ch,
	// 		"${projectDir}/assets/card_collapsed.tsv",
	// 		"hybrid"
	// 	)
	// } else {
	// 	merge_dereplicate(
	// 		results_ch,
	// 		"${projectDir}/assets/card_collapsed.tsv",
	// 		params.runmode
	// 	)
	// }

	if (false) {

		if (params.genes != null && params.contigs == null) {

			print "GENE MODE"
			

			// windjamr_genes(gene_input_ch.genes, gene_input_ch.proteins)
			// windjamr_genes(
			// 	input_ch.map { row -> [ row.genome, row.genes ] },
			// 	input_ch.map { row -> [ row.genome, row.proteins ] }
			// )
			windjamr_genes(input_ch.map { row -> [ row.genome, row.proteins ] }, predictors_ch)
			results_ch = results_ch.mix(windjamr_genes.out.results)
			runmode = "genes"

		} else if (params.contigs != null) {

			print "CONTIG MODE"

			// genes_ch = (params.genes != null && params.add_deeparg_genes) ? gene_input_ch.genes : Channel.empty()
			// genes_ch = (params.genes != null && params.add_deeparg_genes) ? input_ch.map { row -> [ row.genome, row.genes ] } : Channel.empty()
			// windjamr_contigs(contig_input_ch, genes_ch)
			windjamr_contigs(
				input_ch.map { row -> [ row.genome, row.contigs ] },
				(params.genes != null && params.add_deeparg_genes) ? input_ch.map { row -> [ row.genome, row.genes ] } : Channel.empty()
			)
			results_ch = results_ch.mix(windjamr_contigs.out.results)
			runmode = "contigs"

		}
	}
}
