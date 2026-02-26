process collate_tables {
	publishDir "${params.output_dir}", mode: "copy"
	time { 8.h * task.attempt }
	memory { 8.GB * task.attempt }

	input:
	path(tables)

	output:
	path("all_samples.summary.tsv"), emit: summary

	script:
	"""
	head -n 1 ${tables[0]} | awk -v OFS='\\t' '{print \$0,"sample"}' > all_samples.summary.tsv

	for f in \$(find . -maxdepth 1 -mindepth 1 -name '*.tsv' | sort ); do
		sample=\$(basename \$f .tsv);
		awk -v OFS='\\t' -v sample=\$sample 'NR>1 {print \$0,sample}' \$f >> all_samples.summary.tsv	
	done
	"""



}