include { windjamr_genes } from "./windjamr/workflows/genes"
include { windjamr_contigs } from "./windjamr/workflows/contigs"
include { merge_dereplicate } from "./windjamr/modules/merge_dereplicate"

params.contig_file_pattern = "**.{fna,fasta,fa,fna.gz,fasta.gz,fa.gz}"
params.gene_file_pattern = "**.{faa,fna,fasta,fa,faa.gz,fna.gz,fasta.gz,fa.gz}"
params.contigs = null
params.genes = null


workflow {

	contig_input_ch = Channel
        .fromPath("${params.contigs}/${params.contig_file_pattern}")
        .map { fasta ->
            def genome_id = fasta.name.replaceAll(/\.(fa(s(ta)?)?|fna)(\.gz)?$/, "")
            return [ genome_id, fasta ]
        }

	Channel
		.fromPath("${params.genes}/${params.gene_file_pattern}")
		.map { fasta ->
			def genome_id = fasta.name.replaceAll(/\.(fa(s(ta)?)?|f[an]a)(\.gz)?$/, "")
			return [ genome_id, fasta ]
		}
		.branch { genome_id, fasta  ->
			proteins: (fasta.name.endsWith(".faa") || fasta.name.endsWith(".faa.gz"))
			genes: true
		}
		.set { gene_input_ch }


	contig_input_ch.dump(pretty: true, tag: "contig_input_ch")
	gene_input_ch.proteins.dump(pretty: true, tag: "gene_input_ch.proteins")
	gene_input_ch.genes.dump(pretty: true, tag: "gene_input_ch.genes")


	results_ch = Channel.empty()
	def runmode = null
	if (params.genes) {

		windjamr_genes(gene_input_ch.genes, gene_input_ch.proteins)
		results_ch = results_ch.mix(windjamr_genes.out.results)
		runmode = "genes"

	} else if (params.contigs) {

		windjamr_contigs(contig_input_ch)
		results_ch = results_ch.mix(windjamr_contigs.out.results)
		runmode = "contigs"

	}

	results_ch.dump(pretty: true, tag: "results_ch")

	merge_dereplicate(
		results_ch,
		"${projectDir}/assets/card_collapsed.tsv",
		runmode
	)

}