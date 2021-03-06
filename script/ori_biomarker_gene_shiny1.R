# example
# mut <- read.xlsx("E:/song/project/20191106biomarker/shiny/demo/pipeline/Himalaya/example/example_mutation.xlsx")
# cli <- read.xlsx("E:/song/project/20191106biomarker/shiny/demo/pipeline/Himalaya/example/example_info.xlsx")
# tt <- ori_biomarker_gene("TMB",mut,cli,n=5,ytype ="continuous",cutoff=NULL,outdir=NULL)
# tt <- ori_biomarker_gene("GENDER",mut,cli,n=5,ytype ="de",cutoff=NULL,outdir=NULL)


ori_biomarker_gene <- function(y,mut,cli,n=5,ytype ="continuous",cutoff=NULL,outdir=NULL){
  cal_freq = function(mut, total){
    # 计算基因突变频率
    mut = unique(mut[, c("ORDER_ID", "GENE")])
    mut = as.data.frame(table(mut$GENE))
    colnames(mut) = c("GENE", "MUTANT")
    mut$N = total
    mut$FREQUENCY = mut$MUTANT / mut$N
    mut$WT = mut$N - mut$MUTANT
    mut = mut[order(mut$FREQUENCY, decreasing = T), ]
    return(mut)
  }
  
  wiltest <- function(varID,dat,group1,group2){
    # group1 wt,group2 mt
    dat[[varID]] <- as.numeric(dat[[varID]])
    dat1 <- dat[dat$ORDER_ID %in% group1, colnames(dat)== varID]
    dat2 <- dat[dat$ORDER_ID %in% group2, colnames(dat)== varID]
    na_count1 <- sum(!is.na(dat1))
    na_count2 <- sum(!is.na(dat2))
    if(na_count1>2 & na_count2>2){
      wtest <- wilcox.test(as.numeric(dat1),
                           as.numeric(dat2))
      ttest <- t.test(as.numeric(dat1),
                      as.numeric(dat2))
      mdat1 <- mean(as.numeric(dat1),na.rm = TRUE) 
      mdat2 <- mean(as.numeric(dat2),na.rm = TRUE)
      re <- data.frame("group1_Mean" = mdat1,
                       "group2_mean" = mdat2,
                       "wilcox_pvalue" = wtest$p.value,
                       "t.test_pvalue" = ttest$p.value,
                       "log2FC"= log2(mdat2/mdat1)
      )
      row.names(re) <- varID
      return(re)
    }else{
      #stop('Requires that there must be at least three elements in all groups')
      re <- rep(NA,5)
      return(re)
    }
  }
  
  ori_wil_t_test_g<-function(x,y,mut){
    datfra0 <-  unique(mut[, c("ORDER_ID","GENE", y)])
    datfra <- unique(mut[, c("ORDER_ID", y)])
    MTsample <-unique(datfra0[["ORDER_ID"]][datfra0[["GENE"]]==x])
    WTsample <- unique(datfra0[["ORDER_ID"]][!datfra0[["ORDER_ID"]] %in% MTsample])
    datfra$type[datfra$ORDER_ID %in% MTsample ] = "MT"
    datfra$type[datfra$ORDER_ID %in% WTsample]  = "WT"
    datfra[[y]] <- as.numeric(datfra[[y]])
    datfra <-datfra[!is.na(datfra[[y]]),]
    r <-  wiltest(y,datfra,WTsample,MTsample)
    return(r)
  }

  fisherte<- function(varID,dat,group1,group2){
    # group1 wt,group2 mt
    dat[[varID]] <- as.factor(dat[[varID]])
    m <- dat[dat$ORDER_ID %in% c(group1,group2), colnames(dat) %in% c("ORDER_ID",varID)]
    m$type <- NA
    m$type[m$ORDER_ID%in% group1]='group1'
    m$type[m$ORDER_ID%in% group2]='group2'
    m <- na.omit(m)
    m[[varID]]<- as.character(m[[varID]])
    m_in <- table(m[,c(varID,"type")])
    m_in <- m_in[,c(2,1)]
    re1 <- fisher.test(m_in)
    re2 <- chisq.test(m_in)
    resum <- c(m_in[,1],m_in[,2],re1$estimate,re1$p.value,re2$p.value)
    names(resum) <- c(paste(rep(colnames(m_in),each=2),rep(rownames(m_in),2),sep = "_"),
                      "OR",'fisher.test.Pvalue','chisq.test.Pvalue')
    return(resum)
  }
  
  ori_fisher_chisq_test_g<-function(x,y,mut,ytype=ytype,cutoff=cutoff){
    datfra0 <-  unique(mut[, c("ORDER_ID","GENE", y)])
    datfra <- unique(mut[, c("ORDER_ID", y)])
    MTsample <-unique(datfra0[["ORDER_ID"]][datfra0[["GENE"]]==x])
    WTsample <- unique(datfra0[["ORDER_ID"]][!datfra0[["ORDER_ID"]] %in% MTsample])
    datfra$type[datfra$ORDER_ID %in% MTsample ] = "MT"
    datfra$type[datfra$ORDER_ID %in% WTsample]  = "WT"
    if(ytype=="continuous"){
      datfra[[y]] <- as.numeric(datfra[[y]])
      datfra <-datfra[!is.na(datfra[[y]]),]
      if(is.null(cutoff)){
        datfra$type1 <- ifelse(datfra[[y]] > median(datfra[[y]]),"High","Low")
      }else{
        datfra$type1 <- ifelse(datfra[[y]] > cutoff,"High","Low")
      }
    }else{
      datfra$type1 <- as.factor(datfra[[y]])
    }
    r <- fisherte("type1",datfra,WTsample,MTsample)
    return(r)
  }
  
  if(!is.null(outdir)){
    outdir <- paste0("./",outdir,"/")
    if(!dir.exists(outdir)){
      dir.create(outdir)
    }
  }
  
  cliNb <- length(unique(cli[["ORDER_ID"]]))
  mutNb <- length(unique(mut[["ORDER_ID"]]))
  NN <- max(cliNb,mutNb)
  freq <- cal_freq(mut, NN)
  g <- as.character(freq$GENE[freq$MUTANT>n])
  
  mut1 <- unique(mut[,c("ORDER_ID","GENE")])
  cli1 <- unique(cli[,c("ORDER_ID",y)])
  mut1 <- merge(mut1,cli1)
  mut <- mut1 

  if (ytype=="continuous"){
    re <- lapply(g,ori_wil_t_test_g,y,mut)
    re <- as.data.frame(do.call(rbind,re))
    rownames(re) <- g
    colnames(re) <- gsub("group1","WT",colnames(re))
    colnames(re) <- gsub("group2","MT",colnames(re))
    re$wilcox_padj <- p.adjust(re$wilcox_pvalue)
    re$t.test_padj <- p.adjust(re$t.test_pvalue)
    wil_t_test_re<- re
    wil_t_test_re <- na.omit(wil_t_test_re)
  }else{
    wil_t_test_re <- NULL
  }
  
  re <- lapply(g,ori_fisher_chisq_test_g,y,mut,ytype=ytype,cutoff=cutoff)
  re <- as.data.frame(do.call(rbind,re))
  rownames(re) <- g
  colnames(re) <- gsub("group1","WT",colnames(re))
  colnames(re) <- gsub("group2","MT",colnames(re))
  re$fisher.test.Padj <- p.adjust(re$fisher.test.Pvalue)
  re$chisq.test.Padj <- p.adjust(re$chisq.test.Pvalue)
  fisher_chisq_test_re <- re  
  fisher_chisq_test_re <- na.omit(fisher_chisq_test_re)
  
  rownames(freq)=freq$GENE
  freq <- freq[,-1]
  l <-list("stat"= freq,
           "wil_test"=wil_t_test_re,
           "fisher_test"= fisher_chisq_test_re
  ) 
  return(l)
}































