#' Compute universal threshold backbone
#'
#' `universal` returns a backbone graph in which edge weights are set to
#'    1 if above the given upper parameter threshold,
#'    set to -1 if below the given lower parameter threshold, and are 0 otherwise.
#'
#' @param M graph: Bipartite graph object of class matrix, sparse matrix, igraph, edgelist, or network object.
#' @param upper Real, FUN, or NULL: upper threshold value or function to be applied to the edge weights. Default is NULL.
#' @param lower Real, FUN, or NULL: lower threshold value or function to be applied to the edge weights. Default is NULL.
#' @param bipartite Boolean: TRUE if bipartite matrix, FALSE if weighted matrix. Default is NULL.
#' @param narrative Boolean: TRUE if suggested text for a manuscript is to be returned
#'
#' @details If both `upper` and `lower` are `NULL`, a weighted projection is returned.
#' @details If `bipartite` is `NULL`, the function tries to guess at whether the data is bipartite or unipartite based on its shape.
#' @return backbone, a list(backbone, summary). The `backbone` object is a graph object of the same class as M.
#'     The `summary` contains a data frame summary of the inputted matrix and the model used including:
#'     model name, number of rows, skew of row sums, number of columns, skew of column sums, and running time.
#' @export
#'
#' @examples
#' test <- universal(davis%*%t(davis), upper = function(x)mean(x)+sd(x), lower=function(x)mean(x))
#' test2 <- universal(davis, upper = function(x)mean(x)+2*sd(x), lower = 2, bipartite = TRUE)
#' test3 <- universal(davis, upper = 4, lower = 2, bipartite = TRUE)
universal <- function(M,
                      upper = NULL,
                      lower = NULL,
                      bipartite = NULL,
                      narrative = FALSE){
  #### Argument Checks ####
  if (!(methods::is(upper, "function")) & (!(methods::is(upper, "numeric"))) & (!(methods::is(upper, "NULL")))) {stop("upper must be either function, numeric, or NULL")}
  if (!(methods::is(lower, "function")) & (!(methods::is(lower, "numeric"))) & (!(methods::is(lower, "NULL")))) {stop("lower must be either function, numeric, or NULL")}

  ### Run Time ###
  run.time.start <- Sys.time()

  ### Class Conversion ###
  convert <- class.convert(M)
  class <- convert[[1]]
  M <- convert[[2]]

  #### If not specified, guess whether bipartite or unipartite ####
  if (nrow(M)==ncol(M) & length(bipartite)==0) {
    bipartite <- FALSE
    {warning("The input data is treated as unipartite")}
  }
  if (nrow(M)!=ncol(M) & length(bipartite)==0) {
    bipartite <- TRUE
    {warning("The input data is treated as bipartite")}
  }
  if (length(upper)==0 & length(lower)==0 & bipartite==FALSE) {stop("If the input data is a weighted unipartite graph, then upper and/or lower must be a function or numeric")}

  #### Bipartite Projection ####
  if (bipartite == TRUE){
    if (nrow(M)==ncol(M)) {warning("The input data is square, however you indicated that bipartite = TRUE")}
    if (methods::is(M, "sparseMatrix")) {
      P <- Matrix::tcrossprod(M)
    } else {
      P <- tcrossprod(M)
    }
  } else {
    if (nrow(M)!=ncol(M)) {warning("The input data is rectangular, however you indicated that bipartite = FALSE")}
    P <- M
  }

  #### If both NULL, return the weighted projection ####
  if ((is.null(upper)) & (is.null(lower))){
    backbone <- P
  } else {

    #### For Universal Thresholds ####
    #### Set Threshold Values ####
    if (class(upper) == "function"){
      ut <- upper(P)
    } else {ut <- upper}

    if (class(lower) == "function"){
      lt <- lower(P)
    } else {lt <- lower}

    #### Create Backbone Matrix ####
    backbone <- matrix(0, nrow(P), ncol(P))

    #### Identify negative edges ####
    if (length(lower) > 0){
      negative <- (P<lt)+0
      backbone <- backbone - negative
    }

    #### Identify positive edges ####
    if (length(upper) > 0) {
      positive <- (P>ut)+0
      backbone <- backbone + positive
    }

  } #end else
  diag(backbone) <- 0

  #### Compile Summary ####
  run.time.end <- Sys.time()
  total.time = (round(difftime(run.time.end, run.time.start, units = "secs"), 2))
  if (methods::is(M, "sparseMatrix")) {
    r <- Matrix::rowSums(M)
    c <- Matrix::colSums(M)
  } else {
    r <- rowSums(M)
    c <- colSums(M)
  }
  a <- c("Input Class", "Model", "Number of Rows", "Mean of Row Sums", "SD of Row Sums", "Skew of Row Sums", "Number of Columns", "Mean of Column Sums", "SD of Column Sums", "Skew of Column Sums", "Running Time (secs)")
  b <- c(class[1], "Universal Threshold", dim(M)[1], round(mean(r),5), round(stats::sd(r),5), round((sum((r-mean(r))**3))/((length(r))*((stats::sd(r))**3)), 5), dim(M)[2], round(mean(c),5), round(stats::sd(c),5), round((sum((c-mean(c))**3))/((length(c))*((stats::sd(c))**3)), 5), as.numeric(total.time))
  model.summary <- data.frame(a,b, row.names = 1)
  colnames(model.summary)<-"Model Summary"

  #### Convert to Indicated Class Object ####
  backbone_converted <- class.convert(backbone, class[1], extract = TRUE)

  #### Return Backbone and Summary ####
  bb <- list(backbone = backbone_converted[[2]], summary = model.summary)
  class(bb) <- "backbone"

  #### Display suggested manuscript text ####
  if (narrative == TRUE) {
    message("Suggested manuscript text and citations:")
    message(" ")
    if (bipartite == FALSE){text <- paste0("From a weighted graph containing ", nrow(M), " agents, we extracted its universal threshold backbone using the backbone package (Domagalski, Neal, & Sagan, 2020).")}
    if ((bipartite == TRUE) & (is.null(upper)) & (is.null(lower))){text <- paste0("From a bipartite graph containing ", nrow(M), " agents and ", ncol(M), " artifacts, we computed the weighted bipartite projection using the backbone package (Domagalski, Neal, & Sagan, 2020).")}
    if ((bipartite == TRUE) & !((is.null(upper)) & (is.null(lower)))){text <- paste0("From a bipartite graph containing ", nrow(M), " agents and ", ncol(M), " artifacts, we computed the weighted bipartite projection, then extracted its universal threshold backbone using the backbone package (Domagalski, Neal, & Sagan, 2020).")}
    if (length(upper) > 0 & length(lower) == 0) {text <- paste0(text, " Edges were retained as positive if their weight was above ", round(ut,3),".")}
    if (length(lower) > 0 & length(upper) == 0) {text <- paste0(text, " Edges were retained as negative if their weight was below ", round(lt,3),".")}
    if (length(lower) > 0 & length(upper) > 0) {text <- paste0(text, " Edges were retained as positive if their weight was above ", round(ut,3),", and as negative if their weight was below ", round(lt,3),".")}
    message(text)
    message("")
    message("Domagalski, R., Neal, Z. P., and Sagan, B. (2020). backbone: An R Package for Backbone Extraction of Weighted Graphs. arXiv:1912.12779 [cs.SI]")
  } #end narrative == TRUE

  return(backbone = bb)
} #end function


