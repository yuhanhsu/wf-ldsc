# code to generate gene coordinates file (for input to ldsc make_annot.py)

rm(list=ls())

library(dplyr)
#BiocManager::install('rtracklayer')
library(rtracklayer) # readGFF

# download and parse GENCODE v49 GTF for GRCh37
#https://www.gencodegenes.org/human/release_49lift37.html
#description: evidence-based annotation of the human genome (GRCh38), version 49 (Ensembl 115), mapped to GRCh37 with gencode-backmap
#date: 2025-07-08
url <- 'https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_49/GRCh37_mapping/gencode.v49lift37.basic.annotation.gtf.gz'
gtf <- readGFF(url)

# extract relevant rows and columns for protein-coding genes on autosomes (chr1-22)
outDf <- gtf %>% subset(type=='gene' & gene_type=='protein_coding' &
	seqid %in% paste0('chr',1:22)) %>%
	select(GENE=gene_name,CHR=seqid,START=start,END=end)

dim(outDf) # 19270 x 4
length(unique(outDf$GENE)) # 19261 unique gene names (9 genes have >1 chr pos)

# check duplicated gene name entries
x <- names(which(table(outDf$GENE)>1)) # 9 gene names
y <- subset(outDf,GENE %in% x)
z <- y %>% group_by(GENE) %>%
	summarize(CHR=paste0(unique(CHR),collapse=','),
		START=paste0(unique(START),collapse=','),
		END=paste0(unique(END),collapse=','))
data.frame(z)
# 9 duplicated genes with similar coordinates on same chromosome

# remove duplicated gene names by keeping first entry only
outDf <- outDf %>% subset(!duplicated(GENE))
dim(outDf) # 19261 x 4

write.table(outDf,'../data/260528_GENCODE_v49_GRCh37_ProteinCoding_chr1-22_coord.txt',
	sep='\t',quote=F,row.names=F)

